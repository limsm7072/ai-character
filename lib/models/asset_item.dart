class AssetItem {
  final String id;
  final String name;
  final String nameKo;
  final String emoji;
  final String category; // cat, dog, forest, farm, exotic, bird, aquatic, fantasy, pack
  final String source; // poly_pizza, sketchfab, kenney, quaternius, kaykit
  final String sourceUrl;
  final String license; // CC0, CC-BY

  const AssetItem({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.emoji,
    required this.category,
    required this.source,
    required this.sourceUrl,
    this.license = 'CC0',
  });

  /// Whether this asset has an individual 3D viewer page.
  bool get has3dViewer =>
      sourceUrl.contains('poly.pizza/m/') || source == 'sketchfab';

  /// URL suitable for loading in a WebView as a 3D viewer.
  String? get viewerUrl {
    // Sketchfab: construct embed URL from model ID
    if (source == 'sketchfab') {
      final match = RegExp(r'-([a-f0-9]{32})').firstMatch(sourceUrl);
      if (match != null) {
        return 'https://sketchfab.com/models/${match.group(1)}/embed'
            '?autostart=1&ui_theme=dark&ui_stop=0&ui_infos=0';
      }
    }
    // Poly Pizza individual model page (has built-in 3D viewer)
    if (sourceUrl.contains('poly.pizza/m/')) return sourceUrl;
    return null;
  }

  static const categoryLabels = {
    'cat': '고양이',
    'dog': '강아지',
    'forest': '숲속동물',
    'farm': '농장동물',
    'exotic': '동물원',
    'bird': '새',
    'aquatic': '수중동물',
    'fantasy': '판타지',
    'dino': '공룡',
    'monster': '몬스터',
    'character': '캐릭터',
  };

  static const categoryEmojis = {
    'cat': '🐱',
    'dog': '🐕',
    'forest': '🦊',
    'farm': '🐰',
    'exotic': '🐼',
    'bird': '🐦',
    'aquatic': '🐟',
    'fantasy': '🐲',
    'dino': '🦕',
    'monster': '👾',
    'character': '👤',
  };
}
