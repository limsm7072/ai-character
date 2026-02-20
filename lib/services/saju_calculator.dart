/// 사주팔자 계산 엔진
/// 천간지지 기반 년주/월주/일주/시주 계산 및 오행 상생상극 분석

class SajuPillar {
  final int stemIndex;   // 천간 인덱스 (0-9)
  final int branchIndex; // 지지 인덱스 (0-11)

  const SajuPillar(this.stemIndex, this.branchIndex);

  String get stem => heavenlyStems[stemIndex];
  String get branch => earthlyBranches[branchIndex];
  String get stemHanja => _stemHanja[stemIndex];
  String get branchHanja => _branchHanja[branchIndex];
  Element get stemElement => stemToElement(stemIndex);
  Element get branchElement => branchToElement(branchIndex);
  String get zodiacAnimal => _zodiacAnimals[branchIndex];

  @override
  String toString() => '$stem$branch';

  static const heavenlyStems = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
  static const earthlyBranches = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];
  static const _stemHanja = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
  static const _branchHanja = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
  static const _zodiacAnimals = ['쥐', '소', '호랑이', '토끼', '용', '뱀', '말', '양', '원숭이', '닭', '개', '돼지'];
}

enum Element { wood, fire, earth, metal, water }

extension ElementName on Element {
  String get korean {
    switch (this) {
      case Element.wood: return '목';
      case Element.fire: return '화';
      case Element.earth: return '토';
      case Element.metal: return '금';
      case Element.water: return '수';
    }
  }

  String get emoji {
    switch (this) {
      case Element.wood: return '🌳';
      case Element.fire: return '🔥';
      case Element.earth: return '🌍';
      case Element.metal: return '⚔️';
      case Element.water: return '💧';
    }
  }
}

/// 천간 → 오행
Element stemToElement(int stemIndex) {
  switch (stemIndex ~/ 2) {
    case 0: return Element.wood;   // 갑을
    case 1: return Element.fire;   // 병정
    case 2: return Element.earth;  // 무기
    case 3: return Element.metal;  // 경신
    case 4: return Element.water;  // 임계
    default: return Element.earth;
  }
}

/// 지지 → 오행
Element branchToElement(int branchIndex) {
  switch (branchIndex) {
    case 2: case 3: return Element.wood;    // 인묘
    case 5: case 6: return Element.fire;    // 사오
    case 1: case 4: case 7: case 10: return Element.earth; // 축진미술
    case 8: case 9: return Element.metal;   // 신유
    case 0: case 11: return Element.water;  // 자해
    default: return Element.earth;
  }
}

/// 오행 상생상극 관계
enum ElementRelation {
  same,     // 비겁 (같은 오행)
  produces, // 식상 (내가 생하는)
  produced, // 인성 (나를 생하는)
  controls, // 재성 (내가 극하는)
  controlled, // 관성 (나를 극하는)
}

ElementRelation getRelation(Element me, Element other) {
  if (me == other) return ElementRelation.same;

  // 상생 순서: 목→화→토→금→수→목
  const cycle = [Element.wood, Element.fire, Element.earth, Element.metal, Element.water];
  final myIdx = cycle.indexOf(me);
  final otherIdx = cycle.indexOf(other);

  if ((myIdx + 1) % 5 == otherIdx) return ElementRelation.produces;  // 내가 생
  if ((otherIdx + 1) % 5 == myIdx) return ElementRelation.produced;  // 나를 생

  // 상극 순서: 목→토→수→화→금→목
  if ((myIdx + 2) % 5 == otherIdx) return ElementRelation.controls;    // 내가 극
  if ((otherIdx + 2) % 5 == myIdx) return ElementRelation.controlled;  // 나를 극

  return ElementRelation.same; // fallback
}

class SajuResult {
  final SajuPillar yearPillar;
  final SajuPillar monthPillar;
  final SajuPillar dayPillar;
  final SajuPillar? hourPillar; // null if birth hour unknown

  const SajuResult({
    required this.yearPillar,
    required this.monthPillar,
    required this.dayPillar,
    this.hourPillar,
  });

  /// 일간 (Day Master) — 사주의 핵심
  Element get dayMaster => dayPillar.stemElement;

  /// 띠
  String get zodiacAnimal => yearPillar.zodiacAnimal;

  /// 오행 분포 (천간 + 지지 모두)
  Map<Element, int> get elementBalance {
    final map = <Element, int>{};
    for (final e in Element.values) {
      map[e] = 0;
    }
    for (final p in [yearPillar, monthPillar, dayPillar, if (hourPillar != null) hourPillar!]) {
      map[p.stemElement] = (map[p.stemElement] ?? 0) + 1;
      map[p.branchElement] = (map[p.branchElement] ?? 0) + 1;
    }
    return map;
  }
}

class SajuCalculator {
  SajuCalculator._();

  /// 생년월일+시로 사주 계산
  static SajuResult calculate({
    required int year,
    required int month,
    required int day,
    int? birthHour, // 0-23, null if unknown
  }) {
    final yearPillar = _yearPillar(year);
    final monthPillar = _monthPillar(yearPillar.stemIndex, month);
    final dayPillar = _dayPillar(year, month, day);
    final hourPillar = birthHour != null ? _hourPillar(dayPillar.stemIndex, birthHour) : null;

    return SajuResult(
      yearPillar: yearPillar,
      monthPillar: monthPillar,
      dayPillar: dayPillar,
      hourPillar: hourPillar,
    );
  }

  /// 오늘 일주 계산
  static SajuPillar todayPillar(DateTime date) {
    return _dayPillar(date.year, date.month, date.day);
  }

