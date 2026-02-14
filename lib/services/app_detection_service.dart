import 'dart:async';
import 'package:flutter/services.dart';

/// Service to detect which app is currently in the foreground.
/// Uses Android foreground service + UsageStatsManager via platform channel.
class AppDetectionService {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
  static const _eventChannel = EventChannel('com.aicharacter.ai_character/distraction_events');

  final _distractionController = StreamController<Map<String, String>>.broadcast();

  /// Stream of distraction events from the native foreground service.
  /// Each event contains: app_package, app_label, routine_name
  Stream<Map<String, String>> get onDistraction => _distractionController.stream;

  /// Check if usage stats permission is granted.
  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageStatsPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Open usage stats permission settings.
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } on PlatformException catch (e) {
      print('Failed to request permission: $e');
    }
  }

  /// Check if overlay permission is granted.
  Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Open overlay permission settings.
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      print('Failed to request overlay permission: $e');
    }
  }

  /// Get a human-readable label for a package name.
  Future<String> getAppLabel(String packageName) async {
    try {
      return await _channel.invokeMethod<String>(
            'getAppLabel',
            {'packageName': packageName},
          ) ??
          packageName;
    } on PlatformException {
      return packageName;
    }
  }

  /// Start the native foreground monitor service.
  Future<void> startMonitorService() async {
    try {
      await _channel.invokeMethod('startMonitorService');
    } on PlatformException catch (e) {
      print('Failed to start monitor service: $e');
    }

    // Listen for distraction events from native service
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _distractionController.add(Map<String, String>.from(event));
      }
    });
  }

  /// Stop the native foreground monitor service.
  Future<void> stopMonitorService() async {
    try {
      await _channel.invokeMethod('stopMonitorService');
    } on PlatformException catch (e) {
      print('Failed to stop monitor service: $e');
    }
  }

  void dispose() {
    _distractionController.close();
  }
}
