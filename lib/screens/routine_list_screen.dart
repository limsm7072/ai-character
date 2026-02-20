import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../models/routine_group.dart';
import '../models/routine_preset.dart';
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/settings_service.dart';
import '../services/alarm_service.dart';
import '../services/timer_service.dart';
import '../services/routine_group_service.dart';
import '../utils/routine_icons.dart';
import 'routine_edit_screen.dart';
import 'timer_screen.dart';
import '../theme/app_colors.dart';

class RoutineListScreen extends StatefulWidget {
  final RoutineService routineService;
  final RoutineCompletionService completionService;
  final SettingsService settingsService;
  final AlarmService? alarmService;
  final TimerService? timerService;
  final RoutineGroupService routineGroupService;
  final VoidCallback? onCompletionUnchecked;

  const RoutineListScreen({
    super.key,
    required this.routineService,
    required this.completionService,
    required this.settingsService,
    this.alarmService,
    this.timerService,
    required this.routineGroupService,
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

  // Group mode
  bool _isGroupMode = false;
  final Set<String> _selectedRoutineIds = {};
  bool _isFabExpanded = false;

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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final filtered = _filteredRoutines;
    final oldRoutineId = filtered[oldIndex].id;
    final realOld = _routines.indexWhere((r) => r.id == oldRoutineId);

    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final targetRoutineId = filtered[adjustedNew].id;
    var realNew = _routines.indexWhere((r) => r.id == targetRoutineId);
    if (newIndex > oldIndex) realNew++;

    await widget.routineService.reorder(realOld, realNew);
    _loadRoutines();
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

  // ─── Group helpers ────────────────────────────────────────

  void _enterGroupMode() {
    setState(() {
      _isGroupMode = true;
      _selectedRoutineIds.clear();
    });
  }

  void _exitGroupMode() {
    setState(() {
      _isGroupMode = false;
      _selectedRoutineIds.clear();
    });
  }

  void _toggleSelection(String routineId) {
    setState(() {
      if (_selectedRoutineIds.contains(routineId)) {
        _selectedRoutineIds.remove(routineId);
      } else {
        _selectedRoutineIds.add(routineId);
      }
    });
  }

  Future<void> _confirmGroup() async {
    if (_selectedRoutineIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('2개 이상 선택해주세요')),
      );
      return;
    }
    // Make selected routines contiguous in the full list
    await widget.routineService.makeContiguous(_selectedRoutineIds.toList());
    await widget.routineGroupService.createGroup(_selectedRoutineIds.toList());
    _loadRoutines();
    _exitGroupMode();
  }

  Future<void> _showUngroupDialog(RoutineGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('그룹 해제'),
        content: const Text('이 그룹을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.routineGroupService.ungroup(group.id);
      setState(() {});
    }
  }

  /// Build a map: routineId → groupId for filtered routines
  Map<String, String> _buildGroupMap(List<model.Routine> filtered) {
    final groups = widget.routineGroupService.getAll();
    final filteredIds = filtered.map((r) => r.id).toSet();
    final map = <String, String>{};
    for (final g in groups) {
      for (final rid in g.routineIds) {
        if (filteredIds.contains(rid)) {
          map[rid] = g.id;
        }
      }
    }
    return map;
  }

  // ─── Navigation ─────────────────────────────────────────

