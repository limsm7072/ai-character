class Diary {
  String id;
  String date; // yyyy-MM-dd
  String content;
  int mood; // 0=very bad, 1=bad, 2=neutral, 3=good, 4=very good
  List<String> tags;
  int createdAt; // epoch ms
  int updatedAt; // epoch ms

  Diary({
    required this.id,
    required this.date,
    this.content = '',
    this.mood = 2,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'content': content,
    'mood': mood,
    'tags': tags,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory Diary.fromJson(Map<String, dynamic> json) => Diary(
    id: json['id'] as String,
    date: json['date'] as String,
    content: json['content'] as String? ?? '',
    mood: json['mood'] as int? ?? 2,
    tags: List<String>.from(json['tags'] ?? []),
    createdAt: json['createdAt'] as int,
    updatedAt: json['updatedAt'] as int,
  );

  static const moodEmojis = ['😢', '😔', '😐', '😊', '😄'];
  static const moodLabels = ['매우 나쁨', '나쁨', '보통', '좋음', '매우 좋음'];

  String get moodEmoji => moodEmojis[mood.clamp(0, 4)];
  String get moodLabel => moodLabels[mood.clamp(0, 4)];
}
