import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';

class BookmarkScreen extends StatefulWidget {
  final BookmarkService bookmarkService;

  const BookmarkScreen({super.key, required this.bookmarkService});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  static const _channel = MethodChannel('com.aicharacter.ai_character/audio');

  List<Bookmark> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _bookmarks = widget.bookmarkService.getAll();
    });
  }

  Future<void> _openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  IconData _guessIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('naver')) return Icons.language;
    if (lower.contains('google')) return Icons.search;
    if (lower.contains('youtube')) return Icons.play_circle_outline;
    if (lower.contains('instagram')) return Icons.camera_alt_outlined;
    if (lower.contains('github')) return Icons.code;
    if (lower.contains('twitter') || lower.contains('x.com')) return Icons.tag;
    if (lower.contains('facebook')) return Icons.facebook;
    if (lower.contains('kakao')) return Icons.chat_bubble_outline;
    return Icons.public;
  }

  Color _guessColor(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('naver')) return const Color(0xFF03C75A);
    if (lower.contains('google')) return const Color(0xFF4285F4);
    if (lower.contains('youtube')) return const Color(0xFFFF0000);
    if (lower.contains('instagram')) return const Color(0xFFE1306C);
    if (lower.contains('github')) return const Color(0xFF333333);
    if (lower.contains('twitter') || lower.contains('x.com')) return const Color(0xFF1DA1F2);
    if (lower.contains('facebook')) return const Color(0xFF1877F2);
    if (lower.contains('kakao')) return const Color(0xFFFEE500);
    return const Color(0xFF607D8B);
  }

  void _showAddDialog({Bookmark? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final isEditing = existing != null;

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(isEditing ? '바로가기 수정' : '바로가기 추가'),
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
                if (isEditing) {
                  existing.name = name;
                  existing.url = url;
                  existing.faviconUrl = _faviconFromUrl(url);
                  await widget.bookmarkService.update(existing);
                } else {
                  await widget.bookmarkService.add(name, url, faviconUrl: _faviconFromUrl(url));
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

  String _faviconFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}/favicon.ico';
    } catch (_) {
      return '';
    }
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
              await widget.bookmarkService.delete(bookmark.id);
              _load();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
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
        title: const Text('바로가기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
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
                    onPressed: () => _showAddDialog(),
                    child: const Text('추가하기'),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bookmarks.length,
              onReorder: (oldIdx, newIdx) async {
                if (newIdx > oldIdx) newIdx--;
                await widget.bookmarkService.reorder(oldIdx, newIdx);
                _load();
              },
              itemBuilder: (context, index) {
                final bm = _bookmarks[index];
                final iconColor = _guessColor(bm.url);
                return Card(
                  key: ValueKey(bm.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_guessIcon(bm.url), color: iconColor, size: 22),
                    ),
                    title: Text(bm.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      bm.url,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _showAddDialog(existing: bm);
                        if (value == 'delete') _confirmDelete(bm);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('수정')),
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
                    onTap: () => _openUrl(bm.url),
                  ),
                );
              },
            ),
    );
  }
}
