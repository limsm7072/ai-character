import 'package:flutter/material.dart';
import '../models/diary.dart';
import '../services/diary_service.dart';
import '../theme/app_colors.dart';

class DiaryScreen extends StatefulWidget {
  final DiaryService diaryService;

  const DiaryScreen({super.key, required this.diaryService});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late DateTime _currentMonth;
  List<Diary> _monthDiaries = [];
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _currentMonth = DateTime(_today.year, _today.month);
    _loadMonth();
  }

  void _loadMonth() {
    setState(() {
      _monthDiaries = widget.diaryService.getByMonth(
        _currentMonth.year,
        _currentMonth.month,
      );
    });
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Diary? _diaryForDate(DateTime date) {
    final dateStr = _formatDate(date);
    for (final d in _monthDiaries) {
      if (d.date == dateStr) return d;
    }
    return null;
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadMonth();
  }

  Future<void> _openDiary(DateTime date) async {
    final dateStr = _formatDate(date);
    final existing = widget.diaryService.getByDate(dateStr);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEditScreen(
          diaryService: widget.diaryService,
          date: dateStr,
          diary: existing,
        ),
      ),
    );
    if (result == true) _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final streak = widget.diaryService.getCurrentStreak();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('일기장'),
        actions: [
          if (streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Text('🔥', style: TextStyle(fontSize: 14)),
                label: Text('$streak일 연속',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthHeader(theme),
          _buildCalendar(theme),
          const Divider(height: 1),
          Expanded(child: _buildDiaryList(theme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDiary(_today),
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildMonthHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '${_currentMonth.year}년 ${_currentMonth.month}월',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme) {
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon
    final todayStr = _formatDate(_today);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Day names
          Row(
            children: dayNames.map((d) => Expanded(
              child: Center(
                child: Text(d, style: TextStyle(fontSize: 11, color: AppColors.grey500, fontWeight: FontWeight.w600)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 4),
          // Calendar grid
          ...List.generate(6, (week) {
            return Row(
              children: List.generate(7, (weekday) {
                final dayNum = week * 7 + weekday + 1 - (startWeekday - 1);
                if (dayNum < 1 || dayNum > lastDay.day) {
                  return const Expanded(child: SizedBox(height: 36));
                }
                final date = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
                final dateStr = _formatDate(date);
                final diary = _diaryForDate(date);
                final isToday = dateStr == todayStr;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _openDiary(date),
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isToday
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (diary != null)
                            Text(diary.moodEmoji, style: const TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDiaryList(ThemeData theme) {
    final diaries = List<Diary>.from(_monthDiaries);
    diaries.sort((a, b) => b.date.compareTo(a.date));

    if (diaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories, size: 64, color: AppColors.grey400),
            const SizedBox(height: 16),
            Text('이번 달 일기가 없어요', style: TextStyle(fontSize: 16, color: AppColors.grey600)),
            const SizedBox(height: 8),
            Text('오늘의 하루를 기록해보세요!', style: TextStyle(fontSize: 13, color: AppColors.grey500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 80 + MediaQuery.of(context).viewPadding.bottom),
      itemCount: diaries.length,
      itemBuilder: (_, i) => _buildDiaryCard(diaries[i], theme),
    );
  }

  Widget _buildDiaryCard(Diary diary, ThemeData theme) {
    final dateParts = diary.date.split('-');
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    final date = DateTime(int.parse(dateParts[0]), month, day);
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDiary(date),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date + mood
              Column(
                children: [
                  Text('$month/$day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  Text(weekday, style: TextStyle(fontSize: 11, color: AppColors.grey500)),
                  const SizedBox(height: 4),
                  Text(diary.moodEmoji, style: const TextStyle(fontSize: 20)),
                ],
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diary.content.isNotEmpty ? diary.content : '(내용 없음)',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: diary.content.isNotEmpty
                            ? theme.colorScheme.onSurface
                            : AppColors.grey400,
                        height: 1.5,
                      ),
                    ),
                    if (diary.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: diary.tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('#$t', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Diary Edit Screen ──────────────────────────────────────

class DiaryEditScreen extends StatefulWidget {
  final DiaryService diaryService;
  final String date;
  final Diary? diary;

  const DiaryEditScreen({
    super.key,
    required this.diaryService,
    required this.date,
    this.diary,
  });

  @override
  State<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends State<DiaryEditScreen> {
  late TextEditingController _contentController;
  late TextEditingController _tagController;
  late int _mood;
  late List<String> _tags;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.diary != null;
    _contentController = TextEditingController(text: widget.diary?.content ?? '');
    _tagController = TextEditingController();
    _mood = widget.diary?.mood ?? 2;
    _tags = widget.diary?.tags.toList() ?? [];
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String _formatDateTitle() {
    final parts = widget.date.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final date = DateTime(int.parse(year), month, day);
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '$month월 $day일 (${weekdays[date.weekday - 1]})';
  }

  Future<void> _save() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diary = Diary(
      id: widget.diary?.id ?? now.toString(),
      date: widget.date,
      content: _contentController.text,
      mood: _mood,
      tags: _tags,
      createdAt: widget.diary?.createdAt ?? now,
      updatedAt: now,
    );
    await widget.diaryService.save(diary);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (widget.diary == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('이 일기를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.diaryService.delete(widget.diary!.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatDateTitle()),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
        children: [
          // Mood selector
          Text('오늘의 기분', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final isSelected = _mood == i;
              return GestureDetector(
                onTap: () => setState(() => _mood = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : Border.all(color: Colors.transparent, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(Diary.moodEmojis[i], style: TextStyle(fontSize: isSelected ? 32 : 24)),
                      const SizedBox(height: 4),
                      Text(
                        Diary.moodLabels[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? theme.colorScheme.primary : AppColors.grey500,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Content
          Text('오늘의 일기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            decoration: InputDecoration(
              hintText: '오늘 하루는 어땠나요?',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              hintStyle: TextStyle(color: AppColors.grey400),
            ),
            maxLines: 10,
            minLines: 5,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 24),

          // Tags
          Text('태그', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: '태그 추가',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    hintStyle: TextStyle(color: AppColors.grey400),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addTag,
                icon: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _tags.map((t) => Chip(
                label: Text('#$t', style: const TextStyle(fontSize: 13)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _tags.remove(t)),
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
