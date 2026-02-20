import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../services/todo_service.dart';
import '../theme/app_colors.dart';

class TodoScreen extends StatefulWidget {
  final TodoService todoService;
  final String? title;

  const TodoScreen({super.key, required this.todoService, this.title});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  List<Todo> _todos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _load() {
    setState(() => _todos = widget.todoService.getAll());
  }

  List<Todo> get _incomplete => _todos.where((t) => !t.isCompleted).toList();
  List<Todo> get _completed => _todos.where((t) => t.isCompleted).toList();

  Future<void> _addTodo() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    await widget.todoService.add(text);
    _inputController.clear();
    _focusNode.requestFocus();
    _load();
  }

  Future<void> _toggleComplete(Todo todo) async {
    await widget.todoService.toggleComplete(todo.id);
    _load();
  }

  Future<void> _deleteTodo(Todo todo) async {
    await widget.todoService.delete(todo.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
      },
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: Text(widget.title ?? '할 일')),
        body: Column(
          children: [
            Expanded(
              child: _todos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: AppColors.grey400),
                          const SizedBox(height: 16),
                          Text(
                            '할 일을 추가해보세요!',
                            style: TextStyle(fontSize: 18, color: AppColors.grey600),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      children: [
                        ..._incomplete.map((t) => _buildTodoItem(t, theme)),
                        if (_completed.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              '완료됨 (${_completed.length})',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.grey600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ..._completed.map((t) => _buildTodoItem(t, theme)),
                        ],
                      ],
                    ),
            ),
            // Bottom input bar
            Container(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.of(context).viewPadding.bottom),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: '새 할 일 입력...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _addTodo(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addTodo,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate(Todo todo) async {
    final initial = todo.dueDate != null ? DateTime.tryParse(todo.dueDate!) : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      todo.dueDate = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      await widget.todoService.update(todo);
      _load();
    } else if (todo.dueDate != null) {
      // Show option to clear
      if (!mounted) return;
      final clear = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('마감일'),
          content: Text('마감일(${todo.dueDateDisplay})을 삭제할까요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('유지')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
          ],
        ),
      );
      if (clear == true) {
        todo.dueDate = null;
        await widget.todoService.update(todo);
        _load();
      }
    }
  }

  Widget _buildTodoItem(Todo todo, ThemeData theme) {
    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: AppColors.white),
      ),
      onDismissed: (_) => _deleteTodo(todo),
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (_) => _toggleComplete(todo),
          shape: const CircleBorder(),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? AppColors.grey500 : null,
          ),
        ),
        subtitle: todo.dueDate != null
            ? Text(
                todo.dueDateDisplay!,
                style: TextStyle(
                  fontSize: 12,
                  color: todo.isOverdue ? AppColors.error : AppColors.grey500,
                  fontWeight: todo.isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              )
            : null,
        trailing: IconButton(
          icon: Icon(Icons.close, size: 18, color: AppColors.grey400),
          onPressed: () => _deleteTodo(todo),
        ),
        onLongPress: () => _pickDueDate(todo),
      ),
    );
  }
}
