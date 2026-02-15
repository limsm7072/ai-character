import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/routine.dart' as model;
import '../services/routine_service.dart';
import '../services/settings_service.dart';
import '../services/app_detection_service.dart';
import '../services/distraction_log_service.dart';
import '../services/routine_completion_service.dart';
import '../services/tts_service.dart';
import '../services/accessory_service.dart';
import '../widgets/assistant_overlay.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<model.Routine> _routines = [];
  int _currentIndex = 0;
  late DateTime _selectedDate;
  late String _selectedDateStr;
  int _weekOffset = 0;

  // Wake word detection
  final _wakeSpeech = stt.SpeechToText();
  bool _wakeSpeechReady = false;
  bool _wakeListening = false;
  bool _assistantShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDate = DateTime.now();
    _selectedDateStr = _formatDate(_selectedDate);
    _loadRoutines();
    _initWakeWord();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeSpeech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopWakeWordListening();
    } else if (state == AppLifecycleState.resumed) {
      if (!_assistantShowing && _currentIndex != 2) {
        _startWakeWordListening();
      }
    }
  }

  Future<void> _initWakeWord() async {
    _wakeSpeechReady = await _wakeSpeech.initialize(
      onError: (_) {},
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          // Restart listening after timeout
          if (_wakeListening && !_assistantShowing && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && !_assistantShowing && _currentIndex != 2) {
                _startWakeWordListening();
              }
            });
          }
        }
      },
    );
    if (_wakeSpeechReady && _currentIndex != 2) {
      _startWakeWordListening();
    }
  }

  void _startWakeWordListening() {
    if (!_wakeSpeechReady || _assistantShowing || !mounted) return;
    _wakeListening = true;
    _wakeSpeech.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        if (_containsWakeWord(words)) {
          _wakeSpeech.stop();
          _wakeListening = false;
          final command = _extractCommand(result.recognizedWords);
          _showAssistantOverlay(initialCommand: command);
        }
      },
      localeId: 'ko_KR',
      listenFor: const Duration(seconds: 5),
      cancelOnError: false,
    );
  }

  void _stopWakeWordListening() {
    _wakeListening = false;
    _wakeSpeech.stop();
  }

  bool _containsWakeWord(String text) {
    final normalized = text.replaceAll(' ', '');
    return normalized.contains('헤이루나') ||
        normalized.contains('hey루나') ||
        normalized.contains('헤이luna');
  }

  String? _extractCommand(String text) {
    final lower = text.toLowerCase();
    final patterns = ['헤이 루나', '헤이루나', 'hey 루나', 'hey루나'];
    for (final p in patterns) {
      final idx = lower.indexOf(p);
      if (idx >= 0) {
        final after = text.substring(idx + p.length).trim();
        if (after.isNotEmpty) return after;
      }
    }
    return null;
  }

  void _showAssistantOverlay({String? initialCommand}) {
    if (widget.settingsService.apiKey.isEmpty) return;
    _assistantShowing = true;
    _stopWakeWordListening();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Assistant',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return AssistantOverlay(
          settingsService: widget.settingsService,
          accessoryService: widget.accessoryService,
          initialCommand: initialCommand,
        );
      },
    ).then((_) {
      _assistantShowing = false;
      if (_currentIndex != 2) {
        _startWakeWordListening();
      }
    });
  }

  void _loadRoutines() {
    setState(() {
      _routines = widget.routineService.getAll();
    });
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _weekOffset = 0;
      _selectedDate = today;
      _selectedDateStr = _formatDate(today);
    });
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String get _todayStr => widget.completionService.todayStr();

  bool get _isSelectedToday => _selectedDateStr == _todayStr;

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
            appDetectionService: widget.appDetection,
          ),
          CharacterChatScreen(
            settingsService: widget.settingsService,
            accessoryService: widget.accessoryService,
            routineService: widget.routineService,
            completionService: widget.completionService,
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
          if (i == 0) _loadRoutines();
          setState(() => _currentIndex = i);
          // Stop wake word on 루나 tab to avoid mic conflicts
          if (i == 2) {
            _stopWakeWordListening();
          } else if (!_assistantShowing) {
            _startWakeWordListening();
          }
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

  /// Filter routines that are active on the selected day.
  List<model.Routine> get _filteredRoutines {
    final dayIndex = _selectedDate.weekday - 1; // 0=Mon, 6=Sun
    return _routines.where((r) => r.activeDays[dayIndex]).toList();
  }

  /// Get Monday of the week for the given date.
  DateTime _mondayOf(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  Widget _buildDaySelector() {
    final today = DateTime.now();
    final monday = _mondayOf(today).add(Duration(days: _weekOffset * 7));
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final todayStr = _formatDate(today);
    final theme = Theme.of(context);

    // Week label: "1월 3주" style
    final weekMonth = monday.add(const Duration(days: 3)); // Thursday determines the month
    final weekLabel = '${weekMonth.month}월';

    return Column(
      children: [
        // Week navigation row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _weekOffset--),
                visualDensity: VisualDensity.compact,
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _weekOffset = 0;
                    _selectedDate = today;
                    _selectedDateStr = _formatDate(today);
                  });
                },
                child: Text(
                  '$weekLabel (${monday.month}/${monday.day} - ${monday.add(const Duration(days: 6)).month}/${monday.add(const Duration(days: 6)).day})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _weekOffset == 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _weekOffset++),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        // Day chips row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final date = monday.add(Duration(days: i));
              final dateStr = _formatDate(date);
              final dayName = dayNames[i];
              final isSelected = dateStr == _selectedDateStr;
              final isToday = dateStr == todayStr;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedDateStr = dateStr;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : isToday
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : isToday
                                    ? theme.colorScheme.primary
                                    : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : isToday
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineList() {
    final filtered = _filteredRoutines;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('루틴 관리'),
          actions: [
            if (!_isSelectedToday || _weekOffset != 0)
              TextButton.icon(
                onPressed: _goToToday,
                icon: const Icon(Icons.today, size: 18),
                label: const Text('오늘'),
              ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showInfo,
            ),
          ],
        ),
        SliverToBoxAdapter(child: _buildDaySelector()),
        const SliverToBoxAdapter(child: Divider(height: 1)),
        if (filtered.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _routines.isEmpty
                        ? '루틴을 추가해보세요!'
                        : '이 날에 활성화된 루틴이 없어요',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_routines.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '루틴 시간에 딴짓하면\n루나가 잔소리해줄 거예요',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildRoutineCard(filtered[index]),
              childCount: filtered.length,
            ),
          ),
      ],
    );
  }

  Widget _buildRoutineCard(model.Routine routine) {
    final isActive = _isSelectedToday && routine.isActiveNow();
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final activeDays = <String>[];
    for (int i = 0; i < 7; i++) {
      if (routine.activeDays[i]) activeDays.add(dayNames[i]);
    }

    final isCompleted =
        widget.completionService.isCompleted(routine.id, _selectedDateStr);
    final isSkipped =
        widget.completionService.isSkipped(routine.id, _selectedDateStr);

    final Color checkColor;
    if (isCompleted) {
      checkColor = Colors.green;
    } else if (isSkipped) {
      checkColor = Colors.orange;
    } else {
      checkColor = Colors.transparent;
    }
    final bool hasCheck = isCompleted || isSkipped;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: GestureDetector(
          onTap: () async {
            if (isSkipped) {
              await widget.completionService
                  .toggleCompletion(routine.id, _selectedDateStr);
            } else if (isCompleted) {
              await widget.completionService
                  .toggleCompletion(routine.id, _selectedDateStr);
            } else {
              await widget.completionService
                  .toggleCompletion(routine.id, _selectedDateStr);
            }
            setState(() {});
          },
          onLongPress: () async {
            if (isSkipped) {
              await widget.completionService
                  .toggleCompletion(routine.id, _selectedDateStr);
            } else {
              await widget.completionService
                  .markSkipped(routine.id, _selectedDateStr);
            }
            setState(() {});
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasCheck ? checkColor : Colors.transparent,
              border: Border.all(
                color: hasCheck ? checkColor : Colors.grey[400]!,
                width: 2,
              ),
            ),
            child: hasCheck
                ? Icon(
                    isSkipped ? Icons.close : Icons.check,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
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
        trailing: Switch(
          value: routine.isEnabled,
          onChanged: (val) async {
            routine.isEnabled = val;
            await widget.routineService.update(routine);
            _loadRoutines();
          },
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
