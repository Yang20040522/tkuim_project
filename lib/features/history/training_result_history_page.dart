import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';
import '../../models/training_session_result.dart';
import '../pose_measurement/repositories/training_result_repository.dart';
import '../pose_measurement/repositories/training_result_repository_selection.dart';

class TrainingResultHistoryPage extends StatefulWidget {
  const TrainingResultHistoryPage({
    super.key,
    this.patientId,
    this.patientName,
    this.repository,
  });

  final String? patientId;
  final String? patientName;
  final TrainingResultRepository? repository;

  @override
  State<TrainingResultHistoryPage> createState() =>
      _TrainingResultHistoryPageState();
}

class _TrainingResultHistoryPageState extends State<TrainingResultHistoryPage> {
  late final TrainingResultRepository _repository;
  late Future<List<TrainingSessionResult>> _results;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? trainingResultRepository;
    _reload();
  }

  void _reload() {
    _results = widget.patientId == null
        ? _repository.getMyResults()
        : _repository.getPatientResults(widget.patientId!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(widget.patientName == null
            ? '姿勢訓練紀錄'
            : '${widget.patientName}的訓練紀錄'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: FutureBuilder<List<TrainingSessionResult>>(
        future: _results,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message(
              message: '讀取訓練紀錄失敗',
              action: () => setState(_reload),
            );
          }
          final results = snapshot.data ?? const [];
          if (results.isEmpty) {
            return const _Message(message: '尚無已完成的姿勢訓練紀錄');
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              key: const Key('training-result-history-list'),
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _ResultCard(result: results[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final TrainingSessionResult result;

  @override
  Widget build(BuildContext context) {
    String two(int value) => value.toString().padLeft(2, '0');
    final completed = result.completedAt.toLocal();
    final time =
        '${completed.year}/${two(completed.month)}/${two(completed.day)} '
        '${two(completed.hour)}:${two(completed.minute)}';
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: ListTile(
        key: Key('training-result-${result.sessionId}'),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          foregroundColor: Color(0xFF2E7D32),
          child: Icon(Icons.check),
        ),
        title: Text(
          result.exerciseName,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '$time\n完成 ${result.completedReps} 次／${result.completedSets} 組',
          style: const TextStyle(color: AppColors.secondaryText),
        ),
        isThreeLine: true,
        trailing: Text(
          '${result.score.toStringAsFixed(0)} 分',
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.action});

  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 10),
            Text(message),
            if (action != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(onPressed: action, child: const Text('重試')),
            ],
          ],
        ),
      );
}
