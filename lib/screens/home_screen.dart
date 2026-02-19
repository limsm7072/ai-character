import 'package:flutter/material.dart';
import '../services/routine_service.dart';
import '../services/settings_service.dart';
import '../services/app_detection_service.dart';
import '../services/distraction_log_service.dart';
import '../services/routine_completion_service.dart';
import '../services/tts_service.dart';
import '../services/accessory_service.dart';
import '../services/health_service.dart';
import '../services/todo_service.dart';
import '../services/memo_service.dart';
import '../services/alarm_service.dart';
import '../services/timer_service.dart';
import '../services/calendar_service.dart';
import '../services/news_service.dart';
import '../services/card_service.dart';
import '../services/weather_service.dart';
import '../services/recommendation_service.dart';
import '../services/routine_group_service.dart';
import '../services/diary_service.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'character_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final RoutineService routineService;
  final SettingsService settingsService;
  final AppDetectionService? appDetection;
  final DistractionLogService distractionLogService;
  final RoutineCompletionService completionService;
  final TtsService ttsService;
  final AccessoryService accessoryService;
  final HealthService? healthService;
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
  final VoidCallback? onCompletionUnchecked;

  const HomeScreen({
    super.key,
    required this.routineService,
    required this.settingsService,
    this.appDetection,
    required this.distractionLogService,
    required this.completionService,
    required this.ttsService,
    required this.accessoryService,
    this.healthService,
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
    this.onCompletionUnchecked,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _dashboardKey = GlobalKey<DashboardScreenState>();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            key: _dashboardKey,
            routineService: widget.routineService,
            completionService: widget.completionService,
            settingsService: widget.settingsService,
            todoService: widget.todoService,
            memoService: widget.memoService,
            distractionLogService: widget.distractionLogService,
            healthService: widget.healthService,
            appDetection: widget.appDetection,
            alarmService: widget.alarmService,
            timerService: widget.timerService,
            calendarService: widget.calendarService,
            newsService: widget.newsService,
            cardService: widget.cardService,
            weatherService: widget.weatherService,
            recommendationService: widget.recommendationService,
            routineGroupService: widget.routineGroupService,
            diaryService: widget.diaryService,
            onCompletionUnchecked: widget.onCompletionUnchecked,
          ),
          CharacterChatScreen(
            settingsService: widget.settingsService,
            accessoryService: widget.accessoryService,
            routineService: widget.routineService,
            completionService: widget.completionService,
            healthService: widget.healthService,
            todoService: widget.todoService,
            memoService: widget.memoService,
            alarmService: widget.alarmService,
            calendarService: widget.calendarService,
            weatherService: widget.weatherService,
            newsService: widget.newsService,
            cardService: widget.cardService,
            timerService: widget.timerService,
            onRoutinesChanged: () => _dashboardKey.currentState?.refresh(),
          ),
          SettingsScreen(
            settingsService: widget.settingsService,
            appDetection: widget.appDetection,
            ttsService: widget.ttsService,
            weatherService: widget.weatherService,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (i == 0) _dashboardKey.currentState?.refresh();
          setState(() => _currentIndex = i);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: widget.settingsService.characterName,
          ),
          const NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    ),
    );
  }
}
