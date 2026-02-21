import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bookmark.dart';
import '../theme/app_colors.dart';
import '../services/bookmark_service.dart';
import '../service_locator.dart';

class BookmarkScreen extends StatefulWidget {
  final String? title;

  const BookmarkScreen({super.key, this.title});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  final BookmarkService _bookmarkService = getIt<BookmarkService>();
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');

  List<Bookmark> _bookmarks = [];

  static const _presets = [
    _PresetSite('네이버', 'https://www.naver.com'),
    _PresetSite('구글', 'https://www.google.com'),
    _PresetSite('유튜브', 'https://www.youtube.com'),
    _PresetSite('인스타그램', 'https://www.instagram.com'),
    _PresetSite('카카오톡', 'https://www.kakao.com'),
    _PresetSite('다음', 'https://www.daum.net'),
    _PresetSite('쿠팡', 'https://www.coupang.com'),
    _PresetSite('배달의민족', 'https://www.baemin.com'),
    _PresetSite('당근마켓', 'https://www.daangn.com'),
    _PresetSite('토스', 'https://toss.im'),
    _PresetSite('넷플릭스', 'https://www.netflix.com'),
    _PresetSite('트위터(X)', 'https://x.com'),
    _PresetSite('페이스북', 'https://www.facebook.com'),
    _PresetSite('틱톡', 'https://www.tiktok.com'),
    _PresetSite('깃허브', 'https://github.com'),
    _PresetSite('디스코드', 'https://discord.com'),
    _PresetSite('트위치', 'https://www.twitch.tv'),
    _PresetSite('스포티파이', 'https://www.spotify.com'),
    _PresetSite('레딧', 'https://www.reddit.com'),
    _PresetSite('네이버 지도', 'https://map.naver.com'),
    _PresetSite('카카오맵', 'https://map.kakao.com'),
    _PresetSite('벅스', 'https://www.bugs.co.kr'),
    _PresetSite('멜론', 'https://www.melon.com'),
    _PresetSite('네이버 웹툰', 'https://comic.naver.com'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _bookmarks = _bookmarkService.getAll();
    });
  }

  Future<void> _openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  String _faviconApiUrl(String url) {
    try {
      final host = Uri.parse(url).host;
      // Try higher quality icon services
      return 'https://icons.duckduckgo.com/ip3/$host.ico';
    } catch (_) {
      return '';
    }
  }

  Widget _faviconWidget(String url, {double size = 24}) {
    final favUrl = _faviconApiUrl(url);
    if (favUrl.isEmpty) {
      return Icon(Icons.public, size: size, color: AppColors.grey400);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        favUrl,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(Icons.public, size: size, color: AppColors.grey400),
      ),
    );
  }

  void _showAddSheet() {
    final existingUrls = _bookmarks.map((b) => Uri.parse(b.url).host).toSet();
    final available = _presets.where((p) {
      try {
        return !existingUrls.contains(Uri.parse(p.url).host);
      } catch (_) {
        return true;
      }
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text('바로가기 추가', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCustomAddDialog();
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('직접 입력'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: available.length,
                    itemBuilder: (_, i) {
                      final preset = available[i];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: _faviconWidget(preset.url, size: 24)),
                        ),
                        title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          Uri.parse(preset.url).host,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        trailing: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
                        onTap: () async {
                          await _bookmarkService.add(preset.name, preset.url, faviconUrl: _faviconApiUrl(preset.url));
                          _load();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomAddDialog({Bookmark? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final isEditing = existing != null;

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(isEditing ? '바로가기 수정' : '직접 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: '이름',
                  hintText: '예: 네이버',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://www.example.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('취소', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                var url = urlCtrl.text.trim();
                if (name.isEmpty || url.isEmpty) return;
                if (!url.startsWith('http://') && !url.startsWith('https://')) {
                  url = 'https://$url';
                }
                if (existing != null) {
                  final updated = Bookmark(
                    id: existing.id,
                    name: name,
                    url: url,
                    faviconUrl: _faviconApiUrl(url),
                    order: existing.order,
                    createdAt: existing.createdAt,
                  );
                  await _bookmarkService.update(updated);
                } else {
                  await _bookmarkService.add(name, url, faviconUrl: _faviconApiUrl(url));
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: Text(isEditing ? '수정' : '추가'),
            ),
          ],
        );
      },
    );
  }

  void _showBookmarkOptions(Bookmark bm) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(bm.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomAddDialog(existing: bm);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('삭제', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(bm);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Bookmark bookmark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: Text("'${bookmark.name}' 바로가기를 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _bookmarkService.delete(bookmark.id);
              _load();
            },
            child: Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '바로가기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddSheet,
          ),
        ],
      ),
      body: _bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('바로가기가 없습니다', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _showAddSheet,
                    child: const Text('추가하기'),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _bookmarks.length,
              itemBuilder: (context, index) {
                final bm = _bookmarks[index];
                return GestureDetector(
                  onTap: () => _openUrl(bm.url),
                  onLongPress: () => _showBookmarkOptions(bm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: _faviconWidget(bm.url, size: 32)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bm.name,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _PresetSite {
  final String name;
  final String url;
  const _PresetSite(this.name, this.url);
}
