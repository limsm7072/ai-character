import 'dart:convert';

class WorkType {
  final String id;
  String name;
  String color; // hex e.g. '#FF9800'

  WorkType({
    required this.id,
    required this.name,
    this.color = '#2196F3',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
  };

  factory WorkType.fromJson(Map<String, dynamic> json) => WorkType(
    id: json['id'],
    name: json['name'],
    color: json['color'] ?? '#2196F3',
  );

  static String encode(List<WorkType> list) =>
      jsonEncode(list.map((w) => w.toJson()).toList());

  static List<WorkType> decode(String source) =>
      (jsonDecode(source) as List).map((j) => WorkType.fromJson(j)).toList();
}
