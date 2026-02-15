import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../services/routine_service.dart';
import '../services/settings_service.dart';
import '../services/app_detection_service.dart';
import '../services/distraction_log_service.dart';
import '../services/routine_completion_service.dart';
import '../services/tts_service.dart';
import '../services/accessory_service.dart';
import 'routine_edit_screen.dart';
import 'stats_screen.dart';
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

  const HomeScreen({
    super.key,
    required this.routineService,
    required this.settingsService,
    this.appDetection,
    required this.distractionLogService,
    required this.completionService,
    required this.ttsService,
    required this.accessoryService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<model.Routine> _routines = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  void _loadRoutines() {
    setState(() {
      _routines = widget.routineService.getAll();
    });
  }

  String get _todayStr => widget.completionService.todayStr();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildRoutineList(),
          StatsScreen(
            routineService: widget.routineService,
            completionService: widget.completionService,
            distractionLogService: widget.distractionLogService,
          ),
          CharacterChatScreen(
            settingsService: widget.settingsService,
            accessoryService: widget.accessoryService,
          ),
          SettingsScreen(
            settingsService: widget.settingsService,
            appDetection: widget.appDetection,
            ttsService: widget.ttsService,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist),
            label: '루틴',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: '통계',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: '루나',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _addRoutine,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildRoutineList() {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('루틴 관리'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showInfo,
            ),
          ],
        ),
        if (_routines.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '루틴을 추가해보세요!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '루틴 시간에 딴짓하면\n루나가 잔소리해줄 거예요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildRoutineCard(_routines[index]),
              childCount: _routines.length,
            ),
          ),
      ],
    );
  }

  Widget _buildRoutineCard(model.Routine routine) {
    final isActive = routine.isActiveNow();
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final activeDays = <String>[];
    for (int i = 0; i < 7; i++) {
      if (routine.activeDays[i]) activeDays.add(dayNames[i]);
    }

    final isCompletedToday =
        widget.completionService.isCompleted(routine.id, _todayStr);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? Colors.green.withValues(alpha: 0.2)
              : routine.isEnabled
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.grey.withValues(alpha: 0.2),
          child: Icon(
            isActive
                ? Icons.play_arrow
                : routine.isEnabled
                    ? Icons.schedule
                    : Icons.pause,
            color: isActive
                ? Colors.green
                : routine.isEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
          ),
        ),
        title: Text(
          routine.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration:
                routine.isEnabled ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${routine.startTime.format()} - ${routine.endTime.format()}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              activeDays.length == 7 ? '매일' : activeDays.join(' '),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Today completion checkbox
            GestureDetector(
              onTap: () async {
                await widget.completionService
                    .toggleCompletion(routine.id, _todayStr);
                setState(() {});
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompletedToday
                      ? Colors.green
                      : Colors.transparent,
                  border: Border.all(
                    color: isCompletedToday ? Colors.green : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isCompletedToday
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: routine.isEnabled,
              onChanged: (val) async {
                routine.isEnabled = val;
                await widget.routineService.update(routine);
                _loadRoutines();
              },
            ),
          ],
        ),
        onTap: () => _editRoutine(routine),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _addRoutine() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineEditScreen(
          routineService: widget.routineService,
        ),
      ),
    );
    if (result == true) _loadRoutines();
  }

  Future<void> _editRoutine(model.Routine routine) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineEditScreen(
          routineService: widget.routineService,
          routine: routine,
        ),
      ),
    );
    if (result == true) _loadRoutines();
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('AI 루틴 잔소리'),
        content: const Text(
          '루틴 시간에 다른 앱을 사용하면 '
          'AI 캐릭터 "루나"가 나타나서 잔소리해줍니다.\n\n'
          '1. 루틴을 추가하세요\n'
          '2. 차단할 앱을 선택하세요\n'
          '3. 루틴 시간에 딴짓하면 루나가 나타나요!\n\n'
          '루틴 완료 시 체크 표시를 눌러\n'
          '통계 탭에서 완료율을 확인하세요.\n\n'
          '설정에서 Gemini API 키를 입력해야\n'
          'AI 대화가 작동합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
