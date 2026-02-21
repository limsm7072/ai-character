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

/// Detailed result for UI debugging.
class NaverSyncDetailedResult {
  final int total;
  final int added;
  final int skipped;
  final int pageTextLength;
  final bool hasApiKey;
  final String parseMethod; // 'gemini' or 'regex'
  final String debugText;

  const NaverSyncDetailedResult({
    this.total = 0,
    this.added = 0,
    this.skipped = 0,
    this.pageTextLength = 0,
    this.hasApiKey = false,
    this.parseMethod = '',
    this.debugText = '',
  });
}

/// Manages Naver reservation → Calendar sync.
/// Two paths:
/// 1. Manual sync: WebView login + page scraping + Gemini/regex parsing
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

  // ─── Manual Sync (WebView) — detailed version ──────────

  /// Opens Naver WebView, scrapes, parses, returns detailed result for UI.
  Future<NaverSyncDetailedResult> syncReservationsDetailed() async {
    final debug = StringBuffer();

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
    debug.writeln('페이지 텍스트 ${pageText.length}자');

    if (pageText.length < 30) {
      throw Exception('페이지 내용이 너무 짧습니다 (${pageText.length}자)');
    }

    // Show first 2000 chars of page text for debugging
    final preview = pageText.length > 2000 ? pageText.substring(0, 2000) : pageText;
    debug.writeln('--- 페이지 미리보기 ---');
    debug.writeln(preview);
    debug.writeln('---');

    // 2. Clear all existing naver events first (clean re-sync)
    final oldEvents = _calendar.getAll().where((e) => e.title.startsWith('[네이버예약]')).toList();
    for (final e in oldEvents) {
      await _calendar.delete(e.id);
    }
    await _prefs.remove(_syncedIdsKey);
    debug.writeln('기존 네이버 이벤트 ${oldEvents.length}건 삭제');

    // 3. Parse: try Gemini first, then regex fallback
    final hasApiKey = _gemini.isInitialized;
    List<NaverReservation> reservations = [];
    String parseMethod = '';

    String geminiRaw = '';
    if (hasApiKey) {
      try {
        final truncated = pageText.length > 4000 ? pageText.substring(0, 4000) : pageText;
        final now2 = DateTime.now();
        final prompt = '''네이버 예약 페이지 텍스트에서 예약 정보를 JSON 배열로 추출해.
오늘: ${now2.year}-${now2.month.toString().padLeft(2, '0')}-${now2.day.toString().padLeft(2, '0')}

중요: 연도가 없는 날짜(예: "2.6 목")는 요일로 정확한 연도를 판단해.
예: 2월6일이 목요일 → 2025년(2025-02-06은 목요일, 2026-02-06은 금요일이므로)

텍스트:
$truncated

JSON만 반환 (마크다운 없이):
[{"title":"업체명","date":"yyyy-MM-dd","time":"HH:mm","status":"확정/방문완료"}]
예약 없으면 []''';
        geminiRaw = await _gemini.generateRecommendation(prompt) ?? '';
        if (geminiRaw.isNotEmpty) {
          reservations = _parseJsonResult(geminiRaw);
          parseMethod = 'Gemini AI';
        }
      } catch (e) {
        debug.writeln('Gemini 오류: $e');
      }
      debug.writeln('Gemini 결과: ${reservations.length}건 (응답 ${geminiRaw.length}자)');
      if (geminiRaw.isNotEmpty && reservations.isEmpty) {
        debug.writeln('Gemini 원문: ${geminiRaw.substring(0, geminiRaw.length.clamp(0, 300))}');
      }
    }

    if (reservations.isEmpty) {
      reservations = _parseWithRegex(pageText);
      parseMethod = hasApiKey && geminiRaw.isNotEmpty ? 'Regex (Gemini 파싱실패)' :
                    hasApiKey ? 'Regex (Gemini 호출실패)' : 'Regex (API 키 없음)';
      debug.writeln('Regex 파싱: ${reservations.length}건');
    }

    debug.writeln('--- 파싱 결과 ---');
    for (final r in reservations) {
      debug.writeln('[${r.date.substring(0, 4)}] ${r.title} → ${r.date} ${r.time}');
    }

    // 3. Add to calendar
    int added = 0;
    int skipped = 0;
    for (final r in reservations) {
      if (await _addIfNotDuplicate(r)) {
        added++;
      } else {
        skipped++;
      }
    }

    await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

    return NaverSyncDetailedResult(
      total: reservations.length,
      added: added,
      skipped: skipped,
      pageTextLength: pageText.length,
      hasApiKey: hasApiKey,
      parseMethod: parseMethod,
      debugText: debug.toString(),
    );
  }

  /// Simple version (for backward compat).
  Future<NaverSyncResult> syncReservations() async {
    final detailed = await syncReservationsDetailed();
    return NaverSyncResult(total: detailed.total, added: detailed.added, skipped: detailed.skipped);
  }

  // ─── Real-time Notification Listener ───────────────────

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
        await _addIfNotDuplicate(r);
      }
    } catch (e) {
      print('[NaverReservation] Notification parse error: $e');
    }
  }

  // ─── Gemini Parsing ────────────────────────────────────

  Future<List<NaverReservation>> _parseWithGemini(String pageText) async {
    final truncated = pageText.length > 4000 ? pageText.substring(0, 4000) : pageText;

    final now = DateTime.now();
    final prompt = '''다음은 네이버 "내 예약" 페이지에서 추출한 텍스트야. 예약 정보를 JSON으로 추출해줘.
오늘 날짜: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}

페이지 텍스트:
$truncated

JSON 배열로만 답해 (마크다운 코드블록 없이):
[{"title": "업체명", "date": "yyyy-MM-dd", "time": "HH:mm", "status": "상태", "location": ""}]

중요 규칙:
- "3.26.목" 또는 "1.2 금" 같은 날짜는 올해(${now.year})로 변환 → "${now.year}-03-26", "${now.year}-01-02"
- "3.26.목 - 3.27.금" 같은 범위는 시작일만 사용
- 업체명 근처에 날짜가 있는 패턴 (위 또는 아래)
- "오전 10:00" → "10:00", "오후 2:00" → "14:00"
- 취소된 예약만 제외, 나머지 모두 포함 (방문완료/이용완료도 포함)
- 예약을 못 찾으면 빈 배열 [] 반환''';

    try {
      final raw = await _gemini.generateRecommendation(prompt);
      if (raw == null) return [];
      return _parseJsonResult(raw);
    } catch (e) {
      print('[NaverReservation] Gemini parse error: $e');
      return [];
    }
  }

  // ─── Regex Fallback Parsing ────────────────────────────

  /// Parse page text using regex patterns (no AI needed).
  /// Only recognizes a date as a reservation when reservation-related
  /// keywords ("예약", "방문", "원", "박", "이용") exist nearby.
  List<NaverReservation> _parseWithRegex(String pageText) {
    final results = <NaverReservation>[];
    final now = DateTime.now();
    final lines = pageText.split('\n');

    // Day-of-week char must NOT be followed by another Korean char
    // (to avoid matching "금액", "일정", "토론" etc. as weekdays)
    final shortDatePattern = RegExp(r'(\d{1,2})\.(\d{1,2})[.\s]([월화수목금토일])(?:요일)?(?![가-힣])');
    final fullDatePattern = RegExp(r'(\d{4})[.\-/년]\s*(\d{1,2})[.\-/월]\s*(\d{1,2})[일]?');
    final korDatePattern = RegExp(r'(\d{1,2})월\s*(\d{1,2})일');
    final timePattern = RegExp(r'(오전|오후)?\s*(\d{1,2}):(\d{2})');
    // Very strict: only match time+"예약" pattern or overnight stay pattern
    final reservationIndicator = RegExp(r'\d{1,2}:\d{2}\s*예약|\d+박\s*\d+일|체크인|숙박');

    const dayOfWeekMap = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      String? date;
      Match? dateMatch;

      // Try short date: "3.26.목" or "1.2 금" (must start near line beginning)
      final shortMatch = shortDatePattern.firstMatch(line);
      if (shortMatch != null && shortMatch.start <= 5) {
        final month = int.tryParse(shortMatch.group(1)!) ?? 0;
        final day = int.tryParse(shortMatch.group(2)!) ?? 0;
        final dowChar = shortMatch.group(3)!;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final targetDow = dayOfWeekMap[dowChar] ?? 0;
          int year = now.year;
          if (targetDow > 0) {
            // Find the year where weekday matches, closest to today
            // Check range: 3 years back ~ 1 year forward
            int bestYear = now.year;
            int bestDiff = 99999;
            for (int y = now.year + 1; y >= now.year - 3; y--) {
              try {
                if (DateTime(y, month, day).weekday == targetDow) {
                  final diff = (now.difference(DateTime(y, month, day)).inDays).abs();
                  if (diff < bestDiff) {
                    bestDiff = diff;
                    bestYear = y;
                  }
                }
              } catch (_) {}
            }
            year = bestYear;
          }
          // Skip reservations older than 3 years
          try {
            final reservationDate = DateTime(year, month, day);
            if (now.difference(reservationDate).inDays > 3 * 365) {
              print('[NAVER-PARSE] Skip old reservation (>3yr): $year-$month-$day');
              continue;
            }
          } catch (_) {}
          date = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
          dateMatch = shortMatch;
        }
      }

      // Try full date: "2025.3.26"
      if (date == null) {
        final fullMatch = fullDatePattern.firstMatch(line);
        if (fullMatch != null && fullMatch.start <= 5) {
          final year = int.tryParse(fullMatch.group(1)!) ?? 0;
          final month = int.tryParse(fullMatch.group(2)!) ?? 0;
          final day = int.tryParse(fullMatch.group(3)!) ?? 0;
          if (year >= 2020 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            date = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            dateMatch = fullMatch;
          }
        }
      }

      if (date == null) continue;

      // ★ STRICT FILTER: Only treat as reservation if nearby lines (±3) contain
      // specific patterns like "10:00 예약" or "1박 2일" — NOT just "예약" alone
      final windowStart = (i - 3).clamp(0, lines.length);
      final windowEnd = (i + 5).clamp(0, lines.length);
      final window = lines.sublist(windowStart, windowEnd).join(' ');
      if (!reservationIndicator.hasMatch(window)) continue;

      // Skip if cancel-related
      if (window.contains('취소')) continue;

      // Look for time (handles "오전 10:00", "오후 2:00")
      String time = '';
      for (int j = 0; j <= 5; j++) {
        final idx = i + j;
        if (idx >= lines.length) break;
        final tm = timePattern.firstMatch(lines[idx]);
        if (tm != null) {
          final ampm = tm.group(1) ?? '';
          var hour = int.tryParse(tm.group(2)!) ?? 0;
          final minute = tm.group(3)!;
          if (ampm == '오후' && hour < 12) hour += 12;
          if (ampm == '오전' && hour == 12) hour = 0;
          time = '${hour.toString().padLeft(2, '0')}:$minute';
          break;
        }
      }

      // Look for business name: check AFTER the date line first (Naver past format),
      // then BEFORE (Naver upcoming format)
      String title = '';

      // Check lines AFTER date
      for (int j = 1; j <= 5; j++) {
        if (i + j >= lines.length) break;
        final candidate = lines[i + j].trim();
        if (candidate.isEmpty || candidate.length > 40) continue;
        if (_isNavText(candidate)) continue;
        if (shortDatePattern.hasMatch(candidate) || fullDatePattern.hasMatch(candidate)) continue;
        if (RegExp(r'^\d+(\.\d+)?\s*(km|m|원)?$').hasMatch(candidate)) continue;
        if (timePattern.hasMatch(candidate)) continue;
        // Must look like a business name (at least 2 chars, not pure numbers)
        if (candidate.length >= 2 && !RegExp(r'^\d+$').hasMatch(candidate)) {
          title = candidate;
          break;
        }
      }

      // Check lines BEFORE date (for upcoming format: name then date)
      if (title.isEmpty) {
        for (int j = -1; j >= -3; j--) {
          if (i + j < 0) break;
          final candidate = lines[i + j].trim();
          if (candidate.isEmpty || candidate.length > 40) continue;
          if (_isNavText(candidate)) continue;
          if (shortDatePattern.hasMatch(candidate) || fullDatePattern.hasMatch(candidate)) continue;
          if (RegExp(r'^\d+(\.\d+)?\s*(km|m|원)?$').hasMatch(candidate)) continue;
          if (candidate.length >= 2 && !RegExp(r'^\d+$').hasMatch(candidate)) {
            title = candidate;
            break;
          }
        }
      }

      if (title.isEmpty) continue; // No business name found → skip entirely

      // Determine status
      String status = '';
      if (window.contains('방문완료') || window.contains('이용완료')) {
        status = '방문완료';
      } else if (window.contains('확정')) {
        status = '확정';
      } else if (window.contains('대기')) {
        status = '대기';
      }

      // Avoid duplicate
      final isDup = results.any((r) => r.date == date && r.title == title);
      if (!isDup) {
        results.add(NaverReservation(
          title: title,
          date: date!,
          time: time,
          status: status,
        ));
      }
    }

    return results;
  }

  bool _isNavText(String text) {
    const navWords = [
      '예약내역', '타임라인', '전체', '필터', '더보기', '뒤로', '홈', '마이',
      '검색', '로그인', '예약 관리', '내 예약', '내위치', '닫기', '© NAVER Corp.',
      '/OpenStreetMap', 'NAVER Corp.', 'OpenStreetMap',
      '저장', '방문 내역 관리', '다시 예약', '예약 내역', '예약하기',
      '리뷰쓰기', '리뷰 쓰기', '영수증 리뷰', '별점', '평점',
      '다가오는 예약', '지난 예약', '예약 확인', '예약 취소',
      '길찾기', '전화', '공유', '찜', '톡톡', '주문',
    ];
    // Also skip lines that are just "N번째" visit counts or "N일만의 방문"
    if (RegExp(r'^\d+번째').hasMatch(text)) return true;
    if (text.contains('일만의 방문')) return true;
    if (text.contains('리뷰')) return true;
    // Skip price lines like "40,000원"
    if (RegExp(r'^[\d,]+원$').hasMatch(text)) return true;
    // Skip representative name "대표 xxx"
    if (text.startsWith('대표 ')) return true;
    return navWords.any((w) => text == w || text.startsWith('©'));
  }

  // ─── JSON Parse Helper ─────────────────────────────────

  List<NaverReservation> _parseJsonResult(String raw) {
    try {
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(raw.trim());
      if (jsonMatch == null) return [];

      final list = jsonDecode(jsonMatch.group(0)!) as List;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final date = map['date']?.toString() ?? '';
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

  Future<bool> _addIfNotDuplicate(NaverReservation r) async {
    final syncedIds = _getSyncedIds();
    if (syncedIds.contains(r.uniqueKey)) return false;

    final existing = _calendar.getByDate(r.date);
    final alreadyExists = existing.any((e) =>
        e.title.contains(r.title) || (e.title.startsWith('[네이버예약]') && e.title.contains(r.title)));
    if (alreadyExists) {
      syncedIds.add(r.uniqueKey);
      await _saveSyncedIds(syncedIds);
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
      color: '#03C75A',
    );
    await _calendar.add(event);

    syncedIds.add(r.uniqueKey);
    await _saveSyncedIds(syncedIds);
    return true;
  }

  /// Clear all Naver reservation data: remove calendar events + reset synced IDs.
  Future<int> clearNaverData() async {
    int removed = 0;
    final allEvents = _calendar.getAll();
    for (final event in allEvents) {
      if (event.title.startsWith('[네이버예약]')) {
        await _calendar.delete(event.id);
        removed++;
      }
    }
    await _prefs.remove(_syncedIdsKey);
    await _prefs.remove(_lastSyncKey);
    return removed;
  }

  Set<String> _getSyncedIds() {
    final raw = _prefs.getStringList(_syncedIdsKey);
    return raw?.toSet() ?? {};
  }

  Future<void> _saveSyncedIds(Set<String> ids) async {
    await _prefs.setStringList(_syncedIdsKey, ids.toList());
  }
}
