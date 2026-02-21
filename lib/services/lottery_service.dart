import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lottery_data.dart';

class LotteryService {
  static const _cacheKey = 'lottery_cache';
  static const _cacheTimeKey = 'lottery_cache_time';
  static const _cacheDuration = Duration(minutes: 30);

  static const _baseUrl = 'https://dhlottery.co.kr/st/selectSellStInfo.do';
  static const _gameTypes = ['SP2000', 'SP1000', 'SP500'];
  static const _gameNames = {'SP2000': '스피또2000', 'SP1000': '스피또1000', 'SP500': '스피또500'};
  static const _gamePrices = {'SP2000': 2000, 'SP1000': 1000, 'SP500': 500};
  // 총 발행량 (회차별 기본)
  static const _baseIssued = {'SP2000': 6000000, 'SP1000': 5000000, 'SP500': 4000000};

  final SharedPreferences _prefs;
  LotterySnapshot? _cached;

  LotteryService(this._prefs) {
    _loadCache();
  }

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _cached = LotterySnapshot.fromJson(jsonDecode(raw));
    } catch (_) {}
  }

  LotterySnapshot? getCached() => _cached;

  Future<LotterySnapshot?> fetch() async {
    final cacheTime = _prefs.getInt(_cacheTimeKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - cacheTime;
    if (elapsed < _cacheDuration.inMilliseconds && _cached != null) {
      return _cached;
    }

    try {
      final games = <ScratchGame>[];
      for (final type in _gameTypes) {
        final result = await _fetchGameType(type);
        games.addAll(result);
      }

      if (games.isEmpty) return _cached;

      final snapshot = LotterySnapshot(games: games, fetchTime: DateTime.now());
      _cached = snapshot;
      await _prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
      await _prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      return snapshot;
    } catch (e) {
      print('[LotteryService] fetch error: $e');
      return _cached;
    }
  }

  Future<List<ScratchGame>> _fetchGameType(String typeCode) async {
    final url = '$_baseUrl?srchStGmTypeCd=$typeCode';
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: false);

      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final list = data['list'] as List? ?? [];

      return list.map((item) {
        final m = item as Map<String, dynamic>;
        return _parseGame(m, typeCode);
      }).toList();
    } catch (e) {
      print('[LotteryService] _fetchGameType($typeCode) error: $e');
      client.close(force: true);
      return [];
    }
  }

  ScratchGame _parseGame(Map<String, dynamic> m, String typeCode) {
    final round = m['stEpsd'] as int? ?? 0;
    final price = _gamePrices[typeCode] ?? 1000;
    final stockRate = (m['stSpmtRt'] as num?)?.toDouble() ?? 0;

    // 등수별 데이터 파싱 (최대 6등까지)
    final tiers = <PrizeTier>[];
    for (int r = 1; r <= 6; r++) {
      final total = m['stRnk${r}WnQty'] as int? ?? 0;
      if (total == 0) continue;
      final claimed = m['winRnk${r}Qty'] as int? ?? 0;
      final remaining = m['stIvtRnk${r}Qty'] as int? ?? 0;
      final prizeText = m['stRnk${r}GdsLstcCharCn'] as String? ?? '';
      tiers.add(PrizeTier(
        rank: r,
        total: total,
        claimed: claimed,
        remaining: remaining,
        prizeAmount: _parseAmount(prizeText),
        prizeText: prizeText,
      ));
    }

    // 총 발행량 추정: 잔여 당첨 합계를 원래 확률로 역산, 또는 기본값 사용
    int totalIssued = _baseIssued[typeCode] ?? 5000000;
    final oddsStr = m['stSumWnPbltNm'] as String? ?? '';
    if (oddsStr.contains('/')) {
      final parts = oddsStr.split('/');
      final denom = double.tryParse(parts.last.trim()) ?? 0;
      if (denom > 0) {
        final totalPrizes = tiers.fold<int>(0, (s, t) => s + t.total);
        totalIssued = (totalPrizes * denom).round();
      }
    } else {
      // "35.3" 같은 퍼센트 형식
      final pct = double.tryParse(oddsStr) ?? 0;
      if (pct > 0) {
        final totalPrizes = tiers.fold<int>(0, (s, t) => s + t.total);
        totalIssued = (totalPrizes / (pct / 100)).round();
      }
    }

    return ScratchGame(
      typeCode: typeCode,
      typeName: _gameNames[typeCode] ?? typeCode,
      round: round,
      price: price,
      saleStart: m['stNtslBgngDt'] as String? ?? '',
      saleEnd: m['stNtslEndDt'] as String? ?? '',
      stockRate: stockRate,
      totalIssued: totalIssued,
      tiers: tiers,
      updateDate: m['dataChgDt'] as String? ?? '',
      originalOdds: oddsStr,
      originalReturnRate: (m['stSumWnGiveRt'] as num?)?.toDouble() ?? 0,
    );
  }

  /// 상금 텍스트 → 원 단위 숫자
  static int _parseAmount(String text) {
    if (text.isEmpty) return 0;
    final clean = text.replaceAll(RegExp(r'[원,\s]'), '');

    // "10억" → 1,000,000,000
    final billions = RegExp(r'(\d+)억');
    final bMatch = billions.firstMatch(clean);
    if (bMatch != null) {
      int amount = int.parse(bMatch.group(1)!) * 100000000;
      // "1억5천만" 같은 복합 처리
      final afterB = clean.substring(bMatch.end);
      final thousands = RegExp(r'(\d+)천만');
      final tMatch = thousands.firstMatch(afterB);
      if (tMatch != null) amount += int.parse(tMatch.group(1)!) * 10000000;
      return amount;
    }

    // "1천만" → 10,000,000
    final tenMillions = RegExp(r'(\d+)천만');
    final tmMatch = tenMillions.firstMatch(clean);
    if (tmMatch != null) return int.parse(tmMatch.group(1)!) * 10000000;

    // "100만" → 1,000,000
    final millions = RegExp(r'(\d+)백만');
    final mMatch = millions.firstMatch(clean);
    if (mMatch != null) return int.parse(mMatch.group(1)!) * 1000000;

    // "2만" → 20,000
    final tenThousands = RegExp(r'(\d+)만');
    final ttMatch = tenThousands.firstMatch(clean);
    if (ttMatch != null) return int.parse(ttMatch.group(1)!) * 10000;

    // "5천" → 5,000
    final thousands2 = RegExp(r'(\d+)천');
    final t2Match = thousands2.firstMatch(clean);
    if (t2Match != null) return int.parse(t2Match.group(1)!) * 1000;

    // 순수 숫자
    return int.tryParse(clean) ?? 0;
  }
}
