/// Korean lunar calendar conversion utility.
/// Covers years 1900-2100.
class LunarDate {
  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;

  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    this.isLeapMonth = false,
  });

  /// e.g. "음 1.15" or "윤6.1"
  String get shortString =>
      '${isLeapMonth ? "윤" : "음"}$month.$day';
}

class LunarCalendar {
  LunarCalendar._();

  // ─── Lookup table (1900–2100) ──────────────────────────
  // Encoding per year:
  //   bits  0-3 : leap month number (0 = none)
  //   bits  4-15: months 1-12 big/small (1=30d, 0=29d)
  //              bit (16-m) for month m
  //   bit  16   : leap month big (1=30d) or small (0=29d)
  static const _info = <int>[
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, //1900-04
    0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2, //1905-09
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, //1910-14
    0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977, //1915-19
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, //1920-24
    0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970, //1925-29
    0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, //1930-34
    0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950, //1935-39
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, //1940-44
    0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557, //1945-49
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, //1950-54
    0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0, //1955-59
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, //1960-64
    0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0, //1965-69
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, //1970-74
    0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6, //1975-79
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, //1980-84
    0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570, //1985-89
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, //1990-94
    0x06b58, 0x05ac0, 0x0ab60, 0x096d5, 0x092e0, //1995-99
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, //2000-04
    0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5, //2005-09
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, //2010-14
    0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930, //2015-19
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, //2020-24
    0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530, //2025-29
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, //2030-34
    0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45, //2035-39
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, //2040-44
    0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0, //2045-49
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, //2050-54
    0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0, //2055-59
    0x092e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, //2060-64
    0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4, //2065-69
    0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, //2070-74
    0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0, //2075-79
    0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, //2080-84
    0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160, //2085-89
    0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, //2090-94
    0x04ae0, 0x0a9d4, 0x0a4d0, 0x0d150, 0x0f252, //2095-99
    0x0d520, //2100
  ];

  /// Leap month number (0 = none) for a given lunar year.
  static int leapMonth(int year) => _info[year - 1900] & 0xF;

  /// Days in a regular month (1-12).
  static int _monthDays(int year, int month) =>
      (_info[year - 1900] & (0x10000 >> month)) != 0 ? 30 : 29;

  /// Days in the leap month (0 if no leap month).
  static int _leapDays(int year) {
    if (leapMonth(year) == 0) return 0;
    return (_info[year - 1900] & 0x10000) != 0 ? 30 : 29;
  }

  /// Total days in a lunar year (including leap month).
  static int _yearDays(int year) {
    int sum = 348; // 12 months × 29 days
    int v = _info[year - 1900];
    for (int m = 0x8000; m > 0x8; m >>= 1) {
      if ((v & m) != 0) sum++;
    }
    return sum + _leapDays(year);
  }

  // ─── Solar → Lunar ────────────────────────────────────

  /// Convert a solar (Gregorian) date to Korean lunar date.
  /// Returns null if out of range (1900-02-01 ~ 2100-12-31).
  static LunarDate? solarToLunar(DateTime solar) {
    final base = DateTime(1900, 1, 31); // = Lunar 1900/1/1
    int offset = solar.difference(base).inDays;
    if (offset < 0) return null;

    // Find lunar year
    int ly = 1900;
    int dyear;
    while (ly < 2101) {
      dyear = _yearDays(ly);
      if (offset < dyear) break;
      offset -= dyear;
      ly++;
    }
    if (ly > 2100) return null;

    // Find lunar month
    int leap = leapMonth(ly);
    bool isLeap = false;
    int lm = 1;

    for (int i = 1; i <= 12; i++) {
      int dm = _monthDays(ly, i);
      if (offset < dm) {
        lm = i;
        break;
      }
      offset -= dm;

      // Leap month right after month i
      if (i == leap) {
        dm = _leapDays(ly);
        if (offset < dm) {
          lm = i;
          isLeap = true;
          break;
        }
        offset -= dm;
      }

      if (i == 12) lm = 12; // safety
      else lm = i + 1;
    }

    return LunarDate(
      year: ly,
      month: lm,
      day: offset + 1,
      isLeapMonth: isLeap,
    );
  }

