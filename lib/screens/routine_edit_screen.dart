import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../models/alarm.dart';
import '../models/timer_preset.dart';
import '../services/routine_service.dart';
import '../services/alarm_service.dart';
import '../services/timer_service.dart';
import '../services/routine_group_service.dart';
import '../services/calendar_service.dart';
import '../theme/app_colors.dart';

class RoutineEditScreen extends StatefulWidget {
  final RoutineService routineService;
  final AlarmService? alarmService;
  final TimerService? timerService;
  final RoutineGroupService? routineGroupService;
  final CalendarService? calendarService;
  final model.Routine? routine;

  const RoutineEditScreen({
    super.key,
    required this.routineService,
    this.alarmService,
    this.timerService,
    this.routineGroupService,
    this.calendarService,
    this.routine,
  });

  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late model.TimeOfDay _startTime;
  late model.TimeOfDay _endTime;
  late List<bool> _activeDays;
  late List<String> _blockedApps;
  DateTime _startDate = DateTime.now();
  bool _isEditing = false;
  bool _isEnabled = true;
  bool _isAllDay = false;
  String? _linkedAlarmId;
  String? _linkedTimerId;
  bool _blockAppsEnabled = false;
  bool _overlayEnabled = true;
  bool _appLockEnabled = false;
  bool _nagEnabled = true;
  int _nagFrequency = 30;
  int _nagIntensity = 1;
  String? _workTypeId;

  // Common app packages for selection
  static const _commonApps = <String, String>{
    'com.google.android.youtube': 'YouTube',
    'com.instagram.android': 'Instagram',
    'com.twitter.android': 'X (Twitter)',
    'com.facebook.katana': 'Facebook',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.kakao.talk': '카카오톡',
    'com.nhn.android.band': 'BAND',
    'com.nhn.android.webtoon': '네이버 웹툰',
    'com.kakao.page': '카카오페이지',
    'com.naver.linewebtoon': 'LINE 웹툰',
    'com.supercell.brawlstars': '브롤스타즈',
    'com.nexon.maplem.global': '메이플스토리',
  };

