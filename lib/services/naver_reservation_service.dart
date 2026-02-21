import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_event.dart';
import 'calendar_service.dart';
import 'gemini_service.dart';

/// Parsed Naver reservation data.
class NaverReservation {
  final String title;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm or empty
  final String status; // 확정, 대기, 완료, 취소
  final String location;

  const NaverReservation({
    required this.title,
    required this.date,
    this.time = '',
    this.status = '',
    this.location = '',
  });

  String get uniqueKey => '${title}_$date${time.isNotEmpty ? '_$time' : ''}';
}

/// Result of a sync operation.
class NaverSyncResult {
  final int total;
  final int added;
  final int skipped;
  const NaverSyncResult({this.total = 0, this.added = 0, this.skipped = 0});
}

/// Manages Naver reservation → Calendar sync.
/// Two paths:
/// 1. Manual sync: WebView login + page scraping + Gemini parsing
/// 2. Real-time: NotificationListenerService → EventChannel → Gemini parsing
class NaverReservationService {
  static const _channel = MethodChannel('com.aicharacter.ai_character/naver_reservation');
  static const _eventChannel = EventChannel('com.aicharacter.ai_character/naver_events');

  static const _syncedIdsKey = 'naver_synced_ids';
  static const _lastSyncKey = 'naver_last_sync';

  final SharedPreferences _prefs;
  final CalendarService _calendar;
  final GeminiService _gemini;

  NaverReservationService({
    required SharedPreferences prefs,
    required CalendarService calendar,
    required GeminiService gemini,
  })  : _prefs = prefs,
        _calendar = calendar,
        _gemini = gemini;

  // ─── Settings ──────────────────────────────────────────

