import 'package:flutter/material.dart';
import '../service_locator.dart';
import '../models/goal.dart';
import '../models/routine.dart';
import '../models/todo.dart';
import '../services/goal_service.dart';
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/todo_service.dart';
import '../theme/app_colors.dart';

class GoalScreen extends StatefulWidget {
  final String? title;

  const GoalScreen({
    super.key,
    this.title,
  });

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  List<Goal> _goals = [];
  String _filterCategory = '전체';

  GoalService get _goalService => getIt<GoalService>();
  RoutineService get _routineService => getIt<RoutineService>();
  RoutineCompletionService get _completionService => getIt<RoutineCompletionService>();
  TodoService get _todoService => getIt<TodoService>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _goals = _goalService.getAll());
  }

  List<Goal> get _filtered {
    if (_filterCategory == '전체') return _goals;
    return _goals.where((g) => g.category == _filterCategory).toList();
  }

  List<Goal> get _incomplete => _filtered.where((g) => !g.isCompleted).toList();
  List<Goal> get _completed => _filtered.where((g) => g.isCompleted).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '목표'),
      ),
      body: Column(
        children: [
          // 카테고리 필터
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ['전체', ...Goal.categories].map((cat) {
                final selected = _filterCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _filterCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _goals.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.track_changes, size: 64, color: AppColors.grey400),
                        const SizedBox(height: 16),
                        Text('목표를 추가해보세요!', style: TextStyle(fontSize: 16, color: AppColors.grey600)),
                        const SizedBox(height: 8),
                        Text('루틴과 할일을 연결하면\n진행률을 자동으로 추적해요',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.grey500)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      ..._incomplete.map((g) => _buildGoalCard(g, theme)),
                      if (_completed.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Text('완료됨 (${_completed.length})',
                              style: TextStyle(fontSize: 13, color: AppColors.grey600, fontWeight: FontWeight.w600)),
                        ),
                        ..._completed.map((g) => _buildGoalCard(g, theme)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal, ThemeData theme) {
    final progress = _goalService.getProgress(goal, _completionService, _todoService);
    final catColor = Goal.categoryColor(goal.category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(goal),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Goal.categoryIcon(goal.category), size: 18, color: catColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(goal.title,
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: goal.isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                            decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (goal.dDayString != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: goal.isOverdue ? Colors.red.withValues(alpha: 0.1) : catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(goal.dDayString!,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: goal.isOverdue ? Colors.red : catColor)),
                      ),
                  ],
                ),
                if (goal.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(goal.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 10),
                // 진행률 바
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(catColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(progress * 100).round()}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: catColor)),
                  ],
                ),
                // 마일스톤 요약
                if (goal.milestones.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('마일스톤 ${goal.completedMilestones}/${goal.milestones.length}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 목표 추가 다이얼로그 ───
  void _showAddDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = '기타';
    String? targetDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('새 목표', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '목표 제목 (예: 10kg 감량)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      hintText: '설명 (선택사항)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Text('카테고리', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: Goal.categories.map((cat) {
                      final selected = category == cat;
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Goal.categoryIcon(cat), size: 14,
                                color: selected ? Colors.white : Goal.categoryColor(cat)),
                            const SizedBox(width: 4),
                            Text(cat),
                          ],
                        ),
                        selected: selected,
                        selectedColor: Goal.categoryColor(cat),
                        onSelected: (_) => setSheetState(() => category = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // 기한 설정
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        locale: const Locale('ko', 'KR'),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          targetDate = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(targetDate ?? '목표 기한 설정 (선택사항)',
                              style: TextStyle(fontSize: 14,
                                  color: targetDate != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant)),
                          const Spacer(),
                          if (targetDate != null)
                            GestureDetector(
                              onTap: () => setSheetState(() => targetDate = null),
                              child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        await _goalService.add(title,
                            description: descCtrl.text.trim(),
                            category: category,
                            targetDate: targetDate);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      child: const Text('추가'),
                    ),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── 목표 상세 뷰 ───
  void _openDetail(Goal goal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _GoalDetailScreen(
          goal: goal,
          onChanged: _load,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 목표 상세 화면
// ═══════════════════════════════════════════════════════════════
class _GoalDetailScreen extends StatefulWidget {
  final Goal goal;
  final VoidCallback onChanged;

  const _GoalDetailScreen({
    required this.goal,
    required this.onChanged,
  });

  @override
  State<_GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<_GoalDetailScreen> {
  late Goal _goal;

  GoalService get _goalService => getIt<GoalService>();
  RoutineService get _routineService => getIt<RoutineService>();
  RoutineCompletionService get _completionService => getIt<RoutineCompletionService>();
  TodoService get _todoService => getIt<TodoService>();

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
  }

  void _reload() {
    final updated = _goalService.getById(_goal.id);
    if (updated != null) {
      setState(() => _goal = updated);
      widget.onChanged();
    }
  }

  double get _progress =>
      _goalService.getProgress(_goal, _completionService, _todoService);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = Goal.categoryColor(_goal.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(_goal.title),
        actions: [
          // 완료 토글
          IconButton(
            icon: Icon(_goal.isCompleted ? Icons.undo : Icons.check_circle_outline),
            tooltip: _goal.isCompleted ? '미완료로 변경' : '완료로 변경',
            onPressed: () async {
              await _goalService.toggleComplete(_goal.id);
              _reload();
            },
          ),
          // 삭제
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 헤더: 진행률 ───
          _buildProgressHeader(theme, catColor),
          const SizedBox(height: 20),

          // ─── 기본 정보 ───
          if (_goal.description.isNotEmpty) ...[
            Text(_goal.description, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
          ],

          // ─── 마일스톤 ───
          _buildSection(theme, '마일스톤', Icons.flag_outlined, _buildMilestones(theme)),
          const SizedBox(height: 16),

          // ─── 연결된 루틴 ───
          _buildSection(theme, '연결된 루틴', Icons.repeat, _buildLinkedRoutines(theme)),
          const SizedBox(height: 16),

          // ─── 연결된 할일 ───
          _buildSection(theme, '연결된 할일', Icons.checklist, _buildLinkedTodos(theme)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(ThemeData theme, Color catColor) {
    final pct = (_progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 원형 진행률
          SizedBox(
            width: 72, height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72, height: 72,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 6,
                    backgroundColor: catColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(catColor),
                  ),
                ),
                Text('$pct%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: catColor)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: catColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Goal.categoryIcon(_goal.category), size: 12, color: catColor),
                          const SizedBox(width: 4),
                          Text(_goal.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
                        ],
                      ),
                    ),
                    if (_goal.dDayString != null) ...[
                      const SizedBox(width: 8),
                      Text(_goal.dDayString!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _goal.isOverdue ? Colors.red : theme.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (_goal.milestones.isNotEmpty)
                  Text('마일스톤 ${_goal.completedMilestones}/${_goal.milestones.length}',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                if (_goal.linkedRoutineIds.isNotEmpty)
                  Text('루틴 ${_goal.linkedRoutineIds.length}개 연결',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, IconData icon, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  // ─── 마일스톤 ───
  Widget _buildMilestones(ThemeData theme) {
    return Column(
      children: [
        ..._goal.milestones.map((m) => ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 4),
          leading: Checkbox(
            value: m.isCompleted,
            onChanged: (_) async {
              await _goalService.toggleMilestone(_goal.id, m.id);
              _reload();
            },
          ),
          title: Text(m.title, style: TextStyle(
            fontSize: 14,
            decoration: m.isCompleted ? TextDecoration.lineThrough : null,
            color: m.isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
          )),
          trailing: IconButton(
            icon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () async {
              await _goalService.removeMilestone(_goal.id, m.id);
              _reload();
            },
          ),
        )),
        // 추가 버튼
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 4),
          leading: const Icon(Icons.add, size: 20),
          title: const Text('마일스톤 추가', style: TextStyle(fontSize: 14)),
          onTap: () => _addMilestoneDialog(context),
        ),
      ],
    );
  }

  void _addMilestoneDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('마일스톤 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 3kg 감량'),
          onSubmitted: (_) async {
            final text = ctrl.text.trim();
            if (text.isEmpty) return;
            await _goalService.addMilestone(_goal.id, text);
            if (ctx.mounted) Navigator.pop(ctx);
            _reload();
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              await _goalService.addMilestone(_goal.id, text);
              if (ctx.mounted) Navigator.pop(ctx);
              _reload();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // ─── 연결된 루틴 ───
  Widget _buildLinkedRoutines(ThemeData theme) {
    final allRoutines = _routineService.getAll();
    final linked = allRoutines.where((r) => _goal.linkedRoutineIds.contains(r.id)).toList();

    return Column(
      children: [
        ...linked.map((r) {
          final rate = _completionService.getCompletionRate(r.id, 7);
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 4),
            leading: Icon(Icons.repeat, size: 18, color: theme.colorScheme.primary),
            title: Text(r.name, style: const TextStyle(fontSize: 14)),
            subtitle: Text('최근 7일 완료율 ${(rate * 100).round()}%', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            trailing: IconButton(
              icon: Icon(Icons.link_off, size: 16, color: theme.colorScheme.onSurfaceVariant),
              onPressed: () async {
                await _goalService.unlinkRoutine(_goal.id, r.id);
                _reload();
              },
            ),
          );
        }),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 4),
          leading: const Icon(Icons.add_link, size: 20),
          title: const Text('루틴 연결', style: TextStyle(fontSize: 14)),
          onTap: () => _showRoutinePicker(context, allRoutines),
        ),
      ],
    );
  }

  void _showRoutinePicker(BuildContext context, List<Routine> allRoutines) {
    final unlinked = allRoutines.where((r) => !_goal.linkedRoutineIds.contains(r.id)).toList();
    if (unlinked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('연결할 수 있는 루틴이 없어요')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('루틴 선택', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          ...unlinked.map((r) => ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(r.name),
            onTap: () async {
              await _goalService.linkRoutine(_goal.id, r.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _reload();
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── 연결된 할일 ───
  Widget _buildLinkedTodos(ThemeData theme) {
    final allTodos = _todoService.getAll();
    final linked = allTodos.where((t) => _goal.linkedTodoIds.contains(t.id)).toList();

    return Column(
      children: [
        ...linked.map((t) => ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 4),
          leading: Icon(
            t.isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18, color: t.isCompleted ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(t.title, style: TextStyle(
            fontSize: 14,
            decoration: t.isCompleted ? TextDecoration.lineThrough : null,
            color: t.isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
          )),
          trailing: IconButton(
            icon: Icon(Icons.link_off, size: 16, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () async {
              await _goalService.unlinkTodo(_goal.id, t.id);
              _reload();
            },
          ),
        )),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 4),
          leading: const Icon(Icons.add_link, size: 20),
          title: const Text('할일 연결', style: TextStyle(fontSize: 14)),
          onTap: () => _showTodoPicker(context, allTodos),
        ),
      ],
    );
  }

  void _showTodoPicker(BuildContext context, List<Todo> allTodos) {
    final unlinked = allTodos.where((t) => !_goal.linkedTodoIds.contains(t.id) && !t.isCompleted).toList();
    if (unlinked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('연결할 수 있는 할일이 없어요')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('할일 선택', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          ...unlinked.take(10).map((t) => ListTile(
            leading: const Icon(Icons.checklist),
            title: Text(t.title),
            onTap: () async {
              await _goalService.linkTodo(_goal.id, t.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _reload();
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('목표 삭제'),
        content: Text('"${_goal.title}"을(를) 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _goalService.delete(_goal.id);
              widget.onChanged();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
