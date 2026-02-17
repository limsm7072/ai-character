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
  static const _routineCheckIntervalKey = 'routine_check_interval';
  static const _characterNameKey = 'character_name';

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

  String get voicePreset => _prefs.getString(_voicePresetKey) ?? 'sunhi';
  Future<void> setVoicePreset(String preset) =>
      _prefs.setString(_voicePresetKey, preset);

  /// Routine check interval in seconds (how often to check unchecked past routines)
  int get routineCheckInterval =>
      _prefs.getInt(_routineCheckIntervalKey) ?? 300;
  Future<void> setRoutineCheckInterval(int seconds) =>
      _prefs.setInt(_routineCheckIntervalKey, seconds);

  String get characterName => _prefs.getString(_characterNameKey) ?? '루나';
  Future<void> setCharacterName(String name) =>
      _prefs.setString(_characterNameKey, name);

  // Weather settings
  static const _weatherApiKeyKey = 'weather_api_key';
  static const _weatherNxKey = 'weather_nx';
  static const _weatherNyKey = 'weather_ny';
  static const _weatherEnabledKey = 'weather_enabled';

  String get weatherApiKey => _prefs.getString(_weatherApiKeyKey) ?? '';
  Future<void> setWeatherApiKey(String key) =>
      _prefs.setString(_weatherApiKeyKey, key);

  int get weatherNx => _prefs.getInt(_weatherNxKey) ?? 60;
  Future<void> setWeatherNx(int nx) => _prefs.setInt(_weatherNxKey, nx);

  int get weatherNy => _prefs.getInt(_weatherNyKey) ?? 127;
  Future<void> setWeatherNy(int ny) => _prefs.setInt(_weatherNyKey, ny);

  bool get weatherEnabled => _prefs.getBool(_weatherEnabledKey) ?? false;
  Future<void> setWeatherEnabled(bool v) =>
      _prefs.setBool(_weatherEnabledKey, v);

  // Calendar: lunar & D-Day toggles
  static const _showLunarKey = 'show_lunar';
  static const _showDDayKey = 'show_dday';

  bool get showLunar => _prefs.getBool(_showLunarKey) ?? true;
  Future<void> setShowLunar(bool v) => _prefs.setBool(_showLunarKey, v);

  bool get showDDay => _prefs.getBool(_showDDayKey) ?? true;
  Future<void> setShowDDay(bool v) => _prefs.setBool(_showDDayKey, v);
}