  @override
  void initState() {
    super.initState();
    _isEditing = widget.routine != null;
    final r = widget.routine;
    _nameController = TextEditingController(text: r?.name ?? '');
    _descController = TextEditingController(text: r?.description ?? '');
    _startTime = r?.startTime ?? const model.TimeOfDay(hour: 9, minute: 0);
    _endTime = r?.endTime ?? const model.TimeOfDay(hour: 10, minute: 0);
    _activeDays = r?.activeDays.toList() ?? List.filled(7, true);
    _blockedApps = r?.blockedApps.toList() ?? [];
    _isEnabled = r?.isEnabled ?? true;
    _isAllDay = r?.isAllDay ?? false;
    _linkedAlarmId = r?.linkedAlarmId;
    _linkedTimerId = r?.linkedTimerId;
    _blockAppsEnabled = _blockedApps.isNotEmpty;
    _overlayEnabled = r?.overlayEnabled ?? true;
    _appLockEnabled = r?.appLockEnabled ?? false;
    _nagEnabled = r?.nagEnabled ?? true;
    _nagFrequency = r?.nagFrequency ?? 30;
    _nagIntensity = r?.nagIntensity ?? 1;
    _workTypeId = r?.workTypeId;
    if (r?.startDate != null) {
      final parts = r!.startDate!.split('-');
      if (parts.length == 3) {
        _startDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } else if (r == null) {
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '루틴 수정' : '루틴 추가'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteRoutine,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '루틴 이름',
                hintText: '예: 아침 공부, 운동',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? '이름을 입력해주세요' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Start date
            const Text('시작 날짜',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              '이 날짜부터 루틴이 활성화됩니다',
              style: TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Enabled toggle
            SwitchListTile(
              title: const Text('활성화'),
              subtitle: Text(
                _isEnabled ? '루틴이 켜져 있습니다' : '루틴이 꺼져 있습니다',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              value: _isEnabled,
              onChanged: (v) => setState(() => _isEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),

            // All-day (free) toggle
            SwitchListTile(
              title: const Text('자유 루틴'),
              subtitle: Text(
                _isAllDay ? '시간 제한 없이 자유롭게' : '정해진 시간에 수행',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              value: _isAllDay,
              onChanged: (v) => setState(() => _isAllDay = v),
              contentPadding: EdgeInsets.zero,
            ),

            // Time (hidden when all-day)
            if (!_isAllDay) ...[
              const SizedBox(height: 8),
              const Text('시간',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker('시작', _startTime, (t) {
                      setState(() => _startTime = t);
                    }),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('~', style: TextStyle(fontSize: 20)),
                  ),
                  Expanded(
                    child: _buildTimePicker('종료', _endTime, (t) {
                      setState(() => _endTime = t);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Linked alarm
              _buildAlarmSelector(),
            ],
            const SizedBox(height: 8),

            // Linked timer
            _buildTimerSelector(),
            const SizedBox(height: 16),

            // Active days
            const Text('요일',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildDaySelector(),
            const SizedBox(height: 24),

            // Work type
            if (widget.calendarService != null) ...[
              _buildWorkTypeSelector(),
              const SizedBox(height: 24),
            ],

            // Nag settings
            const Divider(),
            SwitchListTile(
              title: const Text('잔소리'),
              subtitle: Text(
                _nagEnabled ? '딴짓하면 잔소리합니다' : '잔소리를 하지 않습니다',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              value: _nagEnabled,
              onChanged: (v) => setState(() => _nagEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_nagEnabled) ...[
              // Block mode: all / select
              Row(
                children: [
                  const Expanded(child: Text('차단 범위')),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('모두 차단')),
                      ButtonSegment(value: true, label: Text('선택 차단')),
                    ],
                    selected: {_blockAppsEnabled},
                    onSelectionChanged: (v) => setState(() => _blockAppsEnabled = v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              if (_blockAppsEnabled) ...[
                const SizedBox(height: 8),
                _buildAppSelector(),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('빈도')),
                  DropdownButton<int>(
                    value: _nagFrequency,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5초')),
                      DropdownMenuItem(value: 15, child: Text('15초')),
                      DropdownMenuItem(value: 30, child: Text('30초')),
                      DropdownMenuItem(value: 60, child: Text('1분')),
                      DropdownMenuItem(value: 120, child: Text('2분')),
                      DropdownMenuItem(value: 300, child: Text('5분')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _nagFrequency = v); },
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('강도')),
                  DropdownButton<int>(
                    value: _nagIntensity,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('부드럽게')),
                      DropdownMenuItem(value: 1, child: Text('보통')),
                      DropdownMenuItem(value: 2, child: Text('엄격하게')),
                    ],
                    onChanged: (v) { if (v != null) setState(() => _nagIntensity = v); },
                  ),
                ],
              ),
              // Overlay (under nag — only when nag is ON)
              SwitchListTile(
                title: const Text('오버레이'),
                subtitle: Text(
                  _overlayEnabled ? '캐릭터가 화면에 나타납니다' : '소리로만 잔소리합니다',
                  style: TextStyle(fontSize: 12, color: AppColors.grey600),
                ),
                value: _overlayEnabled,
                onChanged: (v) => setState(() => _overlayEnabled = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 8),

            // App lock (independent)
            const Divider(),
            SwitchListTile(
              title: const Text('앱 잠금'),
              subtitle: const Text('차단된 앱을 강제로 닫습니다'),
              value: _appLockEnabled,
              onChanged: (v) => setState(() => _appLockEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),

            // Save button
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? '수정' : '추가'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(
    String label,
    model.TimeOfDay time,
    ValueChanged<model.TimeOfDay> onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
        );
        if (picked != null) {
          onChanged(model.TimeOfDay(hour: picked.hour, minute: picked.minute));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          time.format(),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: List.generate(7, (i) {
        return FilterChip(
          label: Text(days[i]),
          selected: _activeDays[i],
          onSelected: (v) => setState(() => _activeDays[i] = v),
        );
      }),
    );
  }

  Widget _buildAlarmSelector() {
    final alarms = widget.alarmService?.getAll() ?? [];
    // Validate linked alarm still exists
    if (_linkedAlarmId != null && !alarms.any((a) => a.id == _linkedAlarmId)) {
      _linkedAlarmId = null;
    }
    return Row(
      children: [
        const Icon(Icons.alarm, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('시작 알림')),
        DropdownButton<String>(
          value: _linkedAlarmId ?? '',
          items: [
            const DropdownMenuItem(value: '', child: Text('없음')),
            ...alarms.map((a) => DropdownMenuItem(
              value: a.id,
              child: Text('${a.label} (${a.timeString})'),
            )),
          ],
          onChanged: (v) => setState(() => _linkedAlarmId = (v == null || v.isEmpty) ? null : v),
        ),
      ],
    );
  }

  Widget _buildTimerSelector() {
    final presets = widget.timerService?.getAll() ?? [];
    // Validate linked timer still exists
    if (_linkedTimerId != null && !presets.any((p) => p.id == _linkedTimerId)) {
      _linkedTimerId = null;
    }
    return Row(
      children: [
        const Icon(Icons.timer, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('집중 타이머')),
        DropdownButton<String>(
          value: _linkedTimerId ?? '',
          items: [
            const DropdownMenuItem(value: '', child: Text('없음')),
            ...presets.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text('${p.label} (${p.durationString})'),
            )),
          ],
          onChanged: (v) => setState(() => _linkedTimerId = (v == null || v.isEmpty) ? null : v),
        ),
      ],
    );
  }

  Widget _buildAppSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _commonApps.entries.map((e) {
        final selected = _blockedApps.contains(e.key);
        return FilterChip(
          label: Text(e.value),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _blockedApps.add(e.key);
              } else {
                _blockedApps.remove(e.key);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildWorkTypeSelector() {
    final workTypes = widget.calendarService?.getWorkTypes() ?? [];
    // Validate linked work type still exists
    if (_workTypeId != null && !workTypes.any((w) => w.id == _workTypeId)) {
      _workTypeId = null;
    }
    return Row(
      children: [
        const Icon(Icons.work_outline, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('근무형태')),
        DropdownButton<String>(
          value: _workTypeId ?? '',
          items: [
            const DropdownMenuItem(value: '', child: Text('없음 (항상 활성)')),
            ...workTypes.map((w) => DropdownMenuItem(
              value: w.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: Color(int.parse(w.color.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(w.name),
                ],
              ),
            )),
          ],
          onChanged: (v) => setState(() => _workTypeId = (v == null || v.isEmpty) ? null : v),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateStr = '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';

    final routine = model.Routine(
      id: widget.routine?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      startDate: startDateStr,
      startTime: _startTime,
      endTime: _endTime,
      blockedApps: _blockAppsEnabled ? _blockedApps : [],
      activeDays: _activeDays,
      isEnabled: _isEnabled,
      isAllDay: _isAllDay,
      linkedAlarmId: _isAllDay ? null : _linkedAlarmId,
      linkedTimerId: _linkedTimerId,
      overlayEnabled: _nagEnabled ? _overlayEnabled : false,
      appLockEnabled: _appLockEnabled,
      nagEnabled: _nagEnabled,
      nagFrequency: _nagFrequency,
      nagIntensity: _nagIntensity,
      workTypeId: _workTypeId,
    );

    if (_isEditing) {
      await widget.routineService.update(routine);
    } else {
      await widget.routineService.add(routine);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteRoutine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('루틴 삭제'),
        content: const Text('이 루틴을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.routineService.delete(widget.routine!.id);
      await widget.routineGroupService?.onRoutineDeleted(widget.routine!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }
}
