import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/subtask.dart';
import '../theme/app_colors.dart';

/// Inline checklist editor used by the task dialog. Manages an ordered
/// list of [Subtask]s and reports changes via [onChanged].
class SubtaskEditor extends StatefulWidget {
  const SubtaskEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final List<Subtask> initial;
  final ValueChanged<List<Subtask>> onChanged;

  @override
  State<SubtaskEditor> createState() => _SubtaskEditorState();
}

class _SubtaskEditorState extends State<SubtaskEditor> {
  late final List<Subtask> _subtasks = List.of(widget.initial);
  final TextEditingController _controller = TextEditingController();

  /// Index of the subtask currently being edited inline, or null.
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocus = FocusNode();

  void _emit() => widget.onChanged(List.unmodifiable(_subtasks));

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(Subtask(title: text));
      _controller.clear();
    });
    _emit();
  }

  void _toggle(int index) {
    setState(() {
      _subtasks[index] =
          _subtasks[index].copyWith(isCompleted: !_subtasks[index].isCompleted);
    });
    _emit();
  }

  void _remove(int index) {
    setState(() => _subtasks.removeAt(index));
    _emit();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _subtasks.length) return;
    setState(() {
      final item = _subtasks.removeAt(index);
      _subtasks.insert(target, item);
    });
    _emit();
  }

  void _startEditing(int index) {
    setState(() {
      _editingIndex = index;
      _editController.text = _subtasks[index].title;
    });
    _editFocus.requestFocus();
    _editController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _editController.text.length,
    );
  }

  void _saveEdit() {
    if (_editingIndex == null) return;
    final text = _editController.text.trim();
    if (text.isEmpty) {
      // Empty title — just cancel the edit.
      _cancelEdit();
      return;
    }
    final idx = _editingIndex!;
    setState(() {
      _subtasks[idx] = _subtasks[idx].copyWith(title: text);
      _editingIndex = null;
    });
    _emit();
  }

  void _cancelEdit() {
    setState(() => _editingIndex = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    _editController.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            hintText: 'Add a subtask and press Enter',
            prefixIcon: const Icon(Icons.add_task_outlined, size: 20),
            isDense: true,
          ),
        ),
        if (_subtasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...List.generate(_subtasks.length, (index) {
            final subtask = _subtasks[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      subtask.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: subtask.isCompleted
                          ? const Color(0xFF10B981)
                          : colors.textTertiary,
                    ),
                    onPressed: () => _toggle(index),
                  ),
                  Expanded(
                    child: _editingIndex == index
                        ? Focus(
                            onKeyEvent: (node, event) {
                              if (event is! KeyDownEvent) return KeyEventResult.ignored;
                              if (event.logicalKey == LogicalKeyboardKey.escape) {
                                _cancelEdit();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              controller: _editController,
                              focusNode: _editFocus,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 4),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _saveEdit(),
                              onTapOutside: (_) => _saveEdit(),
                            ),
                          )
                        : GestureDetector(
                            onTap: () => _startEditing(index),
                            child: Text(
                              subtask.title,
                              style: TextStyle(
                                fontSize: 13,
                                color: subtask.isCompleted
                                    ? colors.textTertiary
                                    : colors.textPrimary,
                                decoration: subtask.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.arrow_upward,
                        size: 14, color: colors.textTertiary),
                    onPressed: () => _move(index, -1),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.arrow_downward,
                        size: 14, color: colors.textTertiary),
                    onPressed: () => _move(index, 1),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.edit,
                        size: 14, color: colors.textTertiary),
                    tooltip: 'Edit subtask',
                    onPressed: () => _startEditing(index),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close,
                        size: 16, color: colors.textTertiary),
                    onPressed: () => _remove(index),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
