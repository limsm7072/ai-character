import 'package:flutter/material.dart';
import '../models/memo.dart';
import '../services/memo_service.dart';

class MemoListScreen extends StatefulWidget {
  final MemoService memoService;

  const MemoListScreen({super.key, required this.memoService});

  @override
  State<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  List<Memo> _memos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final memos = widget.memoService.getAll();
    memos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    setState(() => _memos = memos);
  }

  Future<void> _createMemo() async {
    final result = await _showEditSheet(null);
    if (result == true) _load();
  }

  Future<void> _editMemo(Memo memo) async {
    final result = await _showEditSheet(memo);
    if (result == true) _load();
  }

  Future<void> _deleteMemo(Memo memo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('메모 삭제'),
        content: Text('"${memo.title}" 메모를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.memoService.delete(memo.id);
      _load();
    }
  }

  Future<bool?> _showEditSheet(Memo? existing) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController = TextEditingController(text: existing?.content ?? '');
    final isNew = existing == null;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isNew ? '새 메모' : '메모 편집',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      Navigator.pop(ctx, false);
                      return;
                    }
                    if (isNew) {
                      await widget.memoService.add(title, content: contentController.text);
                    } else {
                      existing!.title = title;
                      existing.content = contentController.text;
                      await widget.memoService.update(existing);
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('저장'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              autofocus: isNew,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              minLines: 3,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메모')),
      body: _memos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '메모를 작성해보세요!',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(top: 8, bottom: 80 + MediaQuery.of(context).viewPadding.bottom),
              itemCount: _memos.length,
              itemBuilder: (_, i) => _buildMemoCard(_memos[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createMemo,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMemoCard(Memo memo) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text(memo.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (memo.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  memo.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatDate(memo.updatedAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
          onPressed: () => _deleteMemo(memo),
        ),
        onTap: () => _editMemo(memo),
        isThreeLine: memo.content.isNotEmpty,
      ),
    );
  }
}
