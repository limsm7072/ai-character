class Bookmark {
  String id;
  String name;
  String url;
  String? faviconUrl;
  int order;
  int createdAt;

  Bookmark({
    required this.id,
    required this.name,
    required this.url,
    this.faviconUrl,
    this.order = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'faviconUrl': faviconUrl,
    'order': order,
    'createdAt': createdAt,
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    faviconUrl: json['faviconUrl'] as String?,
    order: json['order'] as int? ?? 0,
    createdAt: json['createdAt'] as int? ?? 0,
  );
}
