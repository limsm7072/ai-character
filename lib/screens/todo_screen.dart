import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../services/todo_service.dart';

class TodoScreen extends StatefulWidget {
  final TodoService todoService;

  const TodoScreen({super.key, required this.todoService});

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
        appBar: AppBar(title: const Text('할 일')),
        body: Column(
          children: [
            Expanded(
              child: _todos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            '할 일을 추가해보세요!',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
                                color: Colors.grey[600],
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
                    color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildTodoItem(Todo todo, ThemeData theme) {
    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
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
            color: todo.isCompleted ? Colors.grey : null,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
          onPressed: () => _deleteTodo(todo),
        ),
      ),
    );
  }
}
