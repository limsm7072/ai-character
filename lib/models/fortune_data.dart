class FortuneData {
  final String date;            // "2026-02-21"
  final String lunarDateStr;    // "음 1.3"
  final int overallScore;       // 0-100
  final String overallLabel;    // "대길/길/평/소흉/흉"
  final Map<String, int> categoryScores;    // {재물:75, 연애:60, ...}
  final Map<String, String> categoryTexts;  // {재물:"...", ...}
  final String luckyColor;
  final String luckyNumber;
  final String luckyDirection;
  final String luckyFood;
  final String todayAdvice;
  final String zodiacAnimal;    // "호랑이"
  final String constellation;   // "물고기자리"
  final String dayMasterElement; // "목"

  const FortuneData({
    required this.date,
    required this.lunarDateStr,
    required this.overallScore,
    required this.overallLabel,
    required this.categoryScores,
    required this.categoryTexts,
    required this.luckyColor,
    required this.luckyNumber,
    required this.luckyDirection,
    required this.luckyFood,
    required this.todayAdvice,
    required this.zodiacAnimal,
    required this.constellation,
    required this.dayMasterElement,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'lunarDateStr': lunarDateStr,
    'overallScore': overallScore,
    'overallLabel': overallLabel,
    'categoryScores': categoryScores,
    'categoryTexts': categoryTexts,
    'luckyColor': luckyColor,
    'luckyNumber': luckyNumber,
    'luckyDirection': luckyDirection,
    'luckyFood': luckyFood,
    'todayAdvice': todayAdvice,
    'zodiacAnimal': zodiacAnimal,
    'constellation': constellation,
    'dayMasterElement': dayMasterElement,
  };

  factory FortuneData.fromJson(Map<String, dynamic> json) => FortuneData(
    date: json['date'] ?? '',
    lunarDateStr: json['lunarDateStr'] ?? '',
    overallScore: json['overallScore'] ?? 50,
    overallLabel: json['overallLabel'] ?? '평',
    categoryScores: (json['categoryScores'] as Map?)?.map(
      (k, v) => MapEntry(k.toString(), (v as num).toInt()),
    ) ?? {},
    categoryTexts: (json['categoryTexts'] as Map?)?.map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ) ?? {},
    luckyColor: json['luckyColor'] ?? '',
    luckyNumber: json['luckyNumber'] ?? '',
    luckyDirection: json['luckyDirection'] ?? '',
    luckyFood: json['luckyFood'] ?? '',
    todayAdvice: json['todayAdvice'] ?? '',
    zodiacAnimal: json['zodiacAnimal'] ?? '',
    constellation: json['constellation'] ?? '',
    dayMasterElement: json['dayMasterElement'] ?? '',
  );
}
