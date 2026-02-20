class Todo {
  String id;
  String title;
  bool isCompleted;
  int createdAt; // epoch ms
  int? completedAt;
  String? dueDate; // yyyy-MM-dd, nullable

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.dueDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'createdAt': createdAt,
    'completedAt': completedAt,
    if (dueDate != null) 'dueDate': dueDate,
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as String,
    title: json['title'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    createdAt: json['createdAt'] as int,
    completedAt: json['completedAt'] as int?,
    dueDate: json['dueDate'] as String?,
  );

  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    final due = DateTime.tryParse(dueDate!);
    if (due == null) return false;
    final today = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }

  String? get dueDateDisplay {
    if (dueDate == null) return null;
    final parts = dueDate!.split('-');
    if (parts.length != 3) return dueDate;
    return '${int.parse(parts[1])}/${int.parse(parts[2])}';
  }
}
