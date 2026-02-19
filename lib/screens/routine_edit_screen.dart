import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../services/routine_service.dart';
import '../theme/app_colors.dart';

class RoutineEditScreen extends StatefulWidget {
  final RoutineService routineService;
  final model.Routine? routine;

  const RoutineEditScreen({
    super.key,
    required this.routineService,
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
  bool _notifyOnStart = false;
  bool _timerEnabled = false;
  int _timerMinutes = 25;
  bool _blockAppsEnabled = false;

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
    _notifyOnStart = r?.notifyOnStart ?? false;
    _timerEnabled = r?.timerMinutes != null;
    _timerMinutes = r?.timerMinutes ?? 25;
    _blockAppsEnabled = _blockedApps.isNotEmpty;
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
            const SizedBox(height: 24),

            // Time
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

            // Notify on start
            SwitchListTile(
              title: const Text('시작 알림'),
              subtitle: Text(
                '루틴 시작 시간에 알림을 보냅니다',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              value: _notifyOnStart,
              onChanged: (v) => setState(() => _notifyOnStart = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Focus timer
            SwitchListTile(
              title: const Text('집중 타이머'),
              subtitle: Text(
                '루틴 목록에서 타이머를 빠르게 실행합니다',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              value: _timerEnabled,
              onChanged: (v) => setState(() => _timerEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_timerEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('시간: ', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28, height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero, iconSize: 18,
                      icon: const Icon(Icons.remove),
                      onPressed: _timerMinutes > 1
                          ? () => setState(() => _timerMinutes--)
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$_timerMinutes분',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(
                    width: 28, height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero, iconSize: 18,
                      icon: const Icon(Icons.add),
                      onPressed: _timerMinutes < 120
                          ? () => setState(() => _timerMinutes++)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 25, 30, 45, 60].map((m) => ChoiceChip(
                  label: Text('$m분'),
                  selected: _timerMinutes == m,
                  onSelected: (_) => setState(() => _timerMinutes = m),
                )).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // Active days
            const Text('요일',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildDaySelector(),
            const SizedBox(height: 24),

            // Blocked apps
            SwitchListTile(
              title: const Text('앱 차단'),
              subtitle: Text(
                _blockAppsEnabled
                    ? '선택한 앱만 잔소리합니다'
                    : '끄면 모든 앱에서 잔소리합니다',
                style: TextStyle(fontSize: 12, color: AppColors.grey600),
              ),
              value: _blockAppsEnabled,
              onChanged: (v) => setState(() => _blockAppsEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_blockAppsEnabled) ...[
              const SizedBox(height: 8),
              _buildAppSelector(),
            ],
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
      notifyOnStart: _notifyOnStart,
      timerMinutes: _timerEnabled ? _timerMinutes : null,
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
      if (mounted) Navigator.pop(context, true);
    }
  }
}
