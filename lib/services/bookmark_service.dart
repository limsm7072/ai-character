import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bookmark.dart';

class BookmarkService {
  static const _key = 'bookmarks';
  static const _initializedKey = 'bookmarks_initialized';
  final SharedPreferences _prefs;

  BookmarkService(this._prefs) {
    _ensureDefaults();
  }

  void _ensureDefaults() {
    if (_prefs.getBool(_initializedKey) == true) return;
    final existing = _prefs.getString(_key);
    if (existing != null) {
      _prefs.setBool(_initializedKey, true);
      return;
    }
    final defaults = [
      Bookmark(
        id: 'default_naver',
        name: '네이버',
        url: 'https://m.naver.com',
        faviconUrl: 'https://www.naver.com/favicon.ico',
        order: 0,
        createdAt: 0,
      ),
      Bookmark(
        id: 'default_google',
        name: '구글',
        url: 'https://www.google.com',
        faviconUrl: 'https://www.google.com/favicon.ico',
        order: 1,
        createdAt: 0,
      ),
      Bookmark(
        id: 'default_youtube',
        name: '유튜브',
        url: 'https://m.youtube.com',
        faviconUrl: 'https://www.youtube.com/favicon.ico',
        order: 2,
        createdAt: 0,
      ),
      Bookmark(
        id: 'default_instagram',
        name: '인스타그램',
        url: 'https://www.instagram.com',
        faviconUrl: 'https://www.instagram.com/favicon.ico',
        order: 3,
        createdAt: 0,
      ),
      Bookmark(
        id: 'default_github',
        name: 'GitHub',
        url: 'https://github.com',
        faviconUrl: 'https://github.com/favicon.ico',
        order: 4,
        createdAt: 0,
      ),
    ];
    _prefs.setString(_key, jsonEncode(defaults.map((b) => b.toJson()).toList()));
    _prefs.setBool(_initializedKey, true);
  }

  List<Bookmark> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final bookmarks = list.map((e) => Bookmark.fromJson(e)).toList();
    bookmarks.sort((a, b) => a.order.compareTo(b.order));
    return bookmarks;
  }

  Future<void> _saveAll(List<Bookmark> bookmarks) async {
    final json = jsonEncode(bookmarks.map((b) => b.toJson()).toList());
    await _prefs.setString(_key, json);
  }

  Future<Bookmark> add(String name, String url, {String? faviconUrl}) async {
    final all = getAll();
    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      url: url,
      faviconUrl: faviconUrl,
      order: all.length,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    all.add(bookmark);
    await _saveAll(all);
    return bookmark;
  }

  Future<void> update(Bookmark bookmark) async {
    final all = getAll();
    final idx = all.indexWhere((b) => b.id == bookmark.id);
    if (idx >= 0) {
      all[idx] = bookmark;
      await _saveAll(all);
    }
  }

  Future<void> delete(String id) async {
    final all = getAll();
    all.removeWhere((b) => b.id == id);
    for (var i = 0; i < all.length; i++) {
      all[i].order = i;
    }
    await _saveAll(all);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final all = getAll();
    if (oldIndex < 0 || oldIndex >= all.length) return;
    if (newIndex < 0 || newIndex >= all.length) return;
    final item = all.removeAt(oldIndex);
    all.insert(newIndex, item);
    for (var i = 0; i < all.length; i++) {
      all[i].order = i;
    }
    await _saveAll(all);
  }
}
