import 'package:flutter/material.dart';

import '../../models/custom_rehab_exercise.dart';
import 'repositories/custom_exercise_repository.dart';
import 'repositories/local_custom_exercise_repository.dart';

typedef CustomExerciseEditorBuilder = Widget Function(
  CustomRehabExercise? exercise,
  CustomExerciseRepository repository,
);

class CustomExerciseListPage extends StatefulWidget {
  final CustomExerciseRepository? repository;
  final CustomExerciseEditorBuilder editorBuilder;

  const CustomExerciseListPage({
    super.key,
    this.repository,
    required this.editorBuilder,
  });

  @override
  State<CustomExerciseListPage> createState() => _CustomExerciseListPageState();
}

class _CustomExerciseListPageState extends State<CustomExerciseListPage> {
  late final CustomExerciseRepository _repository;
  late Future<List<CustomRehabExercise>> _exercises;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? customExerciseRepository;
    _exercises = _repository.getAllExercises();
  }

  void _reload() {
    setState(() {
      _exercises = _repository.getAllExercises();
    });
  }

  Future<void> _openEditor(CustomRehabExercise? exercise) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.editorBuilder(exercise, _repository),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _deleteExercise(CustomRehabExercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除自訂動作'),
        content: Text('確定要刪除「${exercise.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-delete-custom-exercise'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE24B4A),
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository.deleteExercise(exercise.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已刪除自訂動作')),
      );
      _reload();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('已儲存自訂動作'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create-custom-exercise-from-list'),
        onPressed: () => _openEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('建立動作'),
      ),
      body: FutureBuilder<List<CustomRehabExercise>>(
        future: _exercises,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ListMessage(
              icon: Icons.error_outline,
              message: '讀取已儲存動作失敗',
              actionLabel: '重試',
              onAction: _reload,
            );
          }

          final exercises = snapshot.data ?? const [];
          if (exercises.isEmpty) {
            return _ListMessage(
              icon: Icons.folder_open,
              message: '尚未儲存自訂動作',
              actionLabel: '建立第一個動作',
              onAction: () => _openEditor(null),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
              itemCount: exercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return _ExerciseCard(
                  exercise: exercise,
                  onOpen: () => _openEditor(exercise),
                  onDelete: () => _deleteExercise(exercise),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final CustomRehabExercise exercise;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ExerciseCard({
    required this.exercise,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('saved-exercise-${exercise.id}'),
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.name,
              style: const TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (exercise.description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                exercise.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Metadata(
                  icon: Icons.timer_outlined,
                  text: '${exercise.duration.toStringAsFixed(1)} 秒',
                ),
                _Metadata(
                  icon: Icons.timeline,
                  text: '${exercise.keyframes.length} Keyframes',
                ),
                _Metadata(
                  icon: Icons.update,
                  text: _formatDateTime(exercise.updatedAt),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  key: Key('delete-saved-exercise-${exercise.id}'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE24B4A),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: Key('open-saved-exercise-${exercise.id}'),
                  onPressed: onOpen,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('開啟'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _Metadata extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Metadata({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6B7280)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
      ],
    );
  }
}

class _ListMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _ListMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
