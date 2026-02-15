import 'package:shared_preferences/shared_preferences.dart';

/// Manages app settings persistence.
class SettingsService {
  static const _apiKeyKey = 'gemini_api_key';
  static const _nagFrequencyKey = 'nag_frequency';
  static const _nagIntensityKey = 'nag_intensity';
  static const _ttsEnabledKey = 'tts_enabled';
  static const _overlayEnabledKey = 'overlay_enabled';
  static const _selectedCharacterKey = 'selected_character';
  static const _voicePresetKey = 'voice_preset';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  String get apiKey => _prefs.getString(_apiKeyKey) ?? '';
  Future<void> setApiKey(String key) => _prefs.setString(_apiKeyKey, key);

  /// Nag frequency in seconds (minimum interval between nags)
  int get nagFrequency => _prefs.getInt(_nagFrequencyKey) ?? 30;
  Future<void> setNagFrequency(int seconds) =>
      _prefs.setInt(_nagFrequencyKey, seconds);

  /// Nag intensity: 0=gentle, 1=normal, 2=strict
  int get nagIntensity => _prefs.getInt(_nagIntensityKey) ?? 1;
  Future<void> setNagIntensity(int level) =>
      _prefs.setInt(_nagIntensityKey, level);

  bool get ttsEnabled => _prefs.getBool(_ttsEnabledKey) ?? true;
  Future<void> setTtsEnabled(bool enabled) =>
      _prefs.setBool(_ttsEnabledKey, enabled);

  bool get overlayEnabled => _prefs.getBool(_overlayEnabledKey) ?? true;
  Future<void> setOverlayEnabled(bool enabled) =>
      _prefs.setBool(_overlayEnabledKey, enabled);

  String get selectedCharacter =>
      _prefs.getString(_selectedCharacterKey) ?? 'chibi-stickers';
  Future<void> setSelectedCharacter(String characterId) =>
      _prefs.setString(_selectedCharacterKey, characterId);

  String get voicePreset => _prefs.getString(_voicePresetKey) ?? 'cute';
  Future<void> setVoicePreset(String preset) =>
      _prefs.setString(_voicePresetKey, preset);
}
