class Memo {
  String id;
  String title;
  String content;
  int createdAt; // epoch ms
  int updatedAt; // epoch ms

  Memo({
    required this.id,
    required this.title,
    this.content = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String? ?? '',
    createdAt: json['createdAt'] as int,
    updatedAt: json['updatedAt'] as int,
  );
}
