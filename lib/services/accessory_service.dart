import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages character accessory/skin selections.
/// Stores selected skins per character in SharedPreferences.
class AccessoryService {
  final SharedPreferences _prefs;

  AccessoryService(this._prefs);

  String _key(String characterId) => 'character_skins_$characterId';

  /// Get saved skin selections for a character.
  List<String> getSelectedSkins(String characterId) {
    final raw = _prefs.getString(_key(characterId));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<String>();
  }

  /// Save skin selections for a character.
  Future<void> setSelectedSkins(
      String characterId, List<String> skins) async {
    await _prefs.setString(_key(characterId), jsonEncode(skins));
  }

  /// Check if character has custom skins saved.
  bool hasCustomSkins(String characterId) {
    return _prefs.containsKey(_key(characterId));
  }
}
