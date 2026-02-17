import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spine_flutter/spine_flutter.dart';
import 'screens/home_screen.dart';
import 'services/routine_service.dart';
import 'services/settings_service.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'services/overlay_service.dart';
import 'services/app_detection_service.dart';
import 'services/character_controller.dart';
import 'services/routine_monitor.dart';
import 'services/distraction_log_service.dart';
import 'services/routine_completion_service.dart';
import 'services/accessory_service.dart';
import 'services/health_service.dart';
import 'services/todo_service.dart';
import 'services/memo_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/timer_service.dart';
import 'services/calendar_service.dart';
import 'services/weather_service.dart';
import 'services/news_service.dart';
import 'widgets/overlay_character.dart';

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

  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(prefs);
  final distractionLogService = DistractionLogService(prefs);
  final completionService = RoutineCompletionService(prefs);
  final accessoryService = AccessoryService(prefs);
  final todoService = TodoService(prefs);
  final memoService = MemoService(prefs);

  final notificationService = NotificationService();
  try {
    await notificationService.initialize();
  } catch (e) {
    print('[Main] NotificationService init failed: $e');
  }
  final routineService = RoutineService(prefs, notificationService);
  final alarmService = AlarmService(prefs, notificationService);
  final timerService = TimerService(prefs, notificationService);
  final calendarService = CalendarService(prefs);
  final weatherService = WeatherService(prefs, settingsService);
  final newsService = NewsService(prefs);
  try {
    await alarmService.rescheduleAll();
  } catch (e) {
    print('[Main] rescheduleAll failed: $e');
  }

  final geminiService = GeminiService();
  final ttsService = TtsService();
  final overlayService = OverlayService();
  final appDetectionService = AppDetectionService();
  final healthService = HealthService();
  await healthService.checkExistingPermissions();

  final apiKey = settingsService.apiKey;
  if (apiKey.isNotEmpty) {
    geminiService.initialize(apiKey, characterName: settingsService.characterName);
  }

  await ttsService.initialize();
  await ttsService.applyPreset(settingsService.voicePreset);

  final characterController = CharacterController(
    gemini: geminiService,
    tts: ttsService,
    overlay: overlayService,
    settings: settingsService,
    completionService: completionService,
  );

  final routineMonitor = RoutineMonitor(
    routineService: routineService,
    appDetection: appDetectionService,
    characterController: characterController,
    completionService: completionService,
  );

  runApp(AiCharacterApp(
    routineService: routineService,
    settingsService: settingsService,
    routineMonitor: routineMonitor,
    appDetection: appDetectionService,
    distractionLogService: distractionLogService,
    completionService: completionService,
    ttsService: ttsService,
    accessoryService: accessoryService,
    healthService: healthService,
    todoService: todoService,
    memoService: memoService,
    alarmService: alarmService,
    timerService: timerService,
    calendarService: calendarService,
    weatherService: weatherService,
    newsService: newsService,
  ));
}

class AiCharacterApp extends StatefulWidget {
  final RoutineService routineService;
  final SettingsService settingsService;
  final RoutineMonitor routineMonitor;
  final AppDetectionService appDetection;
  final DistractionLogService distractionLogService;
  final RoutineCompletionService completionService;
  final TtsService ttsService;
  final AccessoryService accessoryService;
  final HealthService healthService;
  final TodoService todoService;
  final MemoService memoService;
  final AlarmService alarmService;
  final TimerService timerService;
  final CalendarService calendarService;
  final WeatherService weatherService;
  final NewsService newsService;

  const AiCharacterApp({
    super.key,
    required this.routineService,
    required this.settingsService,
    required this.routineMonitor,
    required this.appDetection,
    required this.distractionLogService,
    required this.completionService,
    required this.ttsService,
    required this.accessoryService,
    required this.healthService,
    required this.todoService,
    required this.memoService,
    required this.alarmService,
    required this.timerService,
    required this.calendarService,
    required this.weatherService,
    required this.newsService,
  });

  @override
  State<AiCharacterApp> createState() => _AiCharacterAppState();
}

class _AiCharacterAppState extends State<AiCharacterApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndStart();
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
      await widget.alarmService.rescheduleAll();
    } catch (_) {}
    try {
      await widget.routineService.rescheduleAllNotifications();
    } catch (_) {}

    // Small delay to let permission dialog complete
    await Future.delayed(const Duration(seconds: 1));

    // Start monitoring
    await widget.routineMonitor.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.routineMonitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 루틴 잔소리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: HomeScreen(
        routineService: widget.routineService,
        settingsService: widget.settingsService,
        appDetection: widget.appDetection,
        distractionLogService: widget.distractionLogService,
        completionService: widget.completionService,
        ttsService: widget.ttsService,
        accessoryService: widget.accessoryService,
        healthService: widget.healthService,
        todoService: widget.todoService,
        memoService: widget.memoService,
        alarmService: widget.alarmService,
        timerService: widget.timerService,
        calendarService: widget.calendarService,
        weatherService: widget.weatherService,
        newsService: widget.newsService,
        onCompletionUnchecked: widget.routineMonitor.forceCheck,
      ),
    );
  }
}
