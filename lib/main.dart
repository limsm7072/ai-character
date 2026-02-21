import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spine_flutter/spine_flutter.dart';
import 'service_locator.dart';
import 'screens/home_screen.dart';
import 'screens/alarm_ring_screen.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/routine_service.dart';
import 'services/routine_monitor.dart';
import 'services/settings_service.dart';
import 'widgets/overlay_character.dart';
import 'theme/app_theme.dart';

/// Entry point for the overlay window (displayed on top of other apps).
@pragma('vm:entry-point')
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSpineFlutter(enableMemoryDebugging: false);

  // Read selected character before creating widget
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // Force fresh read from disk
  final characterId = prefs.getString('selected_character') ?? 'chibi-stickers';
  print('[OVERLAY] overlayMain characterId=$characterId');

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayCharacter(initialCharacterId: characterId),
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('ko_KR');
  await initSpineFlutter(enableMemoryDebugging: false);

  await setupServiceLocator();

  runApp(const AiCharacterApp());
}

class AiCharacterApp extends StatefulWidget {
  const AiCharacterApp({super.key});

  @override
  State<AiCharacterApp> createState() => _AiCharacterAppState();
}

class _AiCharacterAppState extends State<AiCharacterApp>
    with WidgetsBindingObserver {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndStart();
    _listenNotificationTaps();
  }

  void _listenNotificationTaps() {
    // Listen for notification taps (timer, routine)
    _notifSub = NotificationService.onNotificationTap.stream.listen((payload) {
      if (payload.startsWith('alarm:')) {
        final alarmId = payload.substring(6);
        final alarm = getIt<AlarmService>().getById(alarmId);
        _openAlarmRingScreen(alarm?.label ?? '알람');
      }
    });

    // Listen for native alarm ring events (from AlarmRingService fullScreenIntent)
    const channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmRing') {
        final data = Map<String, dynamic>.from(call.arguments);
        _openAlarmRingScreen(data['label'] ?? '알람');
      }
    });

    // Check if app was launched from alarm fullScreenIntent
    _checkPendingAlarm();
  }

  Future<void> _checkPendingAlarm() async {
    const channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
    try {
      final data = await channel.invokeMethod('checkPendingAlarm');
      if (data != null) {
        final label = (data as Map)['label'] ?? '알람';
        // Small delay to ensure navigator is ready
        await Future.delayed(const Duration(milliseconds: 300));
        _openAlarmRingScreen(label);
      }
    } catch (_) {}
  }

  void _openAlarmRingScreen(String label) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => AlarmRingScreen(alarmLabel: label),
        ),
      );
    }
  }

  Future<void> _requestPermissionsAndStart() async {
    // Request notification permission (Android 13+)
    const channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
    try {
      await channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}

    // Request notification + exact alarm permissions via flutter_local_notifications
    final notificationService = NotificationService();
    try {
      await notificationService.requestPermissions();
    } catch (_) {}

    // Reschedule alarms + routine notifications after permissions are granted
    try {
      await getIt<AlarmService>().rescheduleAll();
    } catch (_) {}
    try {
      await getIt<RoutineService>().rescheduleAllNotifications();
    } catch (_) {}

    // Small delay to let permission dialog complete
    await Future.delayed(const Duration(seconds: 1));

    // Start monitoring
    await getIt<RoutineMonitor>().start();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    getIt<RoutineMonitor>().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AI 루틴 잔소리',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR')],
      locale: const Locale('ko', 'KR'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: HomeScreen(
        onCompletionUnchecked: getIt<RoutineMonitor>().forceCheck,
      ),
    );
  }
}