  DateTime? get lastSync {
    final raw = _prefs.getString(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  String get lastSyncText {
    final dt = lastSync;
    if (dt == null) return '동기화한 적 없음';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ─── Permissions ───────────────────────────────────────

  Future<bool> hasNotificationListenerPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasNotificationListenerPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestNotificationListenerPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationListenerPermission');
    } catch (_) {}
  }

  // ─── Manual Sync (WebView) ─────────────────────────────

  /// Opens Naver WebView for login + scraping, then parses with Gemini.
  Future<NaverSyncResult> syncReservations() async {
    // 1. Open WebView and get page text
    final result = await _channel.invokeMethod<Map>('fetchReservations');
    if (result == null) throw Exception('채널 응답 없음');

    final status = result['status'] as String? ?? '';
    if (status == 'error') {
      final error = result['error'] as String? ?? 'UNKNOWN';
      if (error == 'USER_CANCELLED') throw Exception('사용자가 취소했습니다');
      if (error == 'TIMEOUT') throw Exception('시간이 초과되었습니다');
      throw Exception('오류: $error');
    }
    if (status == 'cancelled') throw Exception('취소됨');

    final pageText = result['text'] as String? ?? '';
    if (pageText.length < 30) throw Exception('페이지 내용을 읽지 못했습니다');

    // 2. Parse with Gemini
    final reservations = await _parseWithGemini(pageText);
    if (reservations.isEmpty) {
      await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      return const NaverSyncResult();
    }

    // 3. Add to calendar (with duplicate check)
    int added = 0;
    int skipped = 0;
    for (final r in reservations) {
      if (_addIfNotDuplicate(r)) {
        added++;
      } else {
        skipped++;
      }
    }

    await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    return NaverSyncResult(total: reservations.length, added: added, skipped: skipped);
  }

  // ─── Real-time Notification Listener ───────────────────

  /// Start listening for Naver reservation notifications via EventChannel.
  void startListeningNotifications() {
    _eventChannel.receiveBroadcastStream().listen((data) {
      if (data is Map) {
        final title = data['title']?.toString() ?? '';
        final text = data['text']?.toString() ?? '';
        final bigText = data['bigText']?.toString() ?? '';
        _processNotification(title, text, bigText);
      }
    }, onError: (e) {
      print('[NaverReservation] EventChannel error: $e');
    });

    // Also check pending notifications (from when app was in background)
    _checkPendingNotifications();
  }

  Future<void> _checkPendingNotifications() async {
    try {
      final pending = await _channel.invokeMethod<List>('getPendingNotifications');
      if (pending == null || pending.isEmpty) return;

      for (final item in pending) {
        if (item is Map) {
          final title = item['title']?.toString() ?? '';
          final text = item['text']?.toString() ?? '';
          final bigText = item['bigText']?.toString() ?? '';
          await _processNotification(title, text, bigText);
        }
      }
    } catch (e) {
      print('[NaverReservation] Check pending error: $e');
    }
  }

  Future<void> _processNotification(String title, String text, String bigText) async {
    final combined = '$title $text $bigText'.trim();
    if (combined.length < 5) return;

    final prompt = '''다음 알림에서 예약 정보를 추출해줘.

알림 텍스트: $combined

JSON으로만 답해 (마크다운 코드블록 없이):
[{"title": "업체명", "date": "yyyy-MM-dd", "time": "HH:mm", "status": "확정", "location": "주소"}]

예약 정보를 찾을 수 없으면 빈 배열 [] 반환.
날짜가 명확하지 않으면 오늘 날짜 사용.''';

    try {
      final raw = await _gemini.generateRecommendation(prompt);
      if (raw == null) return;
      final reservations = _parseJsonResult(raw);
      for (final r in reservations) {
        _addIfNotDuplicate(r);
      }
    } catch (e) {
      print('[NaverReservation] Notification parse error: $e');
    }
  }

  // ─── Gemini Parsing ────────────────────────────────────

  Future<List<NaverReservation>> _parseWithGemini(String pageText) async {
    // Truncate if too long (Gemini token limit)
    final truncated = pageText.length > 4000 ? pageText.substring(0, 4000) : pageText;

    final prompt = '''다음은 네이버 예약 내역 페이지 텍스트야. 예약 정보를 JSON 배열로 추출해줘.

페이지 텍스트:
$truncated

JSON 배열로만 답해 (마크다운 코드블록 없이):
[{"title": "업체명", "date": "yyyy-MM-dd", "time": "HH:mm", "status": "확정|대기|완료|취소", "location": "주소"}]

규칙:
- 확정, 대기 상태인 미래 예약만 포함
- 완료, 취소된 예약은 제외
- 날짜는 반드시 yyyy-MM-dd 형식
- 시간은 HH:mm 형식 (없으면 빈 문자열)
- 예약 정보가 없으면 빈 배열 [] 반환''';

    try {
      final raw = await _gemini.generateRecommendation(prompt);
      if (raw == null) return [];
      return _parseJsonResult(raw);
    } catch (e) {
      print('[NaverReservation] Gemini parse error: $e');
      return [];
    }
  }

  List<NaverReservation> _parseJsonResult(String raw) {
    try {
      // Extract JSON array from response
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(raw.trim());
      if (jsonMatch == null) return [];

      final list = jsonDecode(jsonMatch.group(0)!) as List;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final date = map['date']?.toString() ?? '';
        // Validate date format
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return null;

        return NaverReservation(
          title: map['title']?.toString() ?? '',
          date: date,
          time: map['time']?.toString() ?? '',
          status: map['status']?.toString() ?? '',
          location: map['location']?.toString() ?? '',
        );
      }).whereType<NaverReservation>().where((r) => r.title.isNotEmpty).toList();
    } catch (e) {
      print('[NaverReservation] JSON parse error: $e');
      return [];
    }
  }

  // ─── Calendar Integration ──────────────────────────────

  bool _addIfNotDuplicate(NaverReservation r) {
    final syncedIds = _getSyncedIds();
    if (syncedIds.contains(r.uniqueKey)) return false;

    // Also check existing calendar events
    final existing = _calendar.getByDate(r.date);
    final alreadyExists = existing.any((e) =>
        e.title.contains(r.title) || (e.title.startsWith('[네이버예약]') && e.title.contains(r.title)));
    if (alreadyExists) {
      syncedIds.add(r.uniqueKey);
      _saveSyncedIds(syncedIds);
      return false;
    }

    int? startHour;
    int? startMinute;
    if (r.time.isNotEmpty && r.time.contains(':')) {
      final parts = r.time.split(':');
      startHour = int.tryParse(parts[0]);
      startMinute = int.tryParse(parts[1]);
    }

    final description = [
      if (r.location.isNotEmpty) '장소: ${r.location}',
      if (r.status.isNotEmpty) '상태: ${r.status}',
    ].join('\n');

    final event = CalendarEvent(
      id: 'naver_${DateTime.now().millisecondsSinceEpoch}',
      title: '[네이버예약] ${r.title}',
      description: description,
      date: r.date,
      startHour: startHour,
      startMinute: startMinute,
      color: '#03C75A', // Naver green
    );
    _calendar.add(event);

    syncedIds.add(r.uniqueKey);
    _saveSyncedIds(syncedIds);
    return true;
  }

  Set<String> _getSyncedIds() {
    final raw = _prefs.getStringList(_syncedIdsKey);
    return raw?.toSet() ?? {};
  }

  void _saveSyncedIds(Set<String> ids) {
    _prefs.setStringList(_syncedIdsKey, ids.toList());
  }
}
