enum ColumnType {
  text,
  number,
  date,
  checkbox,
  select,
}

class DatabaseColumn {
  String id;
  String name;
  ColumnType type;
  List<String>? selectOptions;
  int order;

  DatabaseColumn({
    required this.id,
    required this.name,
    required this.type,
    this.selectOptions,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    if (selectOptions != null) 'selectOptions': selectOptions,
    'order': order,
  };

  factory DatabaseColumn.fromJson(Map<String, dynamic> json) => DatabaseColumn(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    type: ColumnType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => ColumnType.text,
    ),
    selectOptions: (json['selectOptions'] as List?)?.cast<String>(),
    order: json['order'] as int? ?? 0,
  );
}

class DatabaseRow {
  String id;
  Map<String, dynamic> cells;
  int createdAt;

  DatabaseRow({
    required this.id,
    required this.cells,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'cells': cells,
    'createdAt': createdAt,
  };

  factory DatabaseRow.fromJson(Map<String, dynamic> json) => DatabaseRow(
    id: json['id'] as String,
    cells: Map<String, dynamic>.from(json['cells'] as Map? ?? {}),
    createdAt: json['createdAt'] as int? ?? 0,
  );
}

class NotionDatabase {
  String id;
  String title;
  String? icon;
  List<DatabaseColumn> columns;
  List<DatabaseRow> rows;
  int createdAt;
  int updatedAt;

  NotionDatabase({
    required this.id,
    required this.title,
    this.icon,
    List<DatabaseColumn>? columns,
    List<DatabaseRow>? rows,
    required this.createdAt,
    required this.updatedAt,
  })  : columns = columns ?? [],
        rows = rows ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (icon != null) 'icon': icon,
    'columns': columns.map((c) => c.toJson()).toList(),
    'rows': rows.map((r) => r.toJson()).toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory NotionDatabase.fromJson(Map<String, dynamic> json) => NotionDatabase(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    icon: json['icon'] as String?,
    columns: (json['columns'] as List?)
        ?.map((e) => DatabaseColumn.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    rows: (json['rows'] as List?)
        ?.map((e) => DatabaseRow.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    createdAt: json['createdAt'] as int? ?? 0,
    updatedAt: json['updatedAt'] as int? ?? 0,
  );

  List<DatabaseRow> sortedBy(String columnId, bool ascending) {
    final col = columns.firstWhere((c) => c.id == columnId,
        orElse: () => columns.first);
    final sorted = List<DatabaseRow>.from(rows);
    sorted.sort((a, b) {
      final va = a.cells[columnId];
      final vb = b.cells[columnId];
      if (va == null && vb == null) return 0;
      if (va == null) return ascending ? -1 : 1;
      if (vb == null) return ascending ? 1 : -1;
      int cmp;
      switch (col.type) {
        case ColumnType.number:
          cmp = ((va as num?) ?? 0).compareTo((vb as num?) ?? 0);
        case ColumnType.checkbox:
          cmp = ((va == true) ? 1 : 0).compareTo((vb == true) ? 1 : 0);
        default:
          cmp = va.toString().compareTo(vb.toString());
      }
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }

  List<DatabaseRow> filteredBy(String columnId, dynamic value) {
    return rows.where((r) {
      final cell = r.cells[columnId];
      if (value == null || value.toString().isEmpty) return true;
      if (cell == null) return false;
      return cell.toString().toLowerCase().contains(value.toString().toLowerCase());
    }).toList();
  }
}
