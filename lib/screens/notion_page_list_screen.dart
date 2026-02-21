import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/notion_page.dart';
import '../services/notion_page_service.dart';
import 'notion_page_edit_screen.dart';

class NotionPageListScreen extends StatefulWidget {
  final NotionPageService service;

  const NotionPageListScreen({super.key, required this.service});

  @override
  State<NotionPageListScreen> createState() => NotionPageListScreenState();
}

class NotionPageListScreenState extends State<NotionPageListScreen> {
  List<NotionPage> _pages = [];
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _pages = widget.service.getAll();
    });
  }

  List<NotionPage> get _filtered {
    if (_searchQuery.isEmpty) return _pages;
    final q = _searchQuery.toLowerCase();
    return _pages.where((p) =>
        p.title.toLowerCase().contains(q) ||
        p.blocks.any((b) => b.content.toLowerCase().contains(q))).toList();
  }

  Future<void> _createPage() async {
    final page = await widget.service.add();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotionPageEditScreen(
          service: widget.service,
          page: page,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openPage(NotionPage page) async {
    // Re-fetch latest version
    final latest = widget.service.getById(page.id) ?? page;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotionPageEditScreen(
          service: widget.service,
          page: latest,
        ),
      ),
    );
    _reload();
  }

  void _showPageMenu(NotionPage page) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                page.isFavorite ? Icons.star : Icons.star_border,
                color: page.isFavorite ? Colors.amber : null,
              ),
              title: Text(page.isFavorite ? '즐겨찾기 해제' : '즐겨찾기'),
              onTap: () {
                page.isFavorite = !page.isFavorite;
                widget.service.update(page);
                Navigator.pop(ctx);
                _reload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON 복사'),
              onTap: () {
                final json = widget.service.exportAsJson(page);
                Clipboard.setData(ClipboardData(text: json));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON이 클립보드에 복사되었습니다')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('마크다운 복사'),
              onTap: () {
                final md = widget.service.exportAsMarkdown(page);
                Clipboard.setData(ClipboardData(text: md));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('마크다운이 클립보드에 복사되었습니다')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('페이지 복제'),
              onTap: () async {
                final json = widget.service.exportAsJson(page);
                widget.service.importFromJson(json);
                Navigator.pop(ctx);
                _reload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('삭제', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('페이지 삭제'),
                    content: Text('"${page.title}" 페이지를 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('삭제',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.service.delete(page.id);
                  _reload();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = _filtered;
    final favorites = pages.where((p) => p.isFavorite).toList();
    final others = pages.where((p) => !p.isFavorite).toList();

    return Column(
      children: [
        // Search
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: '페이지 검색...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showSearch = false;
                      _searchQuery = '';
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        // List
        Expanded(
          child: pages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('페이지가 없습니다',
                          style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _createPage,
                        icon: const Icon(Icons.add),
                        label: const Text('새 페이지'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (favorites.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text('⭐ 즐겨찾기',
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.amber.shade700)),
                      ),
                      ...favorites.map((p) => _pageCard(p)),
                      const SizedBox(height: 8),
                    ],
                    if (others.isNotEmpty) ...[
                      if (favorites.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text('전체 페이지',
                              style: theme.textTheme.labelLarge),
                        ),
                      ...others.map((p) => _pageCard(p)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _pageCard(NotionPage page) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Text(page.icon ?? '📝', style: const TextStyle(fontSize: 28)),
        title: Row(
          children: [
            if (page.isAutoGenerated)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('루나', style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold)),
              ),
            Expanded(
              child: Text(
                page.title.isEmpty ? '제목 없음' : (page.isAutoGenerated ? page.title.substring(5) : page.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${page.blocks.length}개 블록 · ${_formatDate(page.updatedAt)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: page.isFavorite
            ? const Icon(Icons.star, color: Colors.amber, size: 18)
            : null,
        onTap: () => _openPage(page),
        onLongPress: () => _showPageMenu(page),
      ),
    );
  }

  // Exposed for parent to trigger search
  void toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) _searchQuery = '';
    });
  }

  void createNewPage() => _createPage();
}
