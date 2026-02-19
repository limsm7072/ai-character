import 'package:flutter/material.dart';

/// 루틴 이름 키워드 → Material Icon 자동 매핑
IconData routineIcon(String name) {
  final n = name.toLowerCase();
  for (final entry in _iconMap) {
    for (final keyword in entry.keywords) {
      if (n.contains(keyword)) return entry.icon;
    }
  }
  return Icons.radio_button_unchecked;
}

class _IconEntry {
  final List<String> keywords;
  final IconData icon;
  const _IconEntry(this.keywords, this.icon);
}

const _iconMap = <_IconEntry>[
  // Sleep / wake
  _IconEntry(['기상', '일어나'], Icons.wb_sunny_outlined),
  _IconEntry(['취침', '수면', '잠'], Icons.bedtime_outlined),
  // Exercise
  _IconEntry(['운동', '헬스', '웨이트'], Icons.fitness_center),
  _IconEntry(['러닝', '달리기', '조깅'], Icons.directions_run),
  _IconEntry(['산책', '걷기', '걸음'], Icons.directions_walk),
  _IconEntry(['요가', '명상', '스트레칭'], Icons.self_improvement),
  _IconEntry(['수영'], Icons.pool),
  _IconEntry(['자전거', '사이클'], Icons.pedal_bike),
  // Food / drink
  _IconEntry(['점심'], Icons.restaurant),
  _IconEntry(['식사', '밥'], Icons.restaurant),
  _IconEntry(['물', '수분'], Icons.water_drop_outlined),
  _IconEntry(['커피'], Icons.coffee),
  // Medicine / health
  _IconEntry(['약', '비타민', '영양제'], Icons.medication_outlined),
  _IconEntry(['병원', '진료'], Icons.local_hospital_outlined),
  // Study / work
  _IconEntry(['공부', '학습', '수업'], Icons.school_outlined),
  _IconEntry(['독서', '책', '읽기'], Icons.menu_book),
  _IconEntry(['영어라디오', '영어듣기'], Icons.headphones),
  _IconEntry(['라디오', '팟캐스트', '듣기'], Icons.headphones),
  _IconEntry(['영어', '외국어', '언어'], Icons.abc),
  _IconEntry(['집중', '업무', '작업'], Icons.laptop_mac),
  _IconEntry(['출근', '퇴근', '회사'], Icons.work_outline),
  // Writing / journal
  _IconEntry(['일기', '일지', '기록'], Icons.auto_stories),
  _IconEntry(['메모', '노트', '글쓰기'], Icons.edit_note),
  // Cleaning / hygiene
  _IconEntry(['청소', '정리', '세탁', '빨래'], Icons.cleaning_services_outlined),
  _IconEntry(['샤워', '세안', '씻기'], Icons.shower_outlined),
  _IconEntry(['스킨케어', '피부'], Icons.face_retouching_natural),
  // Music / hobby
  _IconEntry(['피아노', '기타', '음악', '악기'], Icons.music_note),
  _IconEntry(['그림', '그리기', '드로잉'], Icons.palette),
  _IconEntry(['코딩', '프로그래밍', '개발'], Icons.code),
  _IconEntry(['게임'], Icons.sports_esports),
  // Other
  _IconEntry(['기도', '예배', '묵상'], Icons.church),
  _IconEntry(['감사'], Icons.favorite_border),
  _IconEntry(['장보기', '쇼핑', '마트'], Icons.shopping_cart_outlined),
  _IconEntry(['요리', '반찬'], Icons.soup_kitchen),
  _IconEntry(['준비'], Icons.checklist),
];
