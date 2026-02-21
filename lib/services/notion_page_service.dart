import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notion_page.dart';

class NotionPageService {
  static const _key = 'notion_pages';
  final SharedPreferences _prefs;

  NotionPageService(this._prefs);

  List<NotionPage> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => NotionPage.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  NotionPage? getById(String id) {
    return getAll().where((p) => p.id == id).firstOrNull;
  }

  List<NotionPage> getRecent({int limit = 3}) {
    return getAll().take(limit).toList();
  }

  List<NotionPage> getFavorites() {
    return getAll().where((p) => p.isFavorite).toList();
  }

  Future<NotionPage> add({String title = '새 페이지', String? icon}) async {
    final pages = getAll();
    final page = NotionPage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      icon: icon,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    pages.insert(0, page);
    await _save(pages);
    return page;
  }

  Future<void> update(NotionPage page) async {
    final pages = getAll();
    final idx = pages.indexWhere((p) => p.id == page.id);
    if (idx >= 0) {
      page.updatedAt = DateTime.now().millisecondsSinceEpoch;
      pages[idx] = page;
      await _save(pages);
    }
  }

  Future<void> delete(String id) async {
    final pages = getAll();
    pages.removeWhere((p) => p.id == id);
    await _save(pages);
  }

  // Block operations
  Future<void> addBlock(String pageId, PageBlock block, {int? index}) async {
    final page = getById(pageId);
    if (page == null) return;
    if (index != null && index <= page.blocks.length) {
      page.blocks.insert(index, block);
    } else {
      page.blocks.add(block);
    }
    await update(page);
  }

  Future<void> updateBlock(String pageId, PageBlock block) async {
    final page = getById(pageId);
    if (page == null) return;
    final idx = page.blocks.indexWhere((b) => b.id == block.id);
    if (idx >= 0) {
      page.blocks[idx] = block;
      await update(page);
    }
  }

  Future<void> removeBlock(String pageId, String blockId) async {
    final page = getById(pageId);
    if (page == null) return;
    page.blocks.removeWhere((b) => b.id == blockId);
    await update(page);
  }

  Future<void> reorderBlocks(String pageId, int oldIndex, int newIndex) async {
    final page = getById(pageId);
    if (page == null) return;
    if (newIndex > oldIndex) newIndex--;
    final block = page.blocks.removeAt(oldIndex);
    page.blocks.insert(newIndex, block);
    await update(page);
  }

  // Export
  String exportAsJson(NotionPage page) {
    return const JsonEncoder.withIndent('  ').convert(page.toJson());
  }

  String exportAsMarkdown(NotionPage page) {
    return page.toMarkdown();
  }

  String exportAllAsJson() {
    final pages = getAll();
    return const JsonEncoder.withIndent('  ')
        .convert(pages.map((p) => p.toJson()).toList());
  }

  // Import
  NotionPage? importFromJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);
      if (data is Map<String, dynamic>) {
        final page = NotionPage.fromJson(data);
        // Assign new ID to avoid conflicts
        page.id = DateTime.now().millisecondsSinceEpoch.toString();
        page.updatedAt = DateTime.now().millisecondsSinceEpoch;
        final pages = getAll();
        pages.insert(0, page);
        _save(pages);
        return page;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  List<NotionPage> importAllFromJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);
      if (data is List) {
        final pages = getAll();
        final imported = <NotionPage>[];
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final page = NotionPage.fromJson(item);
            page.id = DateTime.now().millisecondsSinceEpoch.toString() +
                '_${imported.length}';
            page.updatedAt = DateTime.now().millisecondsSinceEpoch;
            imported.add(page);
            pages.insert(0, page);
          }
        }
        _save(pages);
        return imported;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<NotionPage> pages) async {
    await _prefs.setString(
        _key, jsonEncode(pages.map((p) => p.toJson()).toList()));
  }
}
