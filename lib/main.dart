import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spine_flutter/spine_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/alarm_ring_screen.dart';
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
import 'services/news_service.dart';
import 'services/card_service.dart';
import 'services/weather_service.dart';
import 'services/recommendation_service.dart';
import 'services/routine_group_service.dart';
import 'services/diary_service.dart';
import 'services/bookmark_service.dart';
import 'services/fortune_service.dart';
import 'services/goal_service.dart';
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
  final alarmService = AlarmService(prefs);
  final timerService = TimerService(prefs, notificationService);
  final calendarService = CalendarService(prefs);
  final newsService = NewsService(prefs);
  final cardService = CardService(prefs);
  final weatherService = WeatherService(prefs);
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

  final routineGroupService = RoutineGroupService(prefs);
  final diaryService = DiaryService(prefs);
  final bookmarkService = BookmarkService(prefs);
  final fortuneService = FortuneService(prefs);
  final goalService = GoalService(prefs);

  final recommendationService = RecommendationService(
    prefs: prefs,
    cardService: cardService,
    routineService: routineService,
    completionService: completionService,
    todoService: todoService,
    memoService: memoService,
    calendarService: calendarService,
    weatherService: weatherService,
    healthService: healthService,
    geminiService: geminiService,
  );

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
    settingsService: settingsService,
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
    newsService: newsService,
    cardService: cardService,
    weatherService: weatherService,
    recommendationService: recommendationService,
    routineGroupService: routineGroupService,
    diaryService: diaryService,
    bookmarkService: bookmarkService,
    fortuneService: fortuneService,
    goalService: goalService,
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
  final NewsService newsService;
  final CardService cardService;
  final WeatherService weatherService;
  final RecommendationService recommendationService;
  final RoutineGroupService routineGroupService;
  final DiaryService diaryService;
  final BookmarkService bookmarkService;
  final FortuneService fortuneService;
  final GoalService goalService;

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
    required this.newsService,
    required this.cardService,
    required this.weatherService,
    required this.recommendationService,
    required this.routineGroupService,
    required this.diaryService,
    required this.bookmarkService,
    required this.fortuneService,
    required this.goalService,
  });

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
        final alarm = widget.alarmService.getById(alarmId);
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
          builder: (_) => AlarmRingScreen(
            alarmLabel: label,
            settingsService: widget.settingsService,
          ),
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
    _notifSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.routineMonitor.dispose();
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
        newsService: widget.newsService,
        cardService: widget.cardService,
        weatherService: widget.weatherService,
        recommendationService: widget.recommendationService,
        routineGroupService: widget.routineGroupService,
        diaryService: widget.diaryService,
        bookmarkService: widget.bookmarkService,
        fortuneService: widget.fortuneService,
        goalService: widget.goalService,
        onCompletionUnchecked: widget.routineMonitor.forceCheck,
      ),
    );
  }
}