  // ─── Korean holidays ────────────────────────────────

  /// Returns the Korean holiday name for a solar date, or null.
  /// Checks both solar (양력) and lunar (음력) holidays + 대체공휴일.
  static String? getHoliday(DateTime solar) {
    // Solar (양력) public holidays
    final solarHoliday = getSolarHoliday(solar.month, solar.day);
    if (solarHoliday != null) return solarHoliday;

    // Lunar (음력) holidays
    final lunarHoliday = getLunarHoliday(solar);
    if (lunarHoliday != null) return lunarHoliday;

    // 대체공휴일 check
    return _getSubstituteHoliday(solar);
  }

  /// 대체공휴일 계산
  /// 2014~: 설날/추석/어린이날 (일요일 겹침 시)
  /// 2021~: 삼일절, 광복절, 개천절, 한글날 추가
  /// 2023~: 토요일도 대체공휴일 적용 (전체 공휴일)
  static String? _getSubstituteHoliday(DateTime solar) {
    final year = solar.year;

    // 양력 공휴일: 토/일 → 다음 월요일
    final solarSubstituteDates = [
      DateTime(year, 1, 1),   // 신정
      DateTime(year, 3, 1),   // 삼일절
      DateTime(year, 5, 5),   // 어린이날
      DateTime(year, 6, 6),   // 현충일
      DateTime(year, 8, 15),  // 광복절
      DateTime(year, 10, 3),  // 개천절
      DateTime(year, 10, 9),  // 한글날
      DateTime(year, 12, 25), // 크리스마스
    ];

    for (final h in solarSubstituteDates) {
      DateTime? sub;
      if (h.weekday == DateTime.sunday) {
        sub = h.add(const Duration(days: 1));
      } else if (h.weekday == DateTime.saturday && year >= 2023) {
        sub = h.add(const Duration(days: 2));
      }
      if (sub != null &&
          solar.year == sub.year && solar.month == sub.month && solar.day == sub.day) {
        return '대체공휴일 (${getSolarHoliday(h.month, h.day)})';
      }
    }

    // 설날/추석 대체공휴일: 연휴 3일 중 토/일 겹치면 연휴 다음 첫 평일
    final lunarHolidayBases = <List<int>>[[1, 1], [8, 15]];
    for (final lh in lunarHolidayBases) {
      final baseDate = _lunarToSolar(year, lh[0], lh[1]);
      if (baseDate == null) continue;

      final days = [
        baseDate.subtract(const Duration(days: 1)),
        baseDate,
        baseDate.add(const Duration(days: 1)),
      ];

      final weekendCount = days.where((d) =>
          d.weekday == DateTime.saturday || d.weekday == DateTime.sunday).length;
      if (weekendCount > 0) {
        var sub = days.last.add(const Duration(days: 1));
        // 주말+공휴일 피해서 다음 평일 찾기
        int safetyCount = 0;
        while ((sub.weekday == DateTime.saturday || sub.weekday == DateTime.sunday) &&
               safetyCount < 7) {
          sub = sub.add(const Duration(days: 1));
          safetyCount++;
        }
        if (solar.year == sub.year && solar.month == sub.month && solar.day == sub.day) {
          final name = lh[0] == 1 ? '설날' : '추석';
          return '대체공휴일 ($name)';
        }
      }
    }

    // 석가탄신일 대체공휴일 (2024~)
    final buddhaDay = _lunarToSolar(year, 4, 8);
    if (buddhaDay != null && year >= 2024) {
      DateTime? sub;
      if (buddhaDay.weekday == DateTime.sunday) {
        sub = buddhaDay.add(const Duration(days: 1));
      } else if (buddhaDay.weekday == DateTime.saturday) {
        sub = buddhaDay.add(const Duration(days: 2));
      }
      if (sub != null &&
          solar.year == sub.year && solar.month == sub.month && solar.day == sub.day) {
        return '대체공휴일 (석가탄신일)';
      }
    }

    return null;
  }