  // ─── 년주 ───
  static SajuPillar _yearPillar(int year) {
    final stem = (year - 4) % 10;
    final branch = (year - 4) % 12;
    return SajuPillar(stem, branch);
  }

  // ─── 월주 ───
  static SajuPillar _monthPillar(int yearStem, int month) {
    // 지지: 1월=인(2), 2월=묘(3), ..., 11월=자(0), 12월=축(1)
    final branch = (month + 1) % 12;
    // 천간: 갑/기년→1월=병, 을/경→무, 병/신→경, 정/임→임, 무/계→갑
    final stem = ((yearStem % 5) * 2 + 2 + (month - 1)) % 10;
    return SajuPillar(stem, branch);
  }

  // ─── 일주 (Julian Day Number 방식) ───
  static SajuPillar _dayPillar(int year, int month, int day) {
    final jdn = _julianDayNumber(year, month, day);
    final idx = (jdn + 15) % 60;
    return SajuPillar(idx % 10, idx % 12);
  }

  static int _julianDayNumber(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  }

  // ─── 시주 ───
  static SajuPillar _hourPillar(int dayStem, int hour) {
    // 시지지: 23-1=자(0), 1-3=축(1), ..., 21-23=해(11)
    final branch = ((hour + 1) ~/ 2) % 12;
    // 시천간
    final stem = ((dayStem % 5) * 2 + branch) % 10;
    return SajuPillar(stem, branch);
  }

  // ─── 별자리 ───
  static String getConstellation(int month, int day) {
    const constellations = [
      [20, '물병자리'],  // 1월 20일~
      [19, '물고기자리'], // 2월 19일~
      [21, '양자리'],    // 3월 21일~
      [20, '황소자리'],  // 4월 20일~
      [21, '쌍둥이자리'], // 5월 21일~
      [22, '게자리'],    // 6월 22일~
      [23, '사자자리'],  // 7월 23일~
      [23, '처녀자리'],  // 8월 23일~
      [23, '천칭자리'],  // 9월 23일~
      [23, '전갈자리'],  // 10월 23일~
      [22, '사수자리'],  // 11월 22일~
      [22, '염소자리'],  // 12월 22일~
    ];

    final idx = month - 1;
    if (day >= (constellations[idx][0] as int)) {
      return constellations[idx][1] as String;
    } else {
      final prev = (idx - 1 + 12) % 12;
      return constellations[prev][1] as String;
    }
  }

  /// 일일 운세 점수 계산
  /// dayMaster: 본인 일간 오행, todayElement: 오늘 일주 천간 오행
  /// seed: 날짜+생일 해시 (결정적 변동)
  static Map<String, int> calculateDailyScores({
    required Element dayMaster,
    required SajuPillar todayPillar,
    required int seed,
  }) {
    final todayStemEl = todayPillar.stemElement;
    final todayBranchEl = todayPillar.branchElement;

    // 기본 관계 점수
    final stemRelation = getRelation(dayMaster, todayStemEl);
    final branchRelation = getRelation(dayMaster, todayBranchEl);

    int baseScore = 55;
    baseScore += _relationScore(stemRelation) + (_relationScore(branchRelation) ~/ 2);
    baseScore = baseScore.clamp(20, 95);

    // 카테고리별 점수 (다른 오행 관계 가중)
    final categories = <String, int>{};
    final catNames = ['재물', '연애', '건강', '사업', '학업'];

    for (var i = 0; i < catNames.length; i++) {
      final catSeed = hash(seed + i * 7919);
      final variation = (catSeed % 21) - 10; // -10 ~ +10
      int score = baseScore + variation;

      // 카테고리별 특수 보정
      switch (catNames[i]) {
        case '재물':
          if (stemRelation == ElementRelation.controls) score += 8;
          break;
        case '연애':
          if (stemRelation == ElementRelation.produces) score += 8;
          if (branchRelation == ElementRelation.controlled) score += 5;
          break;
        case '건강':
          if (stemRelation == ElementRelation.produced) score += 10;
          if (stemRelation == ElementRelation.controlled) score -= 5;
          break;
        case '사업':
          if (stemRelation == ElementRelation.controls) score += 5;
          if (branchRelation == ElementRelation.same) score += 5;
          break;
        case '학업':
          if (stemRelation == ElementRelation.produced) score += 8;
          break;
      }

      categories[catNames[i]] = score.clamp(10, 98);
    }

    // 총운 = 카테고리 평균 + 약간의 시드 변동
    final avg = categories.values.reduce((a, b) => a + b) / categories.length;
    final overallVariation = (hash(seed + 31337) % 11) - 5;
    categories['총운'] = (avg + overallVariation).round().clamp(10, 98);

    return categories;
  }

  static int _relationScore(ElementRelation r) {
    switch (r) {
      case ElementRelation.same: return 5;
      case ElementRelation.produces: return 10;
      case ElementRelation.produced: return 20;
      case ElementRelation.controls: return 15;
      case ElementRelation.controlled: return -10;
    }
  }

  /// Simple deterministic hash for seed-based variation
  static int hash(int value) {
    var h = value & 0x7FFFFFFF;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = (h >> 16) ^ h;
    return h & 0x7FFFFFFF;
  }

  /// 날짜+생일 기반 시드 생성
  static int makeSeed(DateTime today, DateTime birthDate) {
    return today.year * 10000 + today.month * 100 + today.day +
        birthDate.year * 7 + birthDate.month * 13 + birthDate.day * 31;
  }
}
