class Todo {
  String id;
  String title;
  bool isCompleted;
  int createdAt; // epoch ms
  int? completedAt;

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'createdAt': createdAt,
    'completedAt': completedAt,
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    createdAt: json['createdAt'] as int,
    completedAt: json['completedAt'] as int?,
  );
}
