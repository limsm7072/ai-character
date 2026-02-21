import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/notion_database.dart';
import '../service_locator.dart';
import '../services/notion_database_service.dart';

class NotionDatabaseViewScreen extends StatefulWidget {
  final NotionDatabase database;

  const NotionDatabaseViewScreen({
    super.key,
    required this.database,
  });

  @override
  State<NotionDatabaseViewScreen> createState() =>
      _NotionDatabaseViewScreenState();
}

class _NotionDatabaseViewScreenState extends State<NotionDatabaseViewScreen> {
  NotionDatabaseService get _service => getIt<NotionDatabaseService>();

  late NotionDatabase _db;
  bool _isKanban = false;
  String? _kanbanColumnId;
  String? _sortColumnId;
  bool _sortAsc = true;
  String? _filterColumnId;
  String _filterValue = '';

  @override
  void initState() {
    super.initState();
    _db = widget.database;
    // Auto-select first select column for kanban
    final selectCols =
        _db.columns.where((c) => c.type == ColumnType.select).toList();
    if (selectCols.isNotEmpty) _kanbanColumnId = selectCols.first.id;
  }

  Future<void> _save() async {
    await _service.update(_db);
  }

  List<DatabaseRow> get _displayRows {
    var rows = List<DatabaseRow>.from(_db.rows);
    // Filter
    if (_filterColumnId != null && _filterValue.isNotEmpty) {
      rows = _db.filteredBy(_filterColumnId!, _filterValue);
    }
    // Sort
    if (_sortColumnId != null) {
      rows = _db.sortedBy(_sortColumnId!, _sortAsc);
      if (_filterColumnId != null && _filterValue.isNotEmpty) {
        // Apply filter on sorted
        final fv = _filterValue.toLowerCase();
        rows = rows.where((r) {
          final cell = r.cells[_filterColumnId!];
          if (cell == null) return false;
          return cell.toString().toLowerCase().contains(fv);
        }).toList();
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectCols =
        _db.columns.where((c) => c.type == ColumnType.select).toList();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _renameDb,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_db.icon ?? '📊', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(_db.title, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        actions: [
          // View toggle
          if (selectCols.isNotEmpty)
            IconButton(
              icon: Icon(_isKanban ? Icons.table_chart : Icons.view_kanban),
              tooltip: _isKanban ? '테이블 뷰' : '칸반 뷰',
              onPressed: () => setState(() => _isKanban = !_isKanban),
            ),
          // Filter
          IconButton(
            icon: Icon(Icons.filter_list,
                color: _filterColumnId != null ? theme.colorScheme.primary : null),
            onPressed: _showFilterSheet,
          ),
          // Add column
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '컬럼 추가',
            onPressed: _addColumn,
          ),
        ],
      ),
      body: _isKanban ? _buildKanban() : _buildTable(),
      floatingActionButton: !_isKanban
          ? FloatingActionButton(
              mini: true,
              onPressed: _addRow,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // ─── Table View ───

  Widget _buildTable() {
    final rows = _displayRows;
    if (_db.columns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('컬럼을 추가해주세요'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _addColumn,
              icon: const Icon(Icons.add),
              label: const Text('컬럼 추가'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            ..._db.columns.map((col) => DataColumn(
                  label: GestureDetector(
                    onTap: () => _toggleSort(col.id),
                    onLongPress: () => _showColumnMenu(col),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_columnTypeIcon(col.type), size: 14,
                            color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(col.name),
                        if (_sortColumnId == col.id)
                          Icon(
                            _sortAsc
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 14,
                          ),
                      ],
                    ),
                  ),
                )),
            const DataColumn(label: SizedBox(width: 40)),
          ],
          rows: rows.map((row) {
            return DataRow(
              cells: [
                ..._db.columns.map((col) => DataCell(
                      _buildCell(row, col),
                      onTap: () => _editCell(row, col),
                    )),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      setState(() => _db.rows.removeWhere((r) => r.id == row.id));
                      _save();
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCell(DatabaseRow row, DatabaseColumn col) {
    final value = row.cells[col.id];
    switch (col.type) {
      case ColumnType.checkbox:
        return Checkbox(
          value: value == true,
          onChanged: (v) {
            setState(() => row.cells[col.id] = v);
            _save();
          },
        );
      case ColumnType.select:
        if (value == null || value.toString().isEmpty) {
          return const Text('-', style: TextStyle(color: Colors.grey));
        }
        return Chip(
          label: Text(value.toString(), style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          backgroundColor: _selectColor(value.toString()),
        );
      case ColumnType.number:
        return Text(
          value?.toString() ?? '',
          textAlign: TextAlign.right,
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        );
      case ColumnType.date:
        return Text(value?.toString() ?? '',
            style: TextStyle(color: Colors.grey.shade700));
      default:
        return Text(value?.toString() ?? '',
            maxLines: 2, overflow: TextOverflow.ellipsis);
    }
  }

  void _editCell(DatabaseRow row, DatabaseColumn col) {
    if (col.type == ColumnType.checkbox) return; // handled inline

    if (col.type == ColumnType.select) {
      _pickSelect(row, col);
      return;
    }

    if (col.type == ColumnType.date) {
      _pickDate(row, col);
      return;
    }

    final ctrl = TextEditingController(
        text: row.cells[col.id]?.toString() ?? '');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(col.name),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: col.type == ColumnType.number
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(hintText: col.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (col.type == ColumnType.number) {
                  row.cells[col.id] = num.tryParse(ctrl.text);
                } else {
                  row.cells[col.id] = ctrl.text;
                }
              });
              _save();
              Navigator.pop(c);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _pickSelect(DatabaseRow row, DatabaseColumn col) {
    final options = col.selectOptions ?? [];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(col.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Clear option
                  ActionChip(
                    label: const Text('없음'),
                    onPressed: () {
                      setState(() => row.cells[col.id] = '');
                      _save();
                      Navigator.pop(ctx);
                    },
                  ),
                  ...options.map((opt) => ActionChip(
                        label: Text(opt),
                        backgroundColor: _selectColor(opt),
                        onPressed: () {
                          setState(() => row.cells[col.id] = opt);
                          _save();
                          Navigator.pop(ctx);
                        },
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickDate(DatabaseRow row, DatabaseColumn col) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        row.cells[col.id] =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
      _save();
    }
  }

  // ─── Kanban View ───

  Widget _buildKanban() {
    if (_kanbanColumnId == null) {
      return const Center(child: Text('Select 타입 컬럼이 필요합니다'));
    }
    final col = _db.columns.firstWhere((c) => c.id == _kanbanColumnId,
        orElse: () => _db.columns.first);
    final options = col.selectOptions ?? [];
    final rows = _displayRows;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unset column
          _kanbanColumn('미분류', rows.where((r) {
            final v = r.cells[_kanbanColumnId!];
            return v == null || v.toString().isEmpty;
          }).toList(), col),
          ...options.map((opt) => _kanbanColumn(
              opt,
              rows
                  .where((r) => r.cells[_kanbanColumnId!]?.toString() == opt)
                  .toList(),
              col)),
        ],
      ),
    );
  }

  Widget _kanbanColumn(
      String title, List<DatabaseRow> rows, DatabaseColumn kanbanCol) {
    final theme = Theme.of(context);
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectColor(title),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                Text('${rows.length}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Cards
          ...rows.map((row) => _kanbanCard(row)),
          // Add button
          TextButton.icon(
            onPressed: () {
              _addRow(
                  preset: {_kanbanColumnId!: title == '미분류' ? '' : title});
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('추가', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _kanbanCard(DatabaseRow row) {
    // Show first text column value as title
    final textCols = _db.columns.where((c) =>
        c.type == ColumnType.text && c.id != _kanbanColumnId);
    final title = textCols.isNotEmpty
        ? row.cells[textCols.first.id]?.toString() ?? ''
        : row.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.isEmpty ? '(비어있음)' : title,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Show other fields
            ..._db.columns
                .where((c) =>
                    c.id != _kanbanColumnId &&
                    (textCols.isEmpty || c.id != textCols.first.id) &&
                    row.cells[c.id] != null &&
                    row.cells[c.id].toString().isNotEmpty)
                .take(2)
                .map((c) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${c.name}: ${row.cells[c.id]}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
          ],
        ),
      ),
    );
  }

  // ─── Column Operations ───

  void _addColumn() {
    String name = '';
    ColumnType type = ColumnType.text;
    String optionsText = '';

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('컬럼 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(labelText: '컬럼 이름'),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ColumnType>(
                value: type,
                decoration: const InputDecoration(labelText: '타입'),
                items: ColumnType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_columnTypeName(t)),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => type = v!),
              ),
              if (type == ColumnType.select) ...[
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: '옵션 (쉼표로 구분)',
                    hintText: '예: 할일, 진행중, 완료',
                  ),
                  onChanged: (v) => optionsText = v,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (name.isEmpty) return;
                final col = DatabaseColumn(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  type: type,
                  selectOptions: type == ColumnType.select
                      ? optionsText
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList()
                      : null,
                  order: _db.columns.length,
                );
                setState(() => _db.columns.add(col));
                _save();
                Navigator.pop(c);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showColumnMenu(DatabaseColumn col) {
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
                _renameColumn(col);
              },
            ),
            if (col.type == ColumnType.select)
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('옵션 편집'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editSelectOptions(col);
                },
              ),
            if (_db.columns.length > 1)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  setState(() {
                    _db.columns.removeWhere((c) => c.id == col.id);
                    for (final row in _db.rows) {
                      row.cells.remove(col.id);
                    }
                  });
                  _save();
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _renameColumn(DatabaseColumn col) {
    final ctrl = TextEditingController(text: col.name);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('컬럼 이름 변경'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() => col.name = ctrl.text);
              _save();
              Navigator.pop(c);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _editSelectOptions(DatabaseColumn col) {
    final ctrl = TextEditingController(
        text: col.selectOptions?.join(', ') ?? '');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('옵션 편집'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '쉼표로 구분'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                col.selectOptions = ctrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
              });
              _save();
              Navigator.pop(c);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // ─── Row Operations ───

  void _addRow({Map<String, dynamic>? preset}) {
    final cells = <String, dynamic>{};
    if (preset != null) cells.addAll(preset);
    setState(() {
      _db.rows.add(DatabaseRow(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        cells: cells,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    });
    _save();
  }

  // ─── Sort / Filter ───

  void _toggleSort(String columnId) {
    setState(() {
      if (_sortColumnId == columnId) {
        if (_sortAsc) {
          _sortAsc = false;
        } else {
          _sortColumnId = null;
        }
      } else {
        _sortColumnId = columnId;
        _sortAsc = true;
      }
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (bCtx, setBS) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('필터',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _filterColumnId,
                  decoration: const InputDecoration(labelText: '컬럼'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('필터 없음')),
                    ..._db.columns.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        )),
                  ],
                  onChanged: (v) => setBS(() => _filterColumnId = v),
                ),
                if (_filterColumnId != null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '값',
                      hintText: '검색할 값',
                    ),
                    onChanged: (v) => _filterValue = v,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterColumnId = null;
                          _filterValue = '';
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('초기화'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      child: const Text('적용'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _renameDb() {
    final ctrl = TextEditingController(text: _db.title);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _db.title = ctrl.text);
              _save();
              Navigator.pop(c);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───

  String _columnTypeName(ColumnType type) {
    switch (type) {
      case ColumnType.text:
        return '텍스트';
      case ColumnType.number:
        return '숫자';
      case ColumnType.date:
        return '날짜';
      case ColumnType.checkbox:
        return '체크박스';
      case ColumnType.select:
        return '선택';
    }
  }

  IconData _columnTypeIcon(ColumnType type) {
    switch (type) {
      case ColumnType.text:
        return Icons.text_fields;
      case ColumnType.number:
        return Icons.numbers;
      case ColumnType.date:
        return Icons.calendar_today;
      case ColumnType.checkbox:
        return Icons.check_box_outlined;
      case ColumnType.select:
        return Icons.list;
    }
  }

  Color _selectColor(String option) {
    final colors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.orange.shade50,
      Colors.purple.shade50,
      Colors.red.shade50,
      Colors.teal.shade50,
      Colors.amber.shade50,
      Colors.pink.shade50,
    ];
    return colors[option.hashCode.abs() % colors.length];
  }
}