  /// 음력 → 양력 변환 (특정 년도의 음력 날짜에 해당하는 양력 날짜 찾기)
  static DateTime? _lunarToSolar(int solarYear, int lunarMonth, int lunarDay) {
    // Search within the solar year for matching lunar date
    // 설날: 보통 1~2월, 추석: 보통 9~10월
    final searchStart = lunarMonth <= 6
        ? DateTime(solarYear, 1, 1)
        : DateTime(solarYear, 8, 1);
    final searchEnd = lunarMonth <= 6
        ? DateTime(solarYear, 3, 15)
        : DateTime(solarYear, 11, 15);

    for (var d = searchStart; d.isBefore(searchEnd); d = d.add(const Duration(days: 1))) {
      final ld = solarToLunar(d);
      if (ld != null && !ld.isLeapMonth && ld.month == lunarMonth && ld.day == lunarDay) {
        return d;
      }
    }
    return null;
  }

  /// Korean solar (양력) public holidays.
  static String? getSolarHoliday(int month, int day) {
    if (month == 1 && day == 1) return '신정';
    if (month == 3 && day == 1) return '삼일절';
    if (month == 5 && day == 5) return '어린이날';
    if (month == 6 && day == 6) return '현충일';
    if (month == 8 && day == 15) return '광복절';
    if (month == 10 && day == 3) return '개천절';
    if (month == 10 && day == 9) return '한글날';
    if (month == 12 && day == 25) return '크리스마스';
    return null;
  }

  /// Korean lunar (음력) public holidays (빨간날만).
  static String? getLunarHoliday(DateTime solar) {
    final ld = solarToLunar(solar);
    if (ld == null || ld.isLeapMonth) return null;

    final m = ld.month;
    final d = ld.day;

    if (m == 1 && d == 1) return '설날';
    if (m == 1 && d == 2) return '설날 연휴';
    if (m == 4 && d == 8) return '석가탄신일';
    if (m == 8 && d == 14) return '추석 연휴';
    if (m == 8 && d == 15) return '추석';
    if (m == 8 && d == 16) return '추석 연휴';

    // 설날 전날 (= 전년도 음력 12월 마지막 날)
    final tomorrow = solar.add(const Duration(days: 1));
    final tmLd = solarToLunar(tomorrow);
    if (tmLd != null && !tmLd.isLeapMonth && tmLd.month == 1 && tmLd.day == 1) {
      return '설날 연휴';
    }

    return null;
  }

  /// 음력 기념일 (공휴일 아님, 캘린더 표시용).
  static String? getLunarMemorialDay(DateTime solar) {
    final ld = solarToLunar(solar);
    if (ld == null || ld.isLeapMonth) return null;

    if (ld.month == 1 && ld.day == 15) return '정월대보름';
    if (ld.month == 5 && ld.day == 5) return '단오';
    if (ld.month == 7 && ld.day == 7) return '칠석';
    if (ld.month == 8 && ld.day == 1) return '어버이은혜의 날';
    if (ld.month == 9 && ld.day == 9) return '중양절';
    if (ld.month == 12 && ld.day == 30) return '섣달그믐';
    return null;
  }

  /// 양력 기념일 (공휴일 아님, 캘린더 표시용).
  static String? getSolarMemorialDay(int month, int day) {
    if (month == 2 && day == 14) return '발렌타인데이';
    if (month == 3 && day == 14) return '화이트데이';
    if (month == 4 && day == 5) return '식목일';
    if (month == 5 && day == 8) return '어버이날';
    if (month == 5 && day == 15) return '스승의날';
    if (month == 6 && day == 25) return '6.25 전쟁일';
    if (month == 7 && day == 17) return '제헌절';
    if (month == 11 && day == 11) return '빼빼로데이';
    return null;
  }

  /// Check if a date is a public holiday (red day).
  static bool isPublicHoliday(DateTime solar) {
    return getHoliday(solar) != null;
  }
}
