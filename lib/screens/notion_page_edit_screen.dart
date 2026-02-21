import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/notion_page.dart';
import '../service_locator.dart';
import '../services/notion_page_service.dart';

class NotionPageEditScreen extends StatefulWidget {
  final NotionPage page;

  const NotionPageEditScreen({
    super.key,
    required this.page,
  });

  @override
  State<NotionPageEditScreen> createState() => _NotionPageEditScreenState();
}

class _NotionPageEditScreenState extends State<NotionPageEditScreen> {
  NotionPageService get _service => getIt<NotionPageService>();

  late NotionPage _page;
  late TextEditingController _titleCtrl;
  final Map<String, TextEditingController> _blockCtrls = {};
  final Map<String, FocusNode> _blockFocusNodes = {};
  Timer? _saveTimer;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _page = widget.page;
    _titleCtrl = TextEditingController(text: _page.title);
    _titleCtrl.addListener(_onChanged);
    for (final b in _page.blocks) {
      _ensureController(b);
    }
  }

  void _ensureController(PageBlock block) {
    if (!_blockCtrls.containsKey(block.id)) {
      final ctrl = TextEditingController(text: block.content);
      ctrl.addListener(_onChanged);
      _blockCtrls[block.id] = ctrl;
      _blockFocusNodes[block.id] = FocusNode();
    }
    if (block.children != null) {
      for (final child in block.children!) {
        _ensureController(child);
      }
    }
  }

  void _onChanged() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    if (!_dirty) return;
    _page.title = _titleCtrl.text;
    for (final b in _page.blocks) {
      _syncBlock(b);
    }
    await _service.update(_page);
    _dirty = false;
  }

  void _syncBlock(PageBlock block) {
    final ctrl = _blockCtrls[block.id];
    if (ctrl != null) block.content = ctrl.text;
    if (block.children != null) {
      for (final child in block.children!) {
        _syncBlock(child);
      }
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Force save on exit
    _page.title = _titleCtrl.text;
    for (final b in _page.blocks) {
      _syncBlock(b);
    }
    _service.update(_page);
    _titleCtrl.dispose();
    for (final ctrl in _blockCtrls.values) {
      ctrl.dispose();
    }
    for (final node in _blockFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _addBlock(BlockType type, {int? insertAt}) {
    final block = PageBlock(
      id: _newId(),
      type: type,
      isChecked: type == BlockType.todo ? false : null,
      isExpanded: type == BlockType.toggle ? true : null,
      calloutIcon: type == BlockType.callout ? '💡' : null,
      children: type == BlockType.toggle ? [] : null,
      tableData: type == BlockType.table
          ? [
              ['열 1', '열 2'],
              ['', ''],
            ]
          : null,
    );
    _ensureController(block);
    setState(() {
      if (insertAt != null && insertAt <= _page.blocks.length) {
        _page.blocks.insert(insertAt, block);
      } else {
        _page.blocks.add(block);
      }
    });
    _onChanged();
    // Focus new block after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _blockFocusNodes[block.id]?.requestFocus();
    });
  }

  void _removeBlock(int index) {
    final block = _page.blocks[index];
    setState(() {
      _page.blocks.removeAt(index);
    });
    _blockCtrls.remove(block.id)?.dispose();
    _blockFocusNodes.remove(block.id)?.dispose();
    _onChanged();
  }

  void _showBlockTypePicker({int? insertAt}) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('블록 추가',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _blockTypeChip('텍스트', Icons.text_fields, BlockType.text, insertAt),
                  _blockTypeChip('제목 1', Icons.title, BlockType.heading1, insertAt),
                  _blockTypeChip('제목 2', Icons.text_increase, BlockType.heading2, insertAt),
                  _blockTypeChip('제목 3', Icons.text_decrease, BlockType.heading3, insertAt),
                  _blockTypeChip('할 일', Icons.check_box_outlined, BlockType.todo, insertAt),
                  _blockTypeChip('구분선', Icons.horizontal_rule, BlockType.divider, insertAt),
                  _blockTypeChip('콜아웃', Icons.lightbulb_outline, BlockType.callout, insertAt),
                  _blockTypeChip('인용', Icons.format_quote, BlockType.quote, insertAt),
                  _blockTypeChip('목록', Icons.format_list_bulleted, BlockType.bulletList, insertAt),
                  _blockTypeChip('번호 목록', Icons.format_list_numbered, BlockType.numberList, insertAt),
                  _blockTypeChip('토글', Icons.expand_more, BlockType.toggle, insertAt),
                  _blockTypeChip('표', Icons.table_chart_outlined, BlockType.table, insertAt),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blockTypeChip(String label, IconData icon, BlockType type, int? insertAt) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () {
        Navigator.pop(context);
        _addBlock(type, insertAt: insertAt);
      },
    );
  }

  void _changeIcon() {
    final icons = ['📝', '📋', '📌', '📎', '📁', '📂', '📊', '📈', '🗂️',
      '💡', '🔖', '🎯', '⭐', '❤️', '🔥', '✅', '🚀', '💻', '🎨', '🎵',
      '📷', '🏠', '🌍', '🌟', '🍀', '🎁', '🔑', '📱', '🖊️', null];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('아이콘 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: icons.map((e) => GestureDetector(
                  onTap: () {
                    setState(() => _page.icon = e);
                    _onChanged();
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _page.icon == e
                          ? Theme.of(ctx).colorScheme.primaryContainer
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e ?? '✕', style: const TextStyle(fontSize: 24)),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('JSON 복사'),
                onTap: () {
                  final json = _service.exportAsJson(_page);
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
                  final md = _service.exportAsMarkdown(_page);
                  Clipboard.setData(ClipboardData(text: md));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('마크다운이 클립보드에 복사되었습니다')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('텍스트 복사'),
                onTap: () {
                  // Plain text: just block contents
                  final sb = StringBuffer();
                  sb.writeln(_page.title);
                  for (final b in _page.blocks) {
                    if (b.content.isNotEmpty) sb.writeln(b.content);
                  }
                  Clipboard.setData(ClipboardData(text: sb.toString()));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('텍스트가 클립보드에 복사되었습니다')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _changeIcon,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_page.icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(_page.icon!, style: const TextStyle(fontSize: 20)),
                ),
              Flexible(
                child: Text(
                  _page.title.isEmpty ? '새 페이지' : _page.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _page.isFavorite ? Icons.star : Icons.star_border,
              color: _page.isFavorite ? Colors.amber : null,
            ),
            onPressed: () {
              setState(() => _page.isFavorite = !_page.isFavorite);
              _onChanged();
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showShareSheet,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title field
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '제목 없음',
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
            const SizedBox(height: 8),
            // Blocks
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _page.blocks.length,
              onReorder: (old, newIdx) {
                setState(() {
                  if (newIdx > old) newIdx--;
                  final b = _page.blocks.removeAt(old);
                  _page.blocks.insert(newIdx, b);
                });
                _onChanged();
              },
              itemBuilder: (ctx, i) {
                final block = _page.blocks[i];
                return _buildBlockRow(block, i);
              },
            ),
            const SizedBox(height: 16),
            // Add block button
            Center(
              child: TextButton.icon(
                onPressed: () => _showBlockTypePicker(),
                icon: const Icon(Icons.add),
                label: const Text('블록 추가'),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockRow(PageBlock block, int index) {
    return Padding(
      key: ValueKey(block.id),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle + menu
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.drag_indicator,
                  size: 20, color: Colors.grey.shade400),
            ),
          ),
          // Block content
          Expanded(child: _buildBlockWidget(block, index)),
          // Delete
          GestureDetector(
            onTap: () => _removeBlock(index),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockWidget(PageBlock block, int index) {
    switch (block.type) {
      case BlockType.text:
        return _textField(block);
      case BlockType.heading1:
        return _textField(block,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
      case BlockType.heading2:
        return _textField(block,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold));
      case BlockType.heading3:
        return _textField(block,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
      case BlockType.todo:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: block.isChecked ?? false,
              onChanged: (v) {
                setState(() => block.isChecked = v);
                _onChanged();
              },
            ),
            Expanded(
              child: _textField(block,
                  style: TextStyle(
                    decoration: (block.isChecked ?? false)
                        ? TextDecoration.lineThrough
                        : null,
                    color: (block.isChecked ?? false) ? Colors.grey : null,
                  )),
            ),
          ],
        );
      case BlockType.divider:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(),
        );
      case BlockType.callout:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _pickCalloutIcon(block),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Text(block.calloutIcon ?? '💡',
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              Expanded(child: _textField(block)),
            ],
          ),
        );
      case BlockType.quote:
        return Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 4,
              ),
            ),
          ),
          child: _textField(block,
              style: const TextStyle(fontStyle: FontStyle.italic)),
        );
      case BlockType.bulletList:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12, right: 8),
              child: Text('•', style: TextStyle(fontSize: 18)),
            ),
            Expanded(child: _textField(block)),
          ],
        );
      case BlockType.numberList:
        // Find index among numberList blocks
        int num = 1;
        for (final b in _page.blocks) {
          if (b.id == block.id) break;
          if (b.type == BlockType.numberList) num++;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 8),
              child: Text('$num.', style: const TextStyle(fontSize: 16)),
            ),
            Expanded(child: _textField(block)),
          ],
        );
      case BlockType.toggle:
        return _buildToggle(block);
      case BlockType.table:
        return _buildTable(block);
    }
  }

  Widget _textField(PageBlock block, {TextStyle? style}) {
    _ensureController(block);
    return TextField(
      controller: _blockCtrls[block.id],
      focusNode: _blockFocusNodes[block.id],
      style: style,
      maxLines: null,
      decoration: InputDecoration(
        hintText: _hintForType(block.type),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  String _hintForType(BlockType type) {
    switch (type) {
      case BlockType.text:
        return '텍스트를 입력하세요';
      case BlockType.heading1:
        return '제목 1';
      case BlockType.heading2:
        return '제목 2';
      case BlockType.heading3:
        return '제목 3';
      case BlockType.todo:
        return '할 일';
      case BlockType.callout:
        return '콜아웃';
      case BlockType.quote:
        return '인용';
      case BlockType.bulletList:
      case BlockType.numberList:
        return '목록 항목';
      case BlockType.toggle:
        return '토글';
      default:
        return '';
    }
  }

  Widget _buildToggle(PageBlock block) {
    _ensureController(block);
    final children = block.children ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() => block.isExpanded = !(block.isExpanded ?? true));
                _onChanged();
              },
              child: Icon(
                (block.isExpanded ?? true)
                    ? Icons.expand_more
                    : Icons.chevron_right,
                size: 24,
              ),
            ),
            Expanded(child: _textField(block)),
          ],
        ),
        if (block.isExpanded ?? true)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              children: [
                ...children.asMap().entries.map((e) {
                  final childBlock = e.value;
                  _ensureController(childBlock);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: _textField(childBlock)),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              block.children!.removeAt(e.key);
                            });
                            _blockCtrls.remove(childBlock.id)?.dispose();
                            _blockFocusNodes.remove(childBlock.id)?.dispose();
                            _onChanged();
                          },
                          child: Icon(Icons.close,
                              size: 16, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      final child = PageBlock(
                        id: _newId(),
                        type: BlockType.text,
                      );
                      _ensureController(child);
                      setState(() {
                        block.children ??= [];
                        block.children!.add(child);
                      });
                      _onChanged();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _blockFocusNodes[child.id]?.requestFocus();
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('하위 블록', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTable(PageBlock block) {
    final data = block.tableData ?? [];
    if (data.isEmpty) return const SizedBox();

    final cols = data.first.length;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            defaultColumnWidth: const FixedColumnWidth(120),
            children: data.asMap().entries.map((rowEntry) {
              final ri = rowEntry.key;
              final row = rowEntry.value;
              return TableRow(
                decoration: ri == 0
                    ? BoxDecoration(color: Colors.grey.shade100)
                    : null,
                children: row.asMap().entries.map((cellEntry) {
                  final ci = cellEntry.key;
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: TextField(
                      controller: TextEditingController(text: cellEntry.value),
                      style: ri == 0
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.all(4),
                      ),
                      onChanged: (v) {
                        block.tableData![ri][ci] = v;
                        _onChanged();
                      },
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  block.tableData!.add(List.filled(cols, ''));
                });
                _onChanged();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('행 추가', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  for (final row in block.tableData!) {
                    row.add('');
                  }
                });
                _onChanged();
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('열 추가', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  void _pickCalloutIcon(PageBlock block) {
    final icons = ['💡', '⚠️', '❗', '✅', '📌', '🔥', '💬', '📎', '🎯', '⭐'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: icons
                .map((e) => GestureDetector(
                      onTap: () {
                        setState(() => block.calloutIcon = e);
                        _onChanged();
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: block.calloutIcon == e
                              ? Theme.of(ctx).colorScheme.primaryContainer
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
