import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class AlarmScreen extends StatefulWidget {
  final AlarmService alarmService;

  const AlarmScreen({super.key, required this.alarmService});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  List<Alarm> _alarms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _alarms = widget.alarmService.getAll().toList());
  }

  Future<void> _ensurePermissions() async {
    final ns = NotificationService();
    if (!ns.hasNotificationPermission || !ns.canScheduleExact) {
      await ns.requestPermissions();
    }
  }

  Future<void> _addAlarm() async {
    await _ensurePermissions();
    final result = await _showEditSheet(null);
    if (result == true) _load();
  }

  Future<void> _editAlarm(Alarm alarm) async {
    final result = await _showEditSheet(alarm);
    if (result == true) _load();
  }

  Future<void> _deleteAlarm(Alarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('알람 삭제'),
        content: Text('"${alarm.label}" 알람을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.alarmService.delete(alarm.id);
      _load();
    }
  }

  Future<void> _toggleAlarm(Alarm alarm) async {
    if (!alarm.isEnabled) {
      // Enabling an alarm — ensure permissions
      await _ensurePermissions();
    }
    await widget.alarmService.toggleEnabled(alarm.id);
    _load();
  }

  Future<bool?> _showEditSheet(Alarm? existing) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AlarmEditSheet(
        alarm: existing,
        onSave: (alarm) async {
          if (existing != null) {
            alarm.id = existing.id;
            alarm.createdAt = existing.createdAt;
            await widget.alarmService.update(alarm);
          } else {
            await widget.alarmService.add(alarm);
          }
          if (ctx.mounted) Navigator.pop(ctx, true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _alarms.where((a) => a.isEnabled).toList();
    final disabled = _alarms.where((a) => !a.isEnabled).toList();
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('알람')),
      body: _alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm_off, size: 64, color: AppColors.grey400),
                  const SizedBox(height: 16),
                  Text(
                    '알람을 추가해보세요!',
                    style: TextStyle(fontSize: 18, color: AppColors.grey600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+ 버튼을 눌러 새 알람을 만드세요',
                    style: TextStyle(fontSize: 13, color: AppColors.grey500),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.only(top: 8, bottom: 80 + bottomPad),
              children: [
                ...enabled.map((a) => _buildAlarmCard(a)),
                if (disabled.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '비활성 (${disabled.length})',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.grey600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...disabled.map((a) => _buildAlarmCard(a)),
                ],
              ],
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: FloatingActionButton(
          onPressed: _addAlarm,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildAlarmCard(Alarm alarm) {
    final theme = Theme.of(context);
    final isOn = alarm.isEnabled;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editAlarm(alarm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Time + Switch + Delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // AM/PM label
                  Text(
                    alarm.hour < 12 ? '오전' : '오후',
                    style: TextStyle(
                      fontSize: 14,
                      color: isOn ? theme.colorScheme.primary : AppColors.grey500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Time — Flexible to prevent overflow
                  Flexible(
                    child: Text(
                      _format12Hour(alarm.hour, alarm.minute),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        color: isOn ? null : AppColors.grey500,
                        letterSpacing: -1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Delete button
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.delete_outline, color: AppColors.grey400, size: 20),
                      onPressed: () => _deleteAlarm(alarm),
                      tooltip: '삭제',
                    ),
                  ),
                  // Toggle switch
                  Switch(
                    value: isOn,
                    onChanged: (_) => _toggleAlarm(alarm),
                  ),
                ],
              ),
              // Row 2: Label + Days
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alarm.label,
                      style: TextStyle(
                        fontSize: 15,
                        color: isOn ? null : AppColors.grey500,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Day chips
                  _buildDayIndicator(alarm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayIndicator(Alarm alarm) {
    if (alarm.isOneTime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: alarm.isEnabled ? AppColors.accent.withValues(alpha: 0.15) : AppColors.grey500.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '한 번',
          style: TextStyle(
            fontSize: 12,
            color: alarm.isEnabled ? AppColors.accentDark : AppColors.grey500,
          ),
        ),
      );
    }

    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final active = alarm.activeDays[i];
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(left: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? (alarm.isEnabled ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : AppColors.grey500.withValues(alpha: 0.1))
                : null,
            shape: BoxShape.circle,
          ),
          child: Text(
            dayLabels[i],
            style: TextStyle(
              fontSize: 9,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active
                  ? (alarm.isEnabled ? Theme.of(context).colorScheme.primary : AppColors.grey500)
                  : AppColors.grey400,
            ),
          ),
        );
      }),
    );
  }

  String _format12Hour(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '${h.toString()}:${minute.toString().padLeft(2, '0')}';
  }
}

