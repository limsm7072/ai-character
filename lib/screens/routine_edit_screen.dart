import 'package:flutter/material.dart';
import '../models/routine.dart' as model;
import '../services/routine_service.dart';

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
  bool _isEditing = false;

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
          padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 24),

            // Active days
            const Text('요일',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildDaySelector(),
            const SizedBox(height: 24),

            // Blocked apps
            const Text('차단할 앱',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              '선택하지 않으면 모든 앱에서 잔소리합니다',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            _buildAppSelector(),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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

    final routine = model.Routine(
      id: widget.routine?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      startTime: _startTime,
      endTime: _endTime,
      blockedApps: _blockedApps,
      activeDays: _activeDays,
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
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
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
