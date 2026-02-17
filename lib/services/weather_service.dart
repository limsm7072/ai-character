import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_data.dart';
import 'settings_service.dart';

class WeatherService {
  static const _cacheKey = 'weather_cache';
  static const _cacheDuration = Duration(minutes: 30);

  final SharedPreferences _prefs;
  final SettingsService _settings;

  WeatherData? _cached;

  WeatherService(this._prefs, this._settings) {
    _loadCache();
  }

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _cached = WeatherData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _cached = null;
    }
  }

  WeatherData? getCached() => _cached;

  Future<WeatherData?> fetchCurrent() async {
    if (!_settings.weatherEnabled) return null;
    final apiKey = _settings.weatherApiKey;
    if (apiKey.isEmpty) return null;

    // Return cache if still valid
    if (_cached != null &&
        DateTime.now().difference(_cached!.fetchedAt) < _cacheDuration) {
      return _cached;
    }

    try {
      final now = DateTime.now();
      // base_time: use previous hour if before XX:40
      var baseHour = now.hour;
      if (now.minute < 40) {
        baseHour = baseHour - 1;
        if (baseHour < 0) baseHour = 23;
      }
      final baseDate =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final baseTime = '${baseHour.toString().padLeft(2, '0')}00';

      final nx = _settings.weatherNx;
      final ny = _settings.weatherNy;

      final uri = Uri.https('apis.data.go.kr',
          '/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst', {
        'serviceKey': apiKey,
        'numOfRows': '10',
        'pageNo': '1',
        'dataType': 'JSON',
        'base_date': baseDate,
        'base_time': baseTime,
        'nx': nx.toString(),
        'ny': ny.toString(),
      });

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: false);

      final json = jsonDecode(body) as Map<String, dynamic>;
      final items = (json['response']?['body']?['items']?['item'] as List?) ?? [];

      double temp = 0;
      int humidity = 0;
      int pty = 0;
      double wsd = 0;
      String rn1 = '0';

      for (final item in items) {
        final category = item['category'] as String?;
        final value = item['obsrValue']?.toString() ?? '0';
        switch (category) {
          case 'T1H':
            temp = double.tryParse(value) ?? 0;
            break;
          case 'REH':
            humidity = int.tryParse(value) ?? 0;
            break;
          case 'PTY':
            pty = int.tryParse(value) ?? 0;
            break;
          case 'WSD':
            wsd = double.tryParse(value) ?? 0;
            break;
          case 'RN1':
            rn1 = value;
            break;
        }
      }

      final data = WeatherData(
        temperature: temp,
        humidity: humidity,
        ptyCode: pty,
        windSpeed: wsd,
        precipitation: rn1,
        fetchedAt: DateTime.now(),
      );

      _cached = data;
      await _prefs.setString(_cacheKey, jsonEncode(data.toJson()));
      return data;
    } catch (e) {
      print('[WeatherService] fetch error: $e');
      return _cached;
    }
  }

  Future<void> clearCache() async {
    _cached = null;
    await _prefs.remove(_cacheKey);
  }
}
