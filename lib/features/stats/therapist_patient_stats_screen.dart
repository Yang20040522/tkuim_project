// lib/features/stats/therapist_patient_stats_screen.dart
//
// 治療師查看「指定病患」的數據頁。
//
// 重用病患端數據頁那 5 張卡片(週摘要 / 雷達 / 進步軌跡 / 徽章 / 個人紀錄),
// 差別只在資料來源:病患端讀本機 HistoryService,這裡改讀後端某個病患的
// training_history。做法是用一個唯讀的 RemoteHistoryRepository 包成
// HistoryService.readOnly(...),再透過 Provider 覆蓋,卡片就會自動改讀這個
// 病患的雲端資料 —— 那 5 張卡片本身一行都不用改。
//
// 資料只在進頁時抓一次(RemoteHistoryRepository 內部有快取),頁面層自己
// 處理載入中 / 失敗重試 / 沒有紀錄的狀態。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_colors.dart';
import '../account/app_session.dart';
import '../../models/training_action.dart';
import '../../services/history_service.dart';
import '../../services/history_repository.dart';
import 'week_summary_card.dart';
import 'radar_chart_card.dart';
import 'progress_trend_card.dart';
import 'badges_card.dart';
import 'personal_records_card.dart';
import 'patient_training_videos_card.dart';

class TherapistPatientStatsScreen extends StatefulWidget {
  const TherapistPatientStatsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  @override
  State<TherapistPatientStatsScreen> createState() =>
      _TherapistPatientStatsScreenState();
}

class _TherapistPatientStatsScreenState
    extends State<TherapistPatientStatsScreen> {
  late final RemoteHistoryRepository _repository;
  late final HistoryService _service;
  late Future<List<TrainingRecord>> _future;

  @override
  void initState() {
    super.initState();
    final id = int.tryParse(widget.patientId) ?? -1;
    _repository = RemoteHistoryRepository(
      userId: id,
      viewerUserId: int.tryParse(AppSession.userId ?? ''),
      identityToken: AppSession.customExerciseToken,
    );
    _service = HistoryService.readOnly(_repository);
    // 先抓一次,驅動頁面層的載入 / 失敗 / 空狀態;卡片之後讀的是同一個
    // repository 的快取,不會再打第二次網路。
    _future = _repository.getHistory();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _future = _repository.getHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('${widget.patientName} 的數據'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
      ),
      body: FutureBuilder<List<TrainingRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              message: '讀取病患數據失敗\n請確認網路連線',
              actionLabel: '重試',
              onAction: _retry,
            );
          }

          final records = snapshot.data ?? const [];
          if (records.isEmpty) {
            return const _Message(
              icon: Icons.bar_chart_outlined,
              message: '這位病患目前沒有已上傳的訓練紀錄',
            );
          }

          // 有資料:用 Provider 覆蓋成「讀這個病患雲端資料」的 service,
          // 底下的卡片會自動改讀它。
          return ChangeNotifierProvider<HistoryService>.value(
            value: _service,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WeekSummaryCard(),
                  const SizedBox(height: 12),
                  const RadarChartCard(),
                  const SizedBox(height: 12),
                  const ProgressTrendCard(),
                  const SizedBox(height: 12),
                  const BadgesCard(),
                  const SizedBox(height: 12),
                  const PersonalRecordsCard(),
                  const SizedBox(height: 12),
                  PatientTrainingVideosCard(
                    records: records,
                    httpHeaders: {
                      if (AppSession.userId?.trim().isNotEmpty == true)
                        'X-User-Id': AppSession.userId!.trim(),
                      if (AppSession.customExerciseToken?.trim().isNotEmpty ==
                          true)
                        'X-Custom-Exercise-Token':
                            AppSession.customExerciseToken!.trim(),
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
