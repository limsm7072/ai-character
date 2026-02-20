import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/settings_service.dart';
import '../models/work_type.dart';
import '../utils/lunar_calendar.dart';
import '../theme/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  final CalendarService calendarService;
  final RoutineService? routineService;
  final RoutineCompletionService? completionService;
  final SettingsService? settingsService;

  const CalendarScreen({
    super.key,
    required this.calendarService,
    this.routineService,
    this.completionService,
    this.settingsService,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late bool _showLunar;
  late bool _showDDay;
  String? _activeWorkTypeId; // active work type for tap-to-assign

  @override
  void initState() {
    super.initState();
    _showLunar = widget.settingsService?.showLunar ?? true;
    _showDDay = widget.settingsService?.showDDay ?? true;
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  bool get _isToday => isSameDay(_selectedDay, DateTime.now());

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedStr = _formatDate(_selectedDay);
    final events = widget.calendarService.getByDate(selectedStr);
    final routineInfo = _getRoutineInfo(selectedStr);
    final ddayEvents = _showDDay ? widget.calendarService.getDDayEvents() : <CalendarEvent>[];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('캘린더'),
        actions: [
          // Go to today
          if (!_isToday)
            TextButton.icon(
              onPressed: _goToToday,
              icon: const Icon(Icons.today, size: 18),
              label: const Text('오늘'),
            ),
          // Lunar toggle
          IconButton(
            icon: Icon(
              Icons.dark_mode_outlined,
              color: _showLunar ? theme.colorScheme.primary : AppColors.grey500,
            ),
            tooltip: _showLunar ? '음력 숨기기' : '음력 보기',
            onPressed: () {
              setState(() => _showLunar = !_showLunar);
              widget.settingsService?.setShowLunar(_showLunar);
            },
          ),
          // D-Day toggle
          IconButton(
            icon: Icon(
              Icons.flag_outlined,
              color: _showDDay ? theme.colorScheme.primary : AppColors.grey500,
            ),
            tooltip: _showDDay ? 'D-Day 숨기기' : 'D-Day 보기',
            onPressed: () {
              setState(() => _showDDay = !_showDDay);
              widget.settingsService?.setShowDDay(_showDDay);
            },
          ),
          // Work type management
          IconButton(
            icon: Icon(
              Icons.work_outline,
              size: 22,
              color: _activeWorkTypeId != null ? theme.colorScheme.primary : null,
            ),
            tooltip: '근무형태 관리',
            onPressed: () => _showWorkTypeManager(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditSheet(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // D-Day banner
            if (_showDDay && ddayEvents.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: ddayEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final e = ddayEvents[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.dDayString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            e.title,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // Calendar
            TableCalendar(
              locale: 'ko_KR',
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              availableCalendarFormats: const {CalendarFormat.month: '월'},
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              onDaySelected: (selected, focused) {
                if (_activeWorkTypeId != null) {
                  // Tap-to-assign mode
                  final dateStr = _formatDate(selected);
                  final currentWtId = widget.calendarService.getDateWorkType(dateStr);
                  if (currentWtId == _activeWorkTypeId) {
                    widget.calendarService.setDateWorkType(dateStr, null);
                  } else {
                    widget.calendarService.setDateWorkType(dateStr, _activeWorkTypeId);
                  }
                }
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              rowHeight: _showLunar ? 56 : 48,
              calendarStyle: CalendarStyle(
                todayDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.calendarSelected,
                  shape: BoxShape.circle,
                ),
                cellMargin: const EdgeInsets.all(2),
                todayTextStyle: const TextStyle(color: AppColors.white, fontSize: 14),
                selectedTextStyle: const TextStyle(color: AppColors.white, fontSize: 14),
                defaultTextStyle: const TextStyle(fontSize: 14),
                weekendTextStyle: TextStyle(fontSize: 14, color: AppColors.errorLight),
                outsideTextStyle: TextStyle(fontSize: 14, color: AppColors.grey400),
              ),
              calendarBuilders: CalendarBuilders(
                // Custom day cell with lunar date
                defaultBuilder: _showLunar ? _buildDayCell : null,
                todayBuilder: _showLunar ? (ctx, day, focused) => _buildDayCell(ctx, day, focused, isToday: true) : null,
                selectedBuilder: _showLunar ? (ctx, day, focused) => _buildDayCell(ctx, day, focused, isSelected: true) : null,
                outsideBuilder: _showLunar ? (ctx, day, focused) => _buildDayCell(ctx, day, focused, isOutside: true) : null,
                markerBuilder: (context, day, _) {
                  final dateStr = _formatDate(day);
                  final markers = <Widget>[];

                  // Work type indicator
                  final wtId = widget.calendarService.getDateWorkType(dateStr);
                  if (wtId != null) {
                    final wt = widget.calendarService.getWorkTypeById(wtId);
                    if (wt != null) {
                      markers.add(_dot(Theme.of(context).colorScheme.primary));
                    }
                  }

                  // Routine markers
                  final rInfo = _getRoutineInfo(dateStr);
                  if (rInfo.total > 0) {
                    if (rInfo.completed == rInfo.total) {
                      markers.add(_dot(AppColors.success));
                    } else if (rInfo.completed > 0) {
                      markers.add(_dot(AppColors.warning));
                    }
                  }

                  // Event marker
                  if (widget.calendarService.getByDate(dateStr).isNotEmpty) {
                    markers.add(_dot(AppColors.info));
                  }

                  // Holiday marker (solar + lunar)
                  final holiday = LunarCalendar.getHoliday(day);
                  if (holiday != null) {
                    markers.add(_dot(AppColors.error));
                  }

                  if (markers.isEmpty) return null;
                  return Positioned(
                    bottom: _showLunar ? 2 : 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: markers,
                    ),
                  );
                },
              ),
            ),
            // Active work type banner
            if (_activeWorkTypeId != null)
              Builder(builder: (_) {
                final wt = widget.calendarService.getWorkTypeById(_activeWorkTypeId!);
                if (wt == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${wt.name} · 날짜를 눌러 배정',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _activeWorkTypeId = null),
                        child: Icon(Icons.close, size: 18, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 1),
            // Content below calendar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lunar info for selected day
                  if (_showLunar) ...[
                    _buildLunarInfo(),
                    const SizedBox(height: 12),
                  ],
                  // Holiday info for selected day
                  if (!_showLunar) ...[
                    Builder(builder: (_) {
                      final holiday = LunarCalendar.getHoliday(_selectedDay);
                      if (holiday == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.celebration, size: 16, color: AppColors.errorLight),
                              const SizedBox(width: 8),
                              Text(holiday, style: TextStyle(fontSize: 13, color: AppColors.errorDark)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  // Work type for selected day
                  _buildWorkTypeChip(selectedStr, theme),
                  const SizedBox(height: 12),
                  // Routine section
                  if (routineInfo.total > 0) ...[
                    Text('루틴', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    const SizedBox(height: 4),
                    Text(
                      '${routineInfo.completed}/${routineInfo.total} 완료',
                      style: TextStyle(fontSize: 13, color: AppColors.grey600),
                    ),
                    if (routineInfo.names.isNotEmpty)
                      ...routineInfo.names.map((info) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(
                                  info.done ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: info.done ? AppColors.success : AppColors.grey500,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(info.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 16),
                  ],
                  // Events section
                  Text('일정', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const SizedBox(height: 4),
                  if (events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('일정이 없습니다', style: TextStyle(color: AppColors.grey500, fontSize: 13)),
                    ),
                  ...events.map((e) => Dismissible(
                        key: Key(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppColors.error,
                          child: const Icon(Icons.delete, color: AppColors.white),
                        ),
                        onDismissed: (_) async {
                          await widget.calendarService.delete(e.id);
                          setState(() {});
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 6,
                            backgroundColor: _parseColor(e.color),
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text(e.title, overflow: TextOverflow.ellipsis)),
                              if (e.isDDay && _showDDay) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    e.dDayString(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(e.timeString),
                          trailing: e.description.isNotEmpty
                              ? const Icon(Icons.notes, size: 16)
                              : null,
                          onTap: () => _showEditSheet(context, event: e),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Lunar day cell builder ───────────────────────────

  Widget _buildDayCell(BuildContext context, DateTime day, DateTime focusedDay, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final lunar = LunarCalendar.solarToLunar(day);
    final holiday = LunarCalendar.getHoliday(day);
    final solarHoliday = LunarCalendar.getSolarHoliday(day.month, day.day);
    final lunarHoliday = LunarCalendar.getLunarHoliday(day);
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final isHoliday = holiday != null;

    Color textColor;
    if (isOutside) {
      textColor = AppColors.grey400;
    } else if (isToday || isSelected) {
      textColor = AppColors.white;
    } else if (isHoliday || isWeekend) {
      textColor = AppColors.errorMid;
    } else {
      textColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.black;
    }

    // Subtitle text: holiday name > lunar month start > lunar day
    String lunarText = '';
    if (holiday != null) {
      lunarText = holiday;
    } else if (lunar != null) {
      if (lunar.day == 1) {
        lunarText = '${lunar.month}월';
      } else {
        lunarText = '${lunar.day}';
      }
    }

    Color lunarColor;
    if (isToday || isSelected) {
      lunarColor = AppColors.white.withOpacity(0.7);
    } else if (isHoliday) {
      lunarColor = AppColors.errorLight;
    } else if (isOutside) {
      lunarColor = AppColors.grey400;
    } else {
      lunarColor = AppColors.grey500;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: isToday || isSelected
          ? BoxDecoration(
              color: isSelected ? AppColors.calendarSelected : AppColors.primary,
              shape: BoxShape.circle,
            )
          : null,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(fontSize: 14, color: textColor),
          ),
          if (lunarText.isNotEmpty)
            Text(
              lunarText,
              style: TextStyle(fontSize: 8, color: lunarColor),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // ─── Lunar info widget ────────────────────────────────

  Widget _buildLunarInfo() {
    final lunar = LunarCalendar.solarToLunar(_selectedDay);
    if (lunar == null) return const SizedBox.shrink();

    final holiday = LunarCalendar.getHoliday(_selectedDay);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.calendarLunar.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.calendarLunar.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.dark_mode_outlined, size: 16, color: AppColors.calendarLunar.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(
            lunar.shortString,
            style: TextStyle(fontSize: 13, color: AppColors.calendarLunar),
          ),
          if (holiday != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.calendarLunar.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                holiday,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.calendarLunar),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────

  Widget _dot(Color color) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.info;
    }
  }

  _RoutineInfo _getRoutineInfo(String dateStr) {
    if (widget.routineService == null || widget.completionService == null) {
      return _RoutineInfo(total: 0, completed: 0, names: []);
    }
    final date = DateTime.tryParse(dateStr);
    if (date == null) return _RoutineInfo(total: 0, completed: 0, names: []);

    final routines = widget.routineService!.getAll();
    final active = routines.where((r) => r.isActiveOnDate(date)).toList();
    int completed = 0;
    final names = <_RoutineNameInfo>[];
    for (final r in active) {
      final done = widget.completionService!.isCompleted(r.id, dateStr) ||
          widget.completionService!.isSkipped(r.id, dateStr);
      if (done) completed++;
      names.add(_RoutineNameInfo(name: r.name, done: done));
    }
    return _RoutineInfo(total: active.length, completed: completed, names: names);
  }

  // ─── Work Type UI ────────────────────────────────────

  Widget _buildWorkTypeChip(String dateStr, ThemeData theme) {
    final wtId = widget.calendarService.getDateWorkType(dateStr);
    final wt = wtId != null ? widget.calendarService.getWorkTypeById(wtId) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: wt != null
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: wt != null
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.work_outline, size: 16,
            color: wt != null ? theme.colorScheme.primary : AppColors.grey500,
          ),
          const SizedBox(width: 8),
          Text(
            wt?.name ?? '근무형태 없음',
            style: TextStyle(
              fontSize: 13,
              color: wt != null ? theme.colorScheme.primary : AppColors.grey500,
              fontWeight: wt != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkTypeManager(BuildContext context) {
    showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WorkTypeManagerSheet(
        calendarService: widget.calendarService,
        settingsService: widget.settingsService,
        activeWorkTypeId: _activeWorkTypeId,
      ),
    ).then((activatedId) {
      // activatedId: 'none' = deactivate, null = no change, otherwise = activated id
      if (activatedId == 'none') {
        setState(() => _activeWorkTypeId = null);
      } else if (activatedId != null) {
        setState(() => _activeWorkTypeId = activatedId);
      } else {
        setState(() {}); // refresh for any work type changes
      }
    });
  }

  Future<void> _showEditSheet(BuildContext context, {CalendarEvent? event}) async {
    final result = await showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventEditSheet(
        event: event,
        initialDate: _selectedDay,
      ),
    );
    if (result == null) return;

    if (event != null) {
      result.id = event.id;
      result.createdAt = event.createdAt;
      await widget.calendarService.update(result);
    } else {
      await widget.calendarService.add(result);
    }
    setState(() {});
  }
}

class _RoutineInfo {
  final int total;
  final int completed;
  final List<_RoutineNameInfo> names;
  _RoutineInfo({required this.total, required this.completed, required this.names});
}

class _RoutineNameInfo {
  final String name;
  final bool done;
  _RoutineNameInfo({required this.name, required this.done});
}

// ─── Event Edit Sheet ──────────────────────────────────

class _EventEditSheet extends StatefulWidget {
  final CalendarEvent? event;
  final DateTime initialDate;

  const _EventEditSheet({this.event, required this.initialDate});

  @override
  State<_EventEditSheet> createState() => _EventEditSheetState();
}

class _EventEditSheetState extends State<_EventEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _date;
  int? _startHour;
  int? _startMinute;
  int? _endHour;
  int? _endMinute;
  String _color = '#2196F3';
  bool _isDDay = false;

  static const _colorOptions = [
    '#2196F3', '#4CAF50', '#FF9800', '#E91E63', '#9C27B0', '#00BCD4',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descController = TextEditingController(text: widget.event?.description ?? '');
    _date = widget.event != null
        ? DateTime.parse(widget.event!.date)
        : widget.initialDate;
    _startHour = widget.event?.startHour;
    _startMinute = widget.event?.startMinute;
    _endHour = widget.event?.endHour;
    _endMinute = widget.event?.endMinute;
    _color = widget.event?.color ?? '#2196F3';
    _isDDay = widget.event?.isDDay ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event == null ? '일정 추가' : '일정 편집',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Date picker + D-Day toggle
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_formatDate(_date)),
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('D-Day'),
                  selected: _isDDay,
                  onSelected: (v) => setState(() => _isDDay = v),
                  avatar: Icon(
                    Icons.flag,
                    size: 16,
                    color: _isDDay ? AppColors.error : AppColors.grey500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Time pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStartTime,
                    child: Text(_startHour != null
                        ? '${_startHour!.toString().padLeft(2, '0')}:${(_startMinute ?? 0).toString().padLeft(2, '0')}'
                        : '시작 시간'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickEndTime,
                    child: Text(_endHour != null
                        ? '${_endHour!.toString().padLeft(2, '0')}:${(_endMinute ?? 0).toString().padLeft(2, '0')}'
                        : '종료 시간'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            // Color picker
            Wrap(
              spacing: 8,
              children: _colorOptions.map((c) {
                final isSelected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppColors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.black.withOpacity(0.26), blurRadius: 4)]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startHour ?? 9, minute: _startMinute ?? 0),
    );
    if (picked != null) {
      setState(() {
        _startHour = picked.hour;
        _startMinute = picked.minute;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _endHour ?? 10, minute: _endMinute ?? 0),
    );
    if (picked != null) {
      setState(() {
        _endHour = picked.hour;
        _endMinute = picked.minute;
      });
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      CalendarEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: _descController.text.trim(),
        date: _formatDate(_date),
        startHour: _startHour,
        startMinute: _startMinute,
        endHour: _endHour,
        endMinute: _endMinute,
        color: _color,
        isDDay: _isDDay,
      ),
    );
  }
}

// ─── Work Type Manager Sheet ──────────────────────────────

class _WorkTypeManagerSheet extends StatefulWidget {
  final CalendarService calendarService;
  final SettingsService? settingsService;
  final String? activeWorkTypeId;

  const _WorkTypeManagerSheet({
    required this.calendarService,
    this.settingsService,
    this.activeWorkTypeId,
  });

  @override
  State<_WorkTypeManagerSheet> createState() => _WorkTypeManagerSheetState();
}

class _WorkTypeManagerSheetState extends State<_WorkTypeManagerSheet> {
  late String? _activeId;

  @override
  void initState() {
    super.initState();
    _activeId = widget.activeWorkTypeId;
  }

  /// Get all routine section IDs from dashboard order.
  List<_RoutineSectionInfo> _getRoutineSections() {
    final ss = widget.settingsService;
    if (ss == null) return [];
    final order = ss.dashboardOrder;
    final sections = <_RoutineSectionInfo>[];
    for (final id in order) {
      if (SettingsService.sectionBaseId(id) == 'routine') {
        if (ss.isDashboardSectionHidden(id)) continue;
        final label = ss.getSectionLabel(id) ?? '루틴';
        sections.add(_RoutineSectionInfo(id: id, label: label));
      }
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workTypes = widget.calendarService.getWorkTypes();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(
              children: [
                Flexible(child: Text('근무형태 관리', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddEdit(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('추가'),
                ),
              ],
            ),
            if (_activeId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  '날짜를 눌러 배정하세요',
                  style: TextStyle(fontSize: 12, color: AppColors.grey500),
                ),
              ),
            const SizedBox(height: 8),
            if (workTypes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('근무형태를 추가해보세요', style: TextStyle(color: AppColors.grey500, fontSize: 14)),
              )
            else
              ...workTypes.map((wt) {
                final isActive = _activeId == wt.id;
                final linkedSections = widget.settingsService?.getSectionsForWorkType(wt.id) ?? [];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.work,
                      size: 18,
                      color: isActive ? Colors.white : theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(wt.name, overflow: TextOverflow.ellipsis),
                  subtitle: linkedSections.isNotEmpty
                      ? Text(
                          '섹션 ${linkedSections.length}개 연동',
                          style: TextStyle(fontSize: 12, color: AppColors.grey500),
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () => _showAddEdit(context, existing: wt),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 22,
                          color: isActive ? theme.colorScheme.primary : AppColors.grey500,
                        ),
                        tooltip: isActive ? '배정모드 해제' : '배정모드 활성',
                        onPressed: () {
                          setState(() {
                            _activeId = isActive ? null : wt.id;
                          });
                          Navigator.pop(context, isActive ? 'none' : wt.id);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                        onPressed: () => _confirmDelete(context, wt),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddEdit(BuildContext context, {WorkType? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final routineSections = _getRoutineSections();
    // Get currently linked section IDs for this work type
    final linkedSectionIds = <String>{};
    if (existing != null) {
      linkedSectionIds.addAll(
        widget.settingsService?.getSectionsForWorkType(existing.id) ?? [],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? '근무형태 추가' : '근무형태 수정'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: existing == null,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        hintText: '예: 오전근무, 야간, 휴가',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (routineSections.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('루틴 섹션 연동', style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                        '이 근무형태일 때 표시할 루틴 섹션',
                        style: TextStyle(fontSize: 11, color: AppColors.grey500),
                      ),
                      const SizedBox(height: 8),
                      ...routineSections.map((s) {
                        final isLinked = linkedSectionIds.contains(s.id);
                        // Check if another work type already links this section
                        final currentWtId = widget.settingsService?.getSectionWorkType(s.id);
                        final otherWtName = (currentWtId != null && currentWtId != existing?.id)
                            ? widget.calendarService.getWorkTypeById(currentWtId)?.name
                            : null;
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: isLinked,
                          title: Text(s.label, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                          subtitle: otherWtName != null
                              ? Text('현재: $otherWtName', style: TextStyle(fontSize: 11, color: AppColors.grey500))
                              : null,
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                linkedSectionIds.add(s.id);
                              } else {
                                linkedSectionIds.remove(s.id);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  String wtId;
                  if (existing != null) {
                    existing.name = name;
                    await widget.calendarService.updateWorkType(existing);
                    wtId = existing.id;
                  } else {
                    wtId = DateTime.now().millisecondsSinceEpoch.toString();
                    await widget.calendarService.addWorkType(WorkType(
                      id: wtId,
                      name: name,
                    ));
                  }
                  // Update section links
                  if (widget.settingsService != null) {
                    for (final s in routineSections) {
                      if (linkedSectionIds.contains(s.id)) {
                        await widget.settingsService!.setSectionWorkType(s.id, wtId);
                      } else {
                        // Only clear if this section was linked to this work type
                        final cur = widget.settingsService!.getSectionWorkType(s.id);
                        if (cur == wtId) {
                          await widget.settingsService!.setSectionWorkType(s.id, null);
                        }
                      }
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WorkType wt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('근무형태 삭제'),
        content: Text('"${wt.name}"을(를) 삭제하시겠습니까?\n연결된 날짜 배정도 해제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              // Unlink sections
              if (widget.settingsService != null) {
                final linked = widget.settingsService!.getSectionsForWorkType(wt.id);
                for (final sId in linked) {
                  await widget.settingsService!.setSectionWorkType(sId, null);
                }
              }
              await widget.calendarService.deleteWorkType(wt.id);
              if (_activeId == wt.id) _activeId = null;
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _RoutineSectionInfo {
  final String id;
  final String label;
  _RoutineSectionInfo({required this.id, required this.label});
}
