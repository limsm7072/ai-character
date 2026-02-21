import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notion_page_service.dart';
import '../services/notion_database_service.dart';
import 'notion_page_list_screen.dart';
import 'notion_database_list_screen.dart';

class NotionScreen extends StatefulWidget {
  final NotionPageService pageService;
  final NotionDatabaseService dbService;

  const NotionScreen({
    super.key,
    required this.pageService,
    required this.dbService,
  });

  @override
  State<NotionScreen> createState() => _NotionScreenState();
}

class _NotionScreenState extends State<NotionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _pageListKey = GlobalKey<NotionPageListScreenState>();
  final _dbListKey = GlobalKey<NotionDatabaseListScreenState>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _importJson() async {
    // Try to read from clipboard
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클립보드에 텍스트가 없습니다')),
      );
      return;
    }

    final text = data.text!.trim();

    // Try to detect if it's a page or database
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('클립보드에서 가져오기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('페이지로 가져오기'),
              subtitle: const Text('JSON 형식의 페이지 데이터'),
              onTap: () {
                Navigator.pop(ctx);
                _importAsPage(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('데이터베이스로 가져오기'),
              subtitle: const Text('JSON 형식의 데이터베이스'),
              onTap: () {
                Navigator.pop(ctx);
                _importAsDatabase(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _importAsPage(String text) {
    try {
      // Try single page first
      final page = widget.pageService.importFromJson(text);
      if (page != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${page.title}" 페이지를 가져왔습니다')),
        );
        _pageListKey.currentState?.setState(() {});
        return;
      }
      // Try array of pages
      final pages = widget.pageService.importAllFromJson(text);
      if (pages.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pages.length}개 페이지를 가져왔습니다')),
        );
        _pageListKey.currentState?.setState(() {});
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 페이지 JSON 형식이 아닙니다')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가져오기 실패: JSON 형식을 확인해주세요')),
      );
    }
  }

  void _importAsDatabase(String text) {
    try {
      final db = widget.dbService.importFromJson(text);
      if (db != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${db.title}" 데이터베이스를 가져왔습니다')),
        );
        _dbListKey.currentState?.setState(() {});
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 데이터베이스 JSON 형식이 아닙니다')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가져오기 실패: JSON 형식을 확인해주세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('워크스페이스'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '가져오기',
            onPressed: _importJson,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (_tabCtrl.index == 0) {
                _pageListKey.currentState?.toggleSearch();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '페이지'),
            Tab(text: '데이터베이스'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          NotionPageListScreen(
            key: _pageListKey,
            service: widget.pageService,
          ),
          NotionDatabaseListScreen(
            key: _dbListKey,
            service: widget.dbService,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabCtrl.index == 0) {
            _pageListKey.currentState?.createNewPage();
          } else {
            _dbListKey.currentState?.createNewDb();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
