import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_card.dart';

class CardService {
  static const _key = 'business_card';
  final SharedPreferences _prefs;

  CardService(this._prefs);

  BusinessCard? get() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    return BusinessCard.fromJson(jsonDecode(raw));
  }

  Future<void> save(BusinessCard card) async {
    await _prefs.setString(_key, jsonEncode(card.toJson()));
  }

  Future<void> delete() async {
    await _prefs.remove(_key);
  }
}
