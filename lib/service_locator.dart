import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/settings_service.dart';
import 'services/distraction_log_service.dart';
import 'services/routine_completion_service.dart';
import 'services/accessory_service.dart';
import 'services/todo_service.dart';
import 'services/memo_service.dart';
import 'services/notification_service.dart';
import 'services/routine_service.dart';
import 'services/alarm_service.dart';
import 'services/timer_service.dart';
import 'services/calendar_service.dart';
import 'services/news_service.dart';
import 'services/card_service.dart';
import 'services/weather_service.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'services/overlay_service.dart';
import 'services/app_detection_service.dart';
import 'services/health_service.dart';
import 'services/routine_group_service.dart';
import 'services/diary_service.dart';
import 'services/bookmark_service.dart';
import 'services/fortune_service.dart';
import 'services/goal_service.dart';
import 'services/psychology_service.dart';
import 'services/screen_time_service.dart';
import 'services/activity_service.dart';
import 'services/growth_service.dart';
import 'services/briefing_service.dart';
import 'services/suggestion_service.dart';
import 'services/weekly_report_service.dart';
import 'services/notion_page_service.dart';
import 'services/notion_database_service.dart';
import 'services/auto_page_service.dart';
import 'services/recommendation_service.dart';
import 'services/character_controller.dart';
import 'services/routine_monitor.dart';
import 'services/naver_reservation_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── Layer 1: SharedPreferences ──
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // ── Layer 2: 기본 서비스 (prefs 또는 인자 없음) ──
  getIt.registerSingleton<SettingsService>(SettingsService(prefs));
  getIt.registerSingleton<DistractionLogService>(DistractionLogService(prefs));
  getIt.registerSingleton<RoutineCompletionService>(RoutineCompletionService(prefs));
  getIt.registerSingleton<AccessoryService>(AccessoryService(prefs));
  getIt.registerSingleton<TodoService>(TodoService(prefs));
  getIt.registerSingleton<MemoService>(MemoService(prefs));
  getIt.registerSingleton<CardService>(CardService(prefs));
  getIt.registerSingleton<WeatherService>(WeatherService(prefs));
  getIt.registerSingleton<NewsService>(NewsService(prefs));
  getIt.registerSingleton<CalendarService>(CalendarService(prefs));
  getIt.registerSingleton<RoutineGroupService>(RoutineGroupService(prefs));
  getIt.registerSingleton<DiaryService>(DiaryService(prefs));
  getIt.registerSingleton<BookmarkService>(BookmarkService(prefs));
  getIt.registerSingleton<FortuneService>(FortuneService(prefs));
  getIt.registerSingleton<GoalService>(GoalService(prefs));
  getIt.registerSingleton<PsychologyService>(PsychologyService(prefs));
  getIt.registerSingleton<ScreenTimeService>(ScreenTimeService(prefs));
  getIt.registerSingleton<ActivityService>(ActivityService(prefs));
  getIt.registerSingleton<GrowthService>(GrowthService(prefs));
  getIt.registerSingleton<NotionPageService>(NotionPageService(prefs));
  getIt.registerSingleton<NotionDatabaseService>(NotionDatabaseService(prefs));

  // 인자 없는 서비스
  getIt.registerSingleton<GeminiService>(GeminiService());
  getIt.registerSingleton<TtsService>(TtsService());
  getIt.registerSingleton<OverlayService>(OverlayService());
  getIt.registerSingleton<AppDetectionService>(AppDetectionService());
  getIt.registerSingleton<HealthService>(HealthService());

  // 네이버 예약 연동 (CalendarService + GeminiService 의존)
  getIt.registerSingleton<NaverReservationService>(NaverReservationService(
    prefs: prefs,
    calendar: getIt<CalendarService>(),
    gemini: getIt<GeminiService>(),
  ));

  // ── Layer 3: NotificationService (async) ──
  final notificationService = NotificationService();
  try {
    await notificationService.initialize();
  } catch (e) {
    print('[ServiceLocator] NotificationService init failed: $e');
  }
  getIt.registerSingleton<NotificationService>(notificationService);

  // ── Layer 4: NotificationService 의존 서비스 ──
  getIt.registerSingleton<RoutineService>(
    RoutineService(prefs, getIt<NotificationService>()),
  );
  getIt.registerSingleton<AlarmService>(AlarmService(prefs));
  getIt.registerSingleton<TimerService>(
    TimerService(prefs, getIt<NotificationService>()),
  );

  try {
    await getIt<AlarmService>().rescheduleAll();
  } catch (e) {
    print('[ServiceLocator] rescheduleAll failed: $e');
  }

  // ── Layer 5: HealthService async init ──
  await getIt<HealthService>().checkExistingPermissions();

  // ── Layer 6: 복합 서비스 ──
  getIt.registerSingleton<AutoPageService>(AutoPageService(
    pageService: getIt<NotionPageService>(),
    routineService: getIt<RoutineService>(),
    completionService: getIt<RoutineCompletionService>(),
    todoService: getIt<TodoService>(),
    diaryService: getIt<DiaryService>(),
    calendarService: getIt<CalendarService>(),
    healthService: getIt<HealthService>(),
    screenTimeService: getIt<ScreenTimeService>(),
    activityService: getIt<ActivityService>(),
    weatherService: getIt<WeatherService>(),
    goalService: getIt<GoalService>(),
    geminiService: getIt<GeminiService>(),
    settingsService: getIt<SettingsService>(),
    prefs: prefs,
  ));

  getIt.registerSingleton<SuggestionService>(SuggestionService(
    prefs: prefs,
    routine: getIt<RoutineService>(),
    completion: getIt<RoutineCompletionService>(),
    distraction: getIt<DistractionLogService>(),
    growth: getIt<GrowthService>(),
  ));

  getIt.registerSingleton<WeeklyReportService>(WeeklyReportService(
    prefs: prefs,
    routine: getIt<RoutineService>(),
    completion: getIt<RoutineCompletionService>(),
    distraction: getIt<DistractionLogService>(),
    growth: getIt<GrowthService>(),
    gemini: getIt<GeminiService>(),
  ));

  getIt.registerSingleton<BriefingService>(BriefingService(
    prefs: prefs,
    weather: getIt<WeatherService>(),
    calendar: getIt<CalendarService>(),
    todo: getIt<TodoService>(),
    routine: getIt<RoutineService>(),
    completion: getIt<RoutineCompletionService>(),
    growth: getIt<GrowthService>(),
    settings: getIt<SettingsService>(),
    gemini: getIt<GeminiService>(),
  ));

  getIt.registerSingleton<RecommendationService>(RecommendationService(
    prefs: prefs,
    cardService: getIt<CardService>(),
    routineService: getIt<RoutineService>(),
    completionService: getIt<RoutineCompletionService>(),
    todoService: getIt<TodoService>(),
    memoService: getIt<MemoService>(),
    calendarService: getIt<CalendarService>(),
    weatherService: getIt<WeatherService>(),
    healthService: getIt<HealthService>(),
    geminiService: getIt<GeminiService>(),
  ));

  // ── Layer 7: GeminiService + TtsService 초기화 ──
  final settings = getIt<SettingsService>();
  final apiKey = settings.apiKey;
  if (apiKey.isNotEmpty) {
    getIt<GeminiService>().initialize(apiKey, characterName: settings.characterName);
  }

  await getIt<TtsService>().initialize();
  await getIt<TtsService>().applyPreset(settings.voicePreset);

  // ── Layer 8: CharacterController ──
  getIt.registerSingleton<CharacterController>(CharacterController(
    gemini: getIt<GeminiService>(),
    tts: getIt<TtsService>(),
    overlay: getIt<OverlayService>(),
    settings: getIt<SettingsService>(),
    completionService: getIt<RoutineCompletionService>(),
  ));

  // ── Layer 9: RoutineMonitor ──
  getIt.registerSingleton<RoutineMonitor>(RoutineMonitor(
    routineService: getIt<RoutineService>(),
    appDetection: getIt<AppDetectionService>(),
    characterController: getIt<CharacterController>(),
    completionService: getIt<RoutineCompletionService>(),
    settingsService: getIt<SettingsService>(),
  ));
}