// ─── Edit Sheet ────────────────────────────────────────

class _AlarmEditSheet extends StatefulWidget {
  final Alarm? alarm;
  final Future<void> Function(Alarm) onSave;

  const _AlarmEditSheet({this.alarm, required this.onSave});

  @override
  State<_AlarmEditSheet> createState() => _AlarmEditSheetState();
}

class _AlarmEditSheetState extends State<_AlarmEditSheet> {
  late int _hour;
  late int _minute;
  late TextEditingController _labelController;
  late List<bool> _activeDays;
  bool _saving = false;
  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _hour = widget.alarm?.hour ?? now.hour;
    _minute = widget.alarm?.minute ?? ((now.minute ~/ 5 + 1) * 5) % 60;
    _labelController = TextEditingController(text: widget.alarm?.label ?? '');
    _activeDays = widget.alarm?.activeDays.toList() ?? List.filled(7, false);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.alarm != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset + bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? '알람 편집' : '새 알람',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('저장'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Time display - tap to pick
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hour < 12 ? '오전' : '오후',
                        style: TextStyle(
                          fontSize: 18,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _format12Hour(_hour, _minute),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit, size: 18, color: AppColors.grey500),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Label input
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: '알람 이름',
                hintText: '예: 기상, 약 먹기, 회의...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 20),
            // Repeat days
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '반복 요일',
                      style: TextStyle(fontSize: 14, color: AppColors.grey700, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    if (_activeDays.every((d) => !d))
                      Text(
                        '(선택 안 하면 한 번만 울림)',
                        style: TextStyle(fontSize: 12, color: AppColors.grey500),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // 7 day buttons — use LayoutBuilder to avoid overflow
                LayoutBuilder(
                  builder: (context, constraints) {
                    final btnSize = ((constraints.maxWidth - 6 * 6) / 7).clamp(28.0, 40.0);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (i) {
                        final selected = _activeDays[i];
                        return GestureDetector(
                          onTap: () => setState(() => _activeDays[i] = !_activeDays[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: btnSize,
                            height: btnSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _dayLabels[i],
                              style: TextStyle(
                                fontSize: btnSize * 0.35,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                color: selected ? theme.colorScheme.onPrimary : AppColors.grey600,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Quick select buttons — Wrap to avoid overflow
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickSelectChip(
                      label: '매일',
                      onTap: () => setState(() => _activeDays = List.filled(7, true)),
                    ),
                    _QuickSelectChip(
                      label: '평일',
                      onTap: () => setState(() => _activeDays = [true, true, true, true, true, false, false]),
                    ),
                    _QuickSelectChip(
                      label: '주말',
                      onTap: () => setState(() => _activeDays = [false, false, false, false, false, true, true]),
                    ),
                    _QuickSelectChip(
                      label: '초기화',
                      onTap: () => setState(() => _activeDays = List.filled(7, false)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _format12Hour(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '${h.toString()}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알람 이름을 입력해주세요'), duration: Duration(seconds: 2)),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(Alarm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      hour: _hour,
      minute: _minute,
      activeDays: _activeDays,
    ));
  }
}

class _QuickSelectChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickSelectChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grey300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.grey600)),
      ),
    );
  }
}
