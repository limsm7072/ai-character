import 'dart:convert';
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

  // Calendar: lunar & D-Day toggles
  static const _showLunarKey = 'show_lunar';
  static const _showDDayKey = 'show_dday';

  bool get showLunar => _prefs.getBool(_showLunarKey) ?? true;
  Future<void> setShowLunar(bool v) => _prefs.setBool(_showLunarKey, v);

  bool get showDDay => _prefs.getBool(_showDDayKey) ?? true;
  Future<void> setShowDDay(bool v) => _prefs.setBool(_showDDayKey, v);

  // Weather location
  static const _weatherLatKey = 'weather_lat';
  static const _weatherLonKey = 'weather_lon';
  static const _weatherLocationNameKey = 'weather_location_name';

  double get weatherLat => _prefs.getDouble(_weatherLatKey) ?? 37.5665;
  double get weatherLon => _prefs.getDouble(_weatherLonKey) ?? 126.978;
  String get weatherLocationName => _prefs.getString(_weatherLocationNameKey) ?? '';

  Future<void> setWeatherLocation(double lat, double lon) async {
    await _prefs.setDouble(_weatherLatKey, lat);
    await _prefs.setDouble(_weatherLonKey, lon);
  }

  Future<void> setWeatherLocationName(String name) =>
      _prefs.setString(_weatherLocationNameKey, name);

  // Dashboard order
  static const _dashboardOrderKey = 'dashboard_order';
  static const defaultDashboardOrder = ['news', 'weather', 'routine', 'todo', 'card', 'calendar', 'stats', 'alarm', 'timer', 'memo', 'dday'];

  List<String> get dashboardOrder {
    final raw = _prefs.getString(_dashboardOrderKey);
    if (raw == null) return List.from(defaultDashboardOrder);
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      // Migrate old 'grid' to individual sections
      final gridIdx = list.indexOf('grid');
      if (gridIdx >= 0) {
        list.removeAt(gridIdx);
        for (final s in ['calendar', 'stats', 'alarm', 'timer', 'memo'].reversed) {
          if (!list.contains(s)) list.insert(gridIdx, s);
        }
      }
      // Ensure all sections present
      for (final s in defaultDashboardOrder) {
        if (!list.contains(s)) list.add(s);
      }
      list.removeWhere((s) => !defaultDashboardOrder.contains(s));
      return list;
    } catch (_) {
      return List.from(defaultDashboardOrder);
    }
  }

  Future<void> setDashboardOrder(List<String> order) =>
      _prefs.setString(_dashboardOrderKey, jsonEncode(order));

  // Dashboard section sizes (true=large, false=small)
  static const _dashboardSizesKey = 'dashboard_sizes';
  // All sections default to large
  static const _defaultLargeSections = {'news', 'weather', 'routine', 'todo', 'card', 'calendar', 'stats', 'alarm', 'timer', 'memo', 'dday'};

  bool isDashboardSectionLarge(String id) {
    final raw = _prefs.getString(_dashboardSizesKey);
    if (raw == null) return _defaultLargeSections.contains(id);
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (map.containsKey(id)) return map[id] == true;
      return _defaultLargeSections.contains(id);
    } catch (_) {
      return _defaultLargeSections.contains(id);
    }
  }

  Future<void> toggleDashboardSectionSize(String id) async {
    final raw = _prefs.getString(_dashboardSizesKey);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try { map = (jsonDecode(raw) as Map).cast<String, dynamic>(); } catch (_) {}
    }
    final current = isDashboardSectionLarge(id);
    map[id] = !current;
    await _prefs.setString(_dashboardSizesKey, jsonEncode(map));
  }

  // Dashboard section widths (half=true means 50% width)
  static const _dashboardWidthsKey = 'dashboard_widths';

  bool isDashboardSectionHalf(String id) {
    final raw = _prefs.getString(_dashboardWidthsKey);
    if (raw == null) return false;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return map[id] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setDashboardSectionHalf(String id, bool half) async {
    final raw = _prefs.getString(_dashboardWidthsKey);
    Map<String, dynamic> map = {};
    if (raw != null) {
      try { map = (jsonDecode(raw) as Map).cast<String, dynamic>(); } catch (_) {}
    }
    map[id] = half;
    await _prefs.setString(_dashboardWidthsKey, jsonEncode(map));
  }

  // Dashboard hidden sections
  static const _dashboardHiddenKey = 'dashboard_hidden';

  Set<String> get dashboardHidden {
    final raw = _prefs.getString(_dashboardHiddenKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  bool isDashboardSectionHidden(String id) => dashboardHidden.contains(id);

  Future<void> setDashboardSectionHidden(String id, bool hidden) async {
    final set = dashboardHidden;
    if (hidden) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await _prefs.setString(_dashboardHiddenKey, jsonEncode(set.toList()));
  }

  // App lock
  static const _appLockEnabledKey = 'app_lock_enabled';

  bool get appLockEnabled => _prefs.getBool(_appLockEnabledKey) ?? false;
  Future<void> setAppLockEnabled(bool v) =>
      _prefs.setBool(_appLockEnabledKey, v);

}
