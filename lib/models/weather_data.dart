import 'package:flutter/material.dart';

class HourlyWeather {
  final String time; // "2026-02-19T10:00"
  final double temperature;
  final int weatherCode;

  const HourlyWeather({required this.time, required this.temperature, required this.weatherCode});

  int get hour => int.tryParse(time.split('T').last.split(':').first) ?? 0;

  String get hourLabel {
    final h = hour;
    if (h == 0) return '자정';
    if (h == 12) return '정오';
    return h < 12 ? '오전 ${h}시' : '오후 ${h - 12}시';
  }

  IconData get icon => WeatherData._iconForCode(weatherCode);
  Color get iconColor => WeatherData._colorForCode(weatherCode);
  String get description => WeatherData._descForCode(weatherCode);
}

class DailyWeather {
  final String date; // "2026-02-19"
  final double maxTemp;
  final double minTemp;
  final int weatherCode;

  const DailyWeather({required this.date, required this.maxTemp, required this.minTemp, required this.weatherCode});

  IconData get icon => WeatherData._iconForCode(weatherCode);
  Color get iconColor => WeatherData._colorForCode(weatherCode);
  String get description => WeatherData._descForCode(weatherCode);

  String get dayLabel {
    final dt = DateTime.tryParse(date);
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(dt.year, dt.month, dt.day).difference(today).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '내일';
    if (diff == 2) return '모레';
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[dt.weekday - 1];
  }

  String get dateLabel {
    final dt = DateTime.tryParse(date);
    if (dt == null) return '';
    return '${dt.month}/${dt.day}';
  }
}

class WeatherData {
  final double temperature;
  final int weatherCode;
  final int humidity;
  final String locationName;
  final double apparentTemperature;
  final double windSpeed;
  final double uvIndex;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;
  final String sunrise;
  final String sunset;

