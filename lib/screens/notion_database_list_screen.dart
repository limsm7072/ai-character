import 'package:flutter/material.dart';
import '../models/notion_database.dart';
import '../service_locator.dart';
import '../services/notion_database_service.dart';
import 'notion_database_view_screen.dart';

class NotionDatabaseListScreen extends StatefulWidget {
  const NotionDatabaseListScreen({super.key});

  @override
  State<NotionDatabaseListScreen> createState() =>
      NotionDatabaseListScreenState();
}

class NotionDatabaseListScreenState extends State<NotionDatabaseListScreen> {
  NotionDatabaseService get _service => getIt<NotionDatabaseService>();

  List<NotionDatabase> _dbs = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _dbs = _service.getAll();
    });
  }

  Future<void> _createDb() async {
    final db = await _service.add();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotionDatabaseViewScreen(
          database: db,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openDb(NotionDatabase db) async {
    final latest = _service.getById(db.id) ?? db;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotionDatabaseViewScreen(
          database: latest,
        ),
      ),
    );
    _reload();
  }

  void _showDbMenu(NotionDatabase db) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('이름 변경'),
              onTap: () {
                Navigator.pop(ctx);
                _renameDb(db);
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
                    title: const Text('데이터베이스 삭제'),
                    content: Text('"${db.title}" 데이터베이스를 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child:
                            const Text('삭제', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _service.delete(db.id);
                  _reload();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameDb(NotionDatabase db) {
    final ctrl = TextEditingController(text: db.title);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '데이터베이스 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              db.title = ctrl.text;
              _service.update(db);
              Navigator.pop(c);
              _reload();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _dbs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_chart_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('데이터베이스가 없습니다',
                          style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _createDb,
                        icon: const Icon(Icons.add),
                        label: const Text('새 데이터베이스'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _dbs.length,
                  itemBuilder: (ctx, i) {
                    final db = _dbs[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Text(db.icon ?? '📊',
                            style: const TextStyle(fontSize: 28)),
                        title: Text(db.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${db.columns.length}개 컬럼 · ${db.rows.length}개 행 · ${_formatDate(db.updatedAt)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        onTap: () => _openDb(db),
                        onLongPress: () => _showDbMenu(db),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void createNewDb() => _createDb();
}