  void _launchTimer(model.Routine routine) {
    final presets = widget.timerService!.getAll();
    final preset = presets.firstWhere(
      (p) => p.id == routine.linkedTimerId,
      orElse: () => presets.first,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerRunScreen(
          timerService: widget.timerService!,
          initialPreset: preset,
        ),
      ),
    );
  }

  Future<void> _addRoutine() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineEditScreen(
          routineService: widget.routineService,
          alarmService: widget.alarmService,
          timerService: widget.timerService,
          routineGroupService: widget.routineGroupService,
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
          alarmService: widget.alarmService,
          timerService: widget.timerService,
          routineGroupService: widget.routineGroupService,
          routine: routine,
        ),
      ),
    );
    if (result == true) _loadRoutines();
  }

  Future<void> _addPreset(RoutinePreset preset) async {
    final now = DateTime.now();
    final routine = model.Routine(
      id: now.millisecondsSinceEpoch.toString(),
      name: preset.name,
      startTime: model.TimeOfDay(hour: preset.startH, minute: preset.startM),
      endTime: model.TimeOfDay(hour: preset.endH, minute: preset.endM),
      isAllDay: preset.isAllDay,
      startDate: _formatDate(now),
    );
    await widget.routineService.add(routine);
    _loadRoutines();
  }

  // ─── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRoutines;
    final groupMap = _buildGroupMap(filtered);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _isGroupMode ? _buildGroupModeAppBar() : _buildNormalAppBar(),
          SliverToBoxAdapter(child: _buildDaySelector()),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            SliverReorderableList(
              itemBuilder: (context, index) =>
                  _buildRoutineRow(filtered[index], index, filtered, groupMap),
              itemCount: filtered.length,
              onReorder: _isGroupMode ? (_, __) {} : _onReorder,
            ),
          SliverToBoxAdapter(child: SizedBox(height: 80 + MediaQuery.of(context).viewPadding.bottom)),
        ],
      ),
      floatingActionButton: _isGroupMode ? null : _buildFab(),
    );
  }

  Widget _buildFab() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded options
        if (_isFabExpanded) ...[
          _buildMiniFabOption(
            icon: Icons.workspaces_outline,
            label: '그룹핑',
            onTap: () {
              setState(() => _isFabExpanded = false);
              _enterGroupMode();
            },
            theme: theme,
          ),
          const SizedBox(height: 8),
          _buildMiniFabOption(
            icon: Icons.add,
            label: '루틴 추가',
            onTap: () {
              setState(() => _isFabExpanded = false);
              _addRoutine();
            },
            theme: theme,
          ),
          const SizedBox(height: 12),
        ],
        // Main FAB
        FloatingActionButton(
          heroTag: 'main',
          onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
          child: AnimatedRotation(
            turns: _isFabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFabOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }

  SliverAppBar _buildNormalAppBar() {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      title: const Text('루틴 관리'),
      actions: [
        if (!_isSelectedToday || _weekOffset != 0)
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today, size: 18),
            label: const Text('오늘'),
          ),
      ],
    );
  }

  SliverAppBar _buildGroupModeAppBar() {
    return SliverAppBar(
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitGroupMode,
      ),
      title: Text('${_selectedRoutineIds.length}개 선택'),
      actions: [
        TextButton(
          onPressed: _selectedRoutineIds.length >= 2 ? _confirmGroup : null,
          child: const Text('확인'),
        ),
      ],
    );
  }

  // ─── Day selector ───────────────────────────────────────

  Widget _buildDaySelector() {
    final today = DateTime.now();
    final monday = _mondayOf(today).add(Duration(days: _weekOffset * 7));
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
                    fontSize: 20,
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

  // ─── Empty / presets ────────────────────────────────────

  Widget _buildEmptyState() {
    if (_routines.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note, size: 64, color: AppColors.grey400),
              const SizedBox(height: 16),
              Text('이 날에 활성화된 루틴이 없어요',
                  style: TextStyle(fontSize: 18, color: AppColors.grey600)),
            ],
          ),
        ),
      );
    }

    final timed = routinePresets.where((p) => !p.isAllDay).toList();
    final free = routinePresets.where((p) => p.isAllDay).toList();
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(child: Text('빠르게 시작하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Center(child: Text('탭하면 바로 추가됩니다', style: TextStyle(fontSize: 13, color: AppColors.grey500))),
            const SizedBox(height: 20),
            Text('시간 루틴', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: timed.map((p) => _presetChip(p, theme)).toList(),
            ),
            const SizedBox(height: 20),
            Text('자유 루틴', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: free.map((p) => _presetChip(p, theme)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(RoutinePreset p, ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _addPreset(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(p.icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(p.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
            if (!p.isAllDay) ...[
              const SizedBox(width: 6),
              Text(
                '${p.startH.toString().padLeft(2, '0')}:${p.startM.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 11, color: AppColors.grey500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Routine row (timeline) ─────────────────────────────

  Widget _buildRoutineRow(
    model.Routine routine,
    int index,
    List<model.Routine> filtered,
    Map<String, String> groupMap,
  ) {
    final isCompleted = widget.completionService.isCompleted(routine.id, _selectedDateStr);
    final isSkipped = widget.completionService.isSkipped(routine.id, _selectedDateStr);
    final isOn = routine.isEnabled;
    final theme = Theme.of(context);
    final isFirst = index == 0;
    final isLast = index == filtered.length - 1;
    final lineColor = theme.colorScheme.primary.withValues(alpha: 0.2);
    final dotColor = isOn ? theme.colorScheme.primary : AppColors.grey400;

    // Group detection
    final myGroupId = groupMap[routine.id];
    final prevGroupId = index > 0 ? groupMap[filtered[index - 1].id] : null;
    final nextGroupId = index < filtered.length - 1 ? groupMap[filtered[index + 1].id] : null;
    final isInGroup = myGroupId != null;
    final isGroupStart = isInGroup && prevGroupId != myGroupId;
    final isGroupEnd = isInGroup && nextGroupId != myGroupId;

    // Group mode selection
    final isSelected = _isGroupMode && _selectedRoutineIds.contains(routine.id);

    final topPadding = isGroupStart ? 8.0 : 0.0;
    final bottomPadding = isGroupEnd ? 8.0 : 0.0;

    final groupBgColor = isInGroup
        ? theme.colorScheme.primary.withValues(alpha: 0.04)
        : Colors.transparent;

    // Content (right side of timeline)
    final contentWidget = Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
      child: Row(
        children: [
          // Time or "자유"
          SizedBox(
            width: 44,
            child: routine.isAllDay
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('자유', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.accentDark, fontWeight: FontWeight.w600)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(routine.startTime.format(),
                          style: TextStyle(fontSize: 12, color: isOn ? AppColors.grey700 : AppColors.grey500, fontWeight: FontWeight.w600)),
                      Text(routine.endTime.format(),
                          style: TextStyle(fontSize: 11, color: AppColors.grey400)),
                    ],
                  ),
          ),
          const SizedBox(width: 6),
          Icon(routineIcon(routine.name), size: 18,
              color: isOn ? theme.colorScheme.primary : AppColors.grey400),
          const SizedBox(width: 6),
          // Title
          Expanded(
            child: Text(routine.name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: isOn ? null : AppColors.grey500,
                    decoration: isOn ? null : TextDecoration.lineThrough),
                overflow: TextOverflow.ellipsis),
          ),
          // Right icons (fixed area, right-aligned)
          SizedBox(
            width: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (routine.linkedAlarmId != null && !routine.isAllDay)
                  Icon(Icons.alarm, size: 18, color: AppColors.grey500),
                if (routine.linkedTimerId != null && widget.timerService != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () => _launchTimer(routine),
                      child: Icon(Icons.timer, size: 18, color: theme.colorScheme.primary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // Right side wrapped with group background + padding
    final rightSide = Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: groupBgColor,
          borderRadius: BorderRadius.vertical(
            top: isGroupStart ? const Radius.circular(12) : Radius.zero,
            bottom: isGroupEnd ? const Radius.circular(12) : Radius.zero,
          ),
        ),
        child: contentWidget,
      ),
    );

    return Material(
      key: ValueKey(routine.id),
      child: IntrinsicHeight(
        child: _isGroupMode
            ? ReorderableDragStartListener(
                index: index,
                child: InkWell(
                  onTap: () => _toggleSelection(routine.id),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTimelineColumn(isFirst, isLast, lineColor,
                          _buildSelectionDot(routine.id, isSelected, theme)),
                      Expanded(child: rightSide),
                    ],
                  ),
                ),
              )
            : ReorderableDragStartListener(
                index: index,
                child: InkWell(
                  onTap: () => _editRoutine(routine),
                  onLongPress: isInGroup
                      ? () {
                          final group = widget.routineGroupService.groupForRoutine(routine.id);
                          if (group != null) _showUngroupDialog(group);
                        }
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTimelineColumn(isFirst, isLast, lineColor,
                          _buildCompletionDot(routine, isCompleted, isSkipped, dotColor)),
                      Expanded(child: rightSide),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTimelineColumn(bool isFirst, bool isLast, Color lineColor, Widget dot) {
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          Expanded(child: Container(
            width: 1.5,
            color: isFirst ? Colors.transparent : lineColor,
          )),
          dot,
          Expanded(child: Container(
            width: 1.5,
            color: isLast ? Colors.transparent : lineColor,
          )),
        ],
      ),
    );
  }

  Widget _buildSelectionDot(String routineId, bool isSelected, ThemeData theme) {
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }

  Widget _buildCompletionDot(
    model.Routine routine,
    bool isCompleted,
    bool isSkipped,
    Color dotColor,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (!isCompleted && !isSkipped) {
          await widget.completionService.toggleCompletion(routine.id, _selectedDateStr);
        } else if (isCompleted) {
          await widget.completionService.markSkipped(routine.id, _selectedDateStr);
        } else {
          await widget.completionService.toggleCompletion(routine.id, _selectedDateStr);
          widget.onCompletionUnchecked?.call();
        }
        setState(() {});
      },
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (isCompleted || isSkipped)
              ? (isCompleted ? AppColors.success : AppColors.warning)
              : dotColor.withValues(alpha: 0.15),
          border: Border.all(
            color: (isCompleted || isSkipped)
                ? (isCompleted ? AppColors.success : AppColors.warning)
                : dotColor,
            width: 1.5,
          ),
        ),
        child: (isCompleted || isSkipped)
            ? Icon(isSkipped ? Icons.close : Icons.check, color: AppColors.white, size: 14)
            : null,
      ),
    );
  }
}
