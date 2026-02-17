import 'package:flutter/material.dart';

class WeatherData {
  final double temperature;
  final int humidity;
  final int ptyCode;
  final double windSpeed;
  final String precipitation;
  final DateTime fetchedAt;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.ptyCode,
    required this.windSpeed,
    required this.precipitation,
    required this.fetchedAt,
  });

  IconData get weatherIcon {
    switch (ptyCode) {
      case 1:
        return Icons.water_drop;
      case 2:
        return Icons.ac_unit;
      case 3:
        return Icons.ac_unit;
      case 4:
        return Icons.grain;
      default:
        return Icons.wb_sunny;
    }
  }

  String get summaryText {
    final desc = _ptyDescription;
    return '$desc ${temperature.round()}℃';
  }

  String get _ptyDescription {
    switch (ptyCode) {
      case 1:
        return '비';
      case 2:
        return '비/눈';
      case 3:
        return '눈';
      case 4:
        return '소나기';
      default:
        return '맑음';
    }
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'humidity': humidity,
        'ptyCode': ptyCode,
        'windSpeed': windSpeed,
        'precipitation': precipitation,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        temperature: (json['temperature'] as num).toDouble(),
        humidity: json['humidity'] as int,
        ptyCode: json['ptyCode'] as int,
        windSpeed: (json['windSpeed'] as num).toDouble(),
        precipitation: json['precipitation'] as String,
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );
}
