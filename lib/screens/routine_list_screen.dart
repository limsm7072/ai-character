import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/settings_service.dart';
import '../services/timer_service.dart';
import 'routine_edit_screen.dart';
import 'timer_screen.dart';
import '../theme/app_colors.dart';

class RoutineListScreen extends StatefulWidget {
  final RoutineService routineService;
  final RoutineCompletionService completionService;
  final SettingsService settingsService;
  final TimerService? timerService;
  final VoidCallback? onCompletionUnchecked;

  const RoutineListScreen({
    super.key,
    required this.routineService,
    required this.completionService,
    required this.settingsService,
    this.timerService,
    this.onCompletionUnchecked,
  });

  @override
  State<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends State<RoutineListScreen> {
  List<model.Routine> _routines = [];
  late DateTime _selectedDate;
  late String _selectedDateStr;
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedDateStr = _formatDate(_selectedDate);
    _loadRoutines();
  }

  void _loadRoutines() {
    setState(() => _routines = widget.routineService.getAll());
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

  List<model.Routine> get _filteredRoutines =>
      _routines.where((r) => r.isActiveOnDate(_selectedDate)).toList();

  DateTime _mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1));

  // ─── Week/day selector ──────────────────────────────────

  Widget _buildDaySelector() {
    final today = DateTime.now();
    final monday = _mondayOf(today).add(Duration(days: _weekOffset * 7));
    final sunday = monday.add(const Duration(days: 6));
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final todayStr = _formatDate(today);
    final theme = Theme.of(context);
    final weekMonth = monday.add(const Duration(days: 3));

    return Column(
      children: [
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
                onTap: _goToToday,
                child: Text(
                  '${weekMonth.month}월',
                  style: TextStyle(
                    fontSize: 16,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final date = monday.add(Duration(days: i));
              final dateStr = _formatDate(date);
              final isSelected = dateStr == _selectedDateStr;
              final isToday = dateStr == todayStr;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedDate = date;
                    _selectedDateStr = dateStr;
                  }),
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
                          dayNames[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : isToday ? theme.colorScheme.primary : AppColors.grey600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface,
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

  // ─── Routine list ───────────────────────────────────────

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, size: 64, color: AppColors.grey400),
            const SizedBox(height: 16),
            Text(
              _routines.isEmpty ? '루틴을 추가해보세요!' : '이 날에 활성화된 루틴이 없어요',
              style: TextStyle(fontSize: 18, color: AppColors.grey600),
            ),
            if (_routines.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '루틴 시간에 딴짓하면\n${widget.settingsService.characterName}가 잔소리해줄 거예요',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Routine card ───────────────────────────────────────

  Widget _buildRoutineCard(model.Routine routine) {
    final isCompleted = widget.completionService.isCompleted(routine.id, _selectedDateStr);
    final isSkipped = widget.completionService.isSkipped(routine.id, _selectedDateStr);

    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final activeDays = [
      for (int i = 0; i < 7; i++)
        if (routine.activeDays[i]) dayNames[i],
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildCheckCircle(routine.id, isCompleted, isSkipped)],
        ),
        title: Text(
          routine.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: routine.isEnabled ? null : TextDecoration.lineThrough,
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
              style: TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (routine.timerMinutes != null && widget.timerService != null)
              IconButton(
                icon: Icon(Icons.timer, size: 20, color: Theme.of(context).colorScheme.primary),
                tooltip: '${routine.timerMinutes}분 타이머',
                onPressed: () => _launchTimer(routine),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
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

  Widget _buildCheckCircle(String routineId, bool isCompleted, bool isSkipped) {
    final hasCheck = isCompleted || isSkipped;
    final color = isCompleted ? AppColors.success : isSkipped ? AppColors.warning : Colors.transparent;

    return GestureDetector(
      onTap: () async {
        if (!isCompleted && !isSkipped) {
          await widget.completionService.toggleCompletion(routineId, _selectedDateStr);
        } else if (isCompleted) {
          await widget.completionService.markSkipped(routineId, _selectedDateStr);
        } else {
          await widget.completionService.toggleCompletion(routineId, _selectedDateStr);
          widget.onCompletionUnchecked?.call();
        }
        setState(() {});
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasCheck ? color : Colors.transparent,
          border: Border.all(color: hasCheck ? color : AppColors.grey400, width: 2),
        ),
        child: hasCheck
            ? Icon(isSkipped ? Icons.close : Icons.check, color: AppColors.white, size: 20)
            : null,
      ),
    );
  }

  // ─── Navigation ─────────────────────────────────────────

  void _launchTimer(model.Routine routine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerScreen(
          timerService: widget.timerService!,
          initialDurationSeconds: routine.timerMinutes! * 60,
          initialLabel: routine.name,
        ),
      ),
    );
  }

  Future<void> _addRoutine() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineEditScreen(routineService: widget.routineService),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRoutines;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('루틴 관리'),
            actions: [
              if (!_isSelectedToday || _weekOffset != 0)
                TextButton.icon(
                  onPressed: _goToToday,
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('오늘'),
                ),
            ],
          ),
          SliverToBoxAdapter(child: _buildDaySelector()),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildRoutineCard(filtered[index]),
                childCount: filtered.length,
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 80 + MediaQuery.of(context).viewPadding.bottom)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRoutine,
        child: const Icon(Icons.add),
      ),
    );
  }
}