  const WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.humidity,
    this.locationName = '',
    this.apparentTemperature = 0,
    this.windSpeed = 0,
    this.uvIndex = 0,
    this.hourly = const [],
    this.daily = const [],
    this.sunrise = '',
    this.sunset = '',
  });

  WeatherData copyWith({String? locationName}) => WeatherData(
    temperature: temperature,
    weatherCode: weatherCode,
    humidity: humidity,
    locationName: locationName ?? this.locationName,
    apparentTemperature: apparentTemperature,
    windSpeed: windSpeed,
    uvIndex: uvIndex,
    hourly: hourly,
    daily: daily,
    sunrise: sunrise,
    sunset: sunset,
  );

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;

    // Parse hourly
    final hourlyData = <HourlyWeather>[];
    final hourlyJson = json['hourly'] as Map<String, dynamic>?;
    if (hourlyJson != null) {
      final times = (hourlyJson['time'] as List?)?.cast<String>() ?? [];
      final temps = (hourlyJson['temperature_2m'] as List?)?.cast<num>() ?? [];
      final codes = (hourlyJson['weather_code'] as List?)?.cast<num>() ?? [];
      for (int i = 0; i < times.length && i < temps.length && i < codes.length; i++) {
        hourlyData.add(HourlyWeather(
          time: times[i],
          temperature: temps[i].toDouble(),
          weatherCode: codes[i].toInt(),
        ));
      }
    }

    // Parse daily
    final dailyData = <DailyWeather>[];
    final dailyJson = json['daily'] as Map<String, dynamic>?;
    if (dailyJson != null) {
      final dates = (dailyJson['time'] as List?)?.cast<String>() ?? [];
      final maxTemps = (dailyJson['temperature_2m_max'] as List?)?.cast<num>() ?? [];
      final minTemps = (dailyJson['temperature_2m_min'] as List?)?.cast<num>() ?? [];
      final codes = (dailyJson['weather_code'] as List?)?.cast<num>() ?? [];
      final sunrises = (dailyJson['sunrise'] as List?)?.cast<String>() ?? [];
      final sunsets = (dailyJson['sunset'] as List?)?.cast<String>() ?? [];
      for (int i = 0; i < dates.length; i++) {
        dailyData.add(DailyWeather(
          date: dates[i],
          maxTemp: i < maxTemps.length ? maxTemps[i].toDouble() : 0,
          minTemp: i < minTemps.length ? minTemps[i].toDouble() : 0,
          weatherCode: i < codes.length ? codes[i].toInt() : 0,
        ));
      }
    }

    // Sunrise/sunset from today (first daily entry)
    String sunrise = '', sunset = '';
    if (dailyJson != null) {
      final sunrises = (dailyJson['sunrise'] as List?)?.cast<String>() ?? [];
      final sunsets = (dailyJson['sunset'] as List?)?.cast<String>() ?? [];
      if (sunrises.isNotEmpty) sunrise = sunrises.first;
      if (sunsets.isNotEmpty) sunset = sunsets.first;
    }

    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      apparentTemperature: (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      uvIndex: (current['uv_index'] as num?)?.toDouble() ?? 0,
      hourly: hourlyData,
      daily: dailyData,
      sunrise: sunrise,
      sunset: sunset,
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'weatherCode': weatherCode,
    'humidity': humidity,
    'locationName': locationName,
    'apparentTemperature': apparentTemperature,
    'windSpeed': windSpeed,
    'uvIndex': uvIndex,
    'sunrise': sunrise,
    'sunset': sunset,
    'hourly': hourly.map((h) => {'time': h.time, 'temperature': h.temperature, 'weatherCode': h.weatherCode}).toList(),
    'daily': daily.map((d) => {'date': d.date, 'maxTemp': d.maxTemp, 'minTemp': d.minTemp, 'weatherCode': d.weatherCode}).toList(),
  };

  factory WeatherData.fromCache(Map<String, dynamic> json) => WeatherData(
    temperature: (json['temperature'] as num).toDouble(),
    weatherCode: (json['weatherCode'] as num).toInt(),
    humidity: (json['humidity'] as num).toInt(),
    locationName: (json['locationName'] as String?) ?? '',
    apparentTemperature: (json['apparentTemperature'] as num?)?.toDouble() ?? 0,
    windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0,
    uvIndex: (json['uvIndex'] as num?)?.toDouble() ?? 0,
    sunrise: (json['sunrise'] as String?) ?? '',
    sunset: (json['sunset'] as String?) ?? '',
    hourly: ((json['hourly'] as List?) ?? []).map((h) => HourlyWeather(
      time: h['time'] as String? ?? '',
      temperature: (h['temperature'] as num?)?.toDouble() ?? 0,
      weatherCode: (h['weatherCode'] as num?)?.toInt() ?? 0,
    )).toList(),
    daily: ((json['daily'] as List?) ?? []).map((d) => DailyWeather(
      date: d['date'] as String? ?? '',
      maxTemp: (d['maxTemp'] as num?)?.toDouble() ?? 0,
      minTemp: (d['minTemp'] as num?)?.toDouble() ?? 0,
      weatherCode: (d['weatherCode'] as num?)?.toInt() ?? 0,
    )).toList(),
  );

  String get description => _descForCode(weatherCode);
  IconData get icon => _iconForCode(weatherCode);
  Color get iconColor => _colorForCode(weatherCode);

  String get sunriseTime {
    if (sunrise.isEmpty) return '';
    // "2026-02-19T06:50" → "06:50"
    final t = sunrise.split('T');
    return t.length > 1 ? t[1] : sunrise;
  }

  String get sunsetTime {
    if (sunset.isEmpty) return '';
    final t = sunset.split('T');
    return t.length > 1 ? t[1] : sunset;
  }

  String get uvLabel {
    if (uvIndex <= 2) return '낮음';
    if (uvIndex <= 5) return '보통';
    if (uvIndex <= 7) return '높음';
    if (uvIndex <= 10) return '매우 높음';
    return '위험';
  }

  static String _descForCode(int code) {
    if (code == 0) return '맑음';
    if (code <= 3) return '구름';
    if (code <= 48) return '안개';
    if (code <= 67) return '비';
    if (code <= 77) return '눈';
    if (code <= 82) return '소나기';
    if (code <= 99) return '천둥';
    return '알 수 없음';
  }

  static IconData _iconForCode(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code <= 3) return Icons.cloud;
    if (code <= 48) return Icons.foggy;
    if (code <= 67) return Icons.grain;
    if (code <= 77) return Icons.ac_unit;
    if (code <= 82) return Icons.water_drop;
    if (code <= 99) return Icons.thunderstorm;
    return Icons.cloud;
  }

  static Color _colorForCode(int code) {
    if (code == 0) return const Color(0xFFFFA726);
    if (code <= 3) return const Color(0xFF78909C);
    if (code <= 48) return const Color(0xFF90A4AE);
    if (code <= 67) return const Color(0xFF42A5F5);
    if (code <= 77) return const Color(0xFF81D4FA);
    if (code <= 82) return const Color(0xFF42A5F5);
    if (code <= 99) return const Color(0xFFFFCA28);
    return const Color(0xFF78909C);
  }
}
