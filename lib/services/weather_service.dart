import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_data.dart';

class WeatherService {
  static const _cacheKey = 'weather_cache';
  static const _cacheTimeKey = 'weather_cache_time';
  static const _cacheDuration = Duration(minutes: 30);

  final SharedPreferences _prefs;
  WeatherData? _cached;

  WeatherService(this._prefs) {
    _loadCache();
  }

  void _loadCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _cached = WeatherData.fromCache(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  WeatherData? getCached() => _cached;

  Future<WeatherData?> fetch(double lat, double lon) async {
    final cacheTime = _prefs.getInt(_cacheTimeKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - cacheTime;
    if (elapsed < _cacheDuration.inMilliseconds && _cached != null) {
      return _cached;
    }

    try {
      final url = 'https://api.open-meteo.com/v1/forecast'
          '?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,weather_code,relative_humidity_2m,apparent_temperature,wind_speed_10m,uv_index'
          '&hourly=temperature_2m,weather_code'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset'
          '&timezone=auto'
          '&forecast_days=7';
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: false);

      final json = jsonDecode(body) as Map<String, dynamic>;
      var data = WeatherData.fromJson(json);

      // Reverse geocode for location name
      final locName = await _reverseGeocode(lat, lon);
      if (locName.isNotEmpty) {
        data = data.copyWith(locationName: locName);
      }

      _cached = data;
      await _prefs.setString(_cacheKey, jsonEncode(data.toJson()));
      await _prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

      return data;
    } catch (e) {
      print('[WeatherService] fetch error: $e');
      return _cached;
    }
  }

  /// Force refresh (bypass cache)
  Future<WeatherData?> forceRefresh(double lat, double lon) async {
    await _prefs.remove(_cacheTimeKey);
    _cached = null;
    return fetch(lat, lon);
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse'
          '?lat=$lat&lon=$lon&format=json&accept-language=ko';
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'AiCharacterApp/1.0');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: false);

      final json = jsonDecode(body) as Map<String, dynamic>;
      final addr = json['address'] as Map<String, dynamic>?;
      if (addr == null) return '';

      final city = addr['city'] ?? addr['town'] ?? addr['county'] ?? '';
      final district = addr['city_district'] ?? addr['suburb'] ?? '';
      final dong = addr['quarter'] ?? addr['neighbourhood'] ?? '';

      final parts = <String>[];
      if (city.toString().isNotEmpty) parts.add(city.toString());
      if (district.toString().isNotEmpty && district.toString() != city.toString()) {
        parts.add(district.toString());
      }
      if (dong.toString().isNotEmpty && dong.toString() != district.toString() && dong.toString() != city.toString()) {
        parts.add(dong.toString());
      }

      return parts.join(' ');
    } catch (e) {
      print('[WeatherService] geocode error: $e');
      return '';
    }
  }
}
