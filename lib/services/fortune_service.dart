import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fortune_data.dart';
import '../utils/lunar_calendar.dart';
import 'saju_calculator.dart';

class FortuneService {
  static const _profileBirthDateKey = 'fortune_birth_date'; // yyyy-MM-dd
  static const _profileBirthHourKey = 'fortune_birth_hour'; // 0-23 or -1
  static const _profileGenderKey = 'fortune_gender';        // male/female
  static const _cacheKey = 'fortune_cache';
  static const _cacheDateKey = 'fortune_cache_date';

  final SharedPreferences _prefs;
  FortuneData? _cached;

  FortuneService(this._prefs) {
    _loadCache();
  }

  // ─── Profile ───

  String get birthDate => _prefs.getString(_profileBirthDateKey) ?? '';
  int get birthHour => _prefs.getInt(_profileBirthHourKey) ?? -1;
  String get gender => _prefs.getString(_profileGenderKey) ?? '';
  bool get hasProfile => birthDate.isNotEmpty;

  Future<void> setProfile({
    required String birthDate,
    required int birthHour,
    required String gender,
  }) async {
    await _prefs.setString(_profileBirthDateKey, birthDate);
    await _prefs.setInt(_profileBirthHourKey, birthHour);
    await _prefs.setString(_profileGenderKey, gender);
    _cached = null;
    await _prefs.remove(_cacheDateKey);
  }

  // ─── Cache ───

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _cached = FortuneData.fromJson(jsonDecode(raw));
    } catch (_) {}
  }

  FortuneData? getCached() {
    if (_cached == null) return null;
    final today = _todayStr();
    final cacheDate = _prefs.getString(_cacheDateKey) ?? '';
    if (cacheDate != today) return null;
    return _cached;
  }

  // ─── Generate ───

  FortuneData? generateTodayFortune() {
    if (!hasProfile) return null;

    final today = DateTime.now();
    final todayStr = _todayStr();

    // Check cache
    final cacheDate = _prefs.getString(_cacheDateKey) ?? '';
    if (cacheDate == todayStr && _cached != null) return _cached;

    // Parse birth date
    final parts = birthDate.split('-');
    if (parts.length != 3) return null;
    final bYear = int.tryParse(parts[0]) ?? 2000;
    final bMonth = int.tryParse(parts[1]) ?? 1;
    final bDay = int.tryParse(parts[2]) ?? 1;
    final bHour = birthHour >= 0 ? birthHour : null;
    final birthDateTime = DateTime(bYear, bMonth, bDay);

    // Calculate saju
    final saju = SajuCalculator.calculate(
      year: bYear, month: bMonth, day: bDay, birthHour: bHour,
    );

    // Today's pillar
    final todayPillar = SajuCalculator.todayPillar(today);

    // Seed for deterministic daily variation
    final seed = SajuCalculator.makeSeed(today, birthDateTime);

    // Calculate scores
    final scores = SajuCalculator.calculateDailyScores(
      dayMaster: saju.dayMaster,
      todayPillar: todayPillar,
      seed: seed,
    );

    final overallScore = scores['총운'] ?? 55;

    // Lunar date
    final lunar = LunarCalendar.solarToLunar(today);
    final lunarStr = lunar?.shortString ?? '';

    // Generate texts
    final categoryTexts = <String, String>{};
    final catScores = Map<String, int>.from(scores)..remove('총운');
    for (final entry in catScores.entries) {
      categoryTexts[entry.key] = _fortuneText(entry.key, entry.value, seed);
    }

    // Lucky items
    final luckyItems = _luckyItems(saju.dayMaster, todayPillar, seed);

    // Advice
    final advice = _todayAdvice(overallScore, saju.dayMaster, seed);

    final fortune = FortuneData(
      date: todayStr,
      lunarDateStr: lunarStr,
      overallScore: overallScore,
      overallLabel: _scoreLabel(overallScore),
      categoryScores: catScores,
      categoryTexts: categoryTexts,
      luckyColor: luckyItems['color']!,
      luckyNumber: luckyItems['number']!,
      luckyDirection: luckyItems['direction']!,
      luckyFood: luckyItems['food']!,
      todayAdvice: advice,
      zodiacAnimal: saju.zodiacAnimal,
      constellation: SajuCalculator.getConstellation(bMonth, bDay),
      dayMasterElement: saju.dayMaster.korean,
    );

    // Cache
    _cached = fortune;
    _prefs.setString(_cacheKey, jsonEncode(fortune.toJson()));
    _prefs.setString(_cacheDateKey, todayStr);

    return fortune;
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ─── Score → Label ───

  static String _scoreLabel(int score) {
    if (score >= 85) return '대길';
    if (score >= 70) return '길';
    if (score >= 50) return '평';
    if (score >= 35) return '소흉';
    return '흉';
  }

  // ─── Fortune Text Templates ───

  static String _fortuneText(String category, int score, int seed) {
    final texts = _categoryTemplates[category];
    if (texts == null) return '';

    final List<String> pool;
    if (score >= 80) {
      pool = texts['great']!;
    } else if (score >= 60) {
      pool = texts['good']!;
    } else if (score >= 45) {
      pool = texts['normal']!;
    } else {
      pool = texts['caution']!;
    }

    final idx = SajuCalculator.hash(seed + category.hashCode) % pool.length;
    return pool[idx];
  }

  static const _categoryTemplates = <String, Map<String, List<String>>>{
    '재물': {
      'great': [
        '예상치 못한 수입이 들어올 수 있는 날이에요',
        '투자나 재테크에 좋은 기운이 감돌아요',
        '금전적으로 매우 안정적인 하루가 될 거예요',
        '횡재수가 있으니 기회를 놓치지 마세요',
      ],
      'good': [
        '소소한 행운이 지갑을 채워줄 거예요',
        '계획된 지출은 괜찮지만 충동구매는 자제하세요',
        '금전 흐름이 원활한 하루예요',
        '작은 절약이 큰 복을 가져다줄 거예요',
      ],
      'normal': [
        '무리한 투자보다는 안정을 추구하세요',
        '수입과 지출이 균형을 이루는 평범한 날이에요',
        '큰 변동 없이 안정적인 재물운이에요',
        '불필요한 소비를 줄이면 좋겠어요',
      ],
      'caution': [
        '충동적인 소비에 주의하세요',
        '금전 거래에 신중을 기하세요',
        '예상치 못한 지출이 생길 수 있어요',
        '오늘은 지갑을 꼭 닫아두세요',
      ],
    },
    '연애': {
      'great': [
        '로맨틱한 만남이 기다리고 있어요',
        '사랑하는 사람과 특별한 시간을 보낼 수 있어요',
        '매력이 빛나는 날이에요. 자신감을 가지세요',
        '인연의 실이 강하게 당기는 날이에요',
      ],
      'good': [
        '따뜻한 대화가 관계를 더 깊게 만들어요',
        '주변 사람들에게 좋은 인상을 줄 수 있어요',
        '작은 관심이 큰 사랑으로 돌아올 거예요',
        '솔직한 마음을 전하기 좋은 날이에요',
      ],
      'normal': [
        '평온한 관계를 유지하는 것이 좋아요',
        '급한 고백보다는 천천히 다가가세요',
        '혼자만의 시간도 소중하게 보내세요',
        '감정의 기복 없이 안정적인 하루예요',
      ],
      'caution': [
        '오해가 생기기 쉬우니 말조심하세요',
        '감정적인 결정은 잠시 미루세요',
        '연인과의 다툼에 주의하세요',
        '섣부른 판단은 관계에 해가 될 수 있어요',
      ],
    },
    '건강': {
      'great': [
        '활력이 넘치는 하루! 운동하기 딱 좋아요',
        '몸과 마음이 모두 가벼운 날이에요',
        '컨디션이 최상이에요. 마음껏 활동하세요',
        '새로운 운동을 시작하기 좋은 날이에요',
      ],
      'good': [
        '규칙적인 생활이 건강을 지켜줄 거예요',
        '가벼운 산책이 기분전환에 도움이 돼요',
        '충분한 수분 섭취를 잊지 마세요',
        '전반적으로 양호한 컨디션이에요',
      ],
      'normal': [
        '무리하지 않는 선에서 활동하세요',
        '휴식과 활동의 균형을 잘 맞추세요',
        '스트레칭으로 몸을 풀어주세요',
        '규칙적인 식사가 중요한 날이에요',
      ],
      'caution': [
        '과로에 주의하고 충분히 쉬세요',
        '차가운 음식은 피하는 게 좋겠어요',
        '수면 부족이 쌓이지 않도록 조심하세요',
        '몸에서 보내는 신호에 귀 기울이세요',
      ],
    },
    '사업': {
      'great': [
        '중요한 결정을 내리기 좋은 날이에요',
        '업무 효율이 최고조에 달하는 하루예요',
        '새로운 프로젝트를 시작하기 좋아요',
        '리더십을 발휘할 기회가 찾아와요',
      ],
      'good': [
        '동료들과의 협력이 좋은 결과를 가져와요',
        '꾸준한 노력이 인정받는 날이에요',
        '작은 성과가 쌓여 큰 결실을 맺을 거예요',
        '긍정적인 피드백을 받을 수 있어요',
      ],
      'normal': [
        '주어진 일에 집중하면 무난한 하루예요',
        '급한 변화보다는 기존 계획을 따르세요',
        '서두르지 말고 차근차근 진행하세요',
        '평범하지만 안정적인 업무일이에요',
      ],
      'caution': [
        '중요한 계약이나 결정은 미루는 게 좋아요',
        '직장 내 인간관계에 신경 쓰세요',
        '실수가 발생하기 쉬우니 꼼꼼히 확인하세요',
        '스트레스 관리에 신경 쓰세요',
      ],
    },
    '학업': {
      'great': [
        '집중력이 최고조! 공부하기 딱 좋은 날이에요',
        '새로운 지식을 빠르게 흡수할 수 있어요',
        '시험이나 발표에서 좋은 결과를 기대하세요',
        '창의적인 아이디어가 샘솟는 하루예요',
      ],
      'good': [
        '계획적인 학습이 효과를 발휘해요',
        '복습에 시간을 투자하면 좋은 결과가 있어요',
        '독서나 자기계발에 좋은 날이에요',
        '조용한 환경에서 집중하면 효율이 올라가요',
      ],
      'normal': [
        '무리하지 말고 적당한 양을 공부하세요',
        '잠깐의 휴식이 효율을 높여줄 거예요',
        '어려운 과목은 내일로 미뤄도 괜찮아요',
        '기본기를 다지는 데 집중하세요',
      ],
      'caution': [
        '집중이 잘 안 되는 날이에요. 짧게 끊어서 공부하세요',
        '새로운 것보다 복습 위주로 하세요',
        '충분한 수면 후에 다시 도전하세요',
        '환경을 바꿔보면 도움이 될 수 있어요',
      ],
    },
  };

  // ─── Lucky Items ───

  static Map<String, String> _luckyItems(Element dayMaster, SajuPillar todayPillar, int seed) {
    // 오행별 행운 색상
    const colorMap = {
      Element.wood: ['초록', '연두', '청록'],
      Element.fire: ['빨강', '주황', '분홍'],
      Element.earth: ['노랑', '갈색', '베이지'],
      Element.metal: ['흰색', '은색', '금색'],
      Element.water: ['파랑', '검정', '남색'],
    };

    // 오행별 행운 방향
    const directionMap = {
      Element.wood: '동쪽',
      Element.fire: '남쪽',
      Element.earth: '중앙',
      Element.metal: '서쪽',
      Element.water: '북쪽',
    };

    // 오행별 행운 음식
    const foodMap = {
      Element.wood: ['나물', '샐러드', '녹차', '과일주스'],
      Element.fire: ['매운탕', '불고기', '커피', '볶음밥'],
      Element.earth: ['떡', '고구마', '옥수수', '카레'],
      Element.metal: ['삼겹살', '치킨', '떡볶이', '만두'],
      Element.water: ['해물탕', '초밥', '냉면', '미역국'],
    };

    // 나를 생하는 오행의 아이템이 행운
    const producingElement = {
      Element.wood: Element.water,
      Element.fire: Element.wood,
      Element.earth: Element.fire,
      Element.metal: Element.earth,
      Element.water: Element.metal,
    };

    final lucky = producingElement[dayMaster] ?? dayMaster;
    final h = SajuCalculator.hash(seed + 9973);

    final colors = colorMap[lucky]!;
    final foods = foodMap[lucky]!;

    return {
      'color': colors[h % colors.length],
      'number': '${(h % 9) + 1}',
      'direction': directionMap[lucky]!,
      'food': foods[(h ~/ 10) % foods.length],
    };
  }

  // ─── Today Advice ───

  static String _todayAdvice(int score, Element dayMaster, int seed) {
    final advices = <List<String>>[
      // 대길 (85+)
      [
        '오늘은 무엇을 해도 잘 풀리는 날이에요! 자신감을 가지고 도전하세요',
        '행운의 기운이 가득해요. 중요한 일을 오늘 처리하세요',
        '모든 것이 순조롭게 흘러가는 하루가 될 거예요',
        '적극적으로 행동하면 좋은 결과가 따라와요',
      ],
      // 길 (70-84)
      [
        '전반적으로 좋은 하루예요. 웃는 얼굴이 더 큰 행운을 불러와요',
        '작은 행운들이 하루를 밝게 만들어줄 거예요',
        '긍정적인 마인드가 좋은 결과를 가져다줄 거예요',
        '주변 사람들과의 교류가 행운을 가져와요',
      ],
      // 평 (50-69)
      [
        '무난한 하루예요. 일상에 감사하는 마음을 가져보세요',
        '큰 변화 없이 평온한 하루가 될 거예요. 내일을 준비하세요',
        '조용히 자신만의 시간을 갖는 것도 좋아요',
        '서두르지 말고 차분하게 하루를 보내세요',
      ],
      // 소흉 (35-49)
      [
        '조금 조심스러운 하루예요. 무리하지 마세요',
        '작은 실수에 주의하고, 중요한 결정은 내일로 미루세요',
        '차분하게 행동하면 나쁜 기운을 피할 수 있어요',
        '오늘은 쉬어가는 날이라고 생각하세요',
      ],
      // 흉 (0-34)
      [
        '조심해야 할 하루예요. 모든 일에 신중하게 임하세요',
        '오늘은 휴식을 취하며 에너지를 충전하세요',
        '급한 일이 아니면 내일로 미루는 것이 현명해요',
        '마음을 편안히 하고 무리하지 마세요',
      ],
    ];

    final int tier;
    if (score >= 85) {
      tier = 0;
    } else if (score >= 70) {
      tier = 1;
    } else if (score >= 50) {
      tier = 2;
    } else if (score >= 35) {
      tier = 3;
    } else {
      tier = 4;
    }

    final pool = advices[tier];
    final idx = SajuCalculator.hash(seed + dayMaster.index * 127) % pool.length;
    return pool[idx];
  }
}
