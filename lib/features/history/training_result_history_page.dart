import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';
import '../../models/training_action.dart';
import '../../models/training_session_result.dart';
import '../../services/exercise_api_service.dart';

import '../account/app_session.dart';
import '../pose_measurement/repositories/training_result_repository.dart';
import '../pose_measurement/repositories/training_result_repository_selection.dart';

import 'network_video_playback_screen.dart';

class TrainingResultHistoryPage extends StatefulWidget {
  const TrainingResultHistoryPage({
    super.key,
    this.patientId,
    this.patientName,
    this.repository,
  });

  /// null：
  /// 病患自己查看原本的「姿勢訓練紀錄」
  ///
  /// 有值：
  /// 治療師查看指定患者的 training_history
  final String? patientId;

  final String? patientName;

  /// 保留原本 repository，
  /// 避免既有頁面與 widget test 被破壞。
  final TrainingResultRepository? repository;

  bool get isTherapistPatientMode =>
      patientId != null && patientId!.trim().isNotEmpty;

  @override
  State<TrainingResultHistoryPage> createState() =>
      _TrainingResultHistoryPageState();
}

class _TrainingResultHistoryPageState
    extends State<TrainingResultHistoryPage> {
  late final TrainingResultRepository _repository;

  Future<List<TrainingSessionResult>>? _legacyResults;

  Future<List<TrainingRecord>>? _patientHistory;

  @override
  void initState() {
    super.initState();

    _repository =
        widget.repository ?? trainingResultRepository;

    _reload();
  }

  void _reload() {
    if (widget.isTherapistPatientMode) {
      _patientHistory = _loadPatientHistory();
    } else {
      _legacyResults = _repository.getMyResults();
    }
  }

  // ═════════════════════════════════════════════════════════════
  // 治療師查看指定患者 training_history
  // ═════════════════════════════════════════════════════════════

  Future<List<TrainingRecord>> _loadPatientHistory() async {
    final patientId =
        int.tryParse(widget.patientId ?? '');

    if (patientId == null) {
      throw Exception('患者 ID 格式錯誤');
    }

    final requesterUserId =
        int.tryParse(AppSession.userId ?? '');

    final rows =
        await ExerciseApiService.fetchTrainingHistory(
      userId: patientId,
      requesterUserId: requesterUserId,
      identityToken:
          AppSession.customExerciseToken,
    );

    return rows
        .map(
          (row) => TrainingRecord.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<void> _refreshPatientHistory() async {
    setState(() {
      _patientHistory = _loadPatientHistory();
    });

    await _patientHistory;
  }

  // ═════════════════════════════════════════════════════════════
  // 治療師端：自動升級歷史分組
  // ═════════════════════════════════════════════════════════════
  //
  // 只有 auto: sessionId 才合併。
  // manual: 與舊資料都維持單筆，避免把手動升級誤合併。

  DateTime _recordTime(TrainingRecord record) {
    return DateTime.tryParse(record.timestamp) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _groupLatestTime(
    List<TrainingRecord> group,
  ) {
    if (group.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime latest =
        _recordTime(group.first);

    for (final record in group.skip(1)) {
      final time = _recordTime(record);

      if (time.isAfter(latest)) {
        latest = time;
      }
    }

    return latest;
  }

  List<List<TrainingRecord>> _groupPatientRecords(
    List<TrainingRecord> records,
  ) {
    if (records.isEmpty) {
      return <List<TrainingRecord>>[];
    }

    final autoGroups =
        <String, List<TrainingRecord>>{};

    final singles =
        <List<TrainingRecord>>[];

    for (final record in records) {
      final sessionId =
          record.sessionId?.trim();

      if (sessionId != null &&
          sessionId.startsWith('auto:')) {
        final key =
            '$sessionId|${record.actionName}';

        autoGroups
            .putIfAbsent(
              key,
              () => <TrainingRecord>[],
            )
            .add(record);
      } else {
        singles.add(
          <TrainingRecord>[record],
        );
      }
    }

    final groups =
        <List<TrainingRecord>>[
      ...autoGroups.values,
      ...singles,
    ];

    for (final group in groups) {
      group.sort(
        (a, b) {
          final level =
              a.difficulty.compareTo(
            b.difficulty,
          );

          if (level != 0) {
            return level;
          }

          return _recordTime(a).compareTo(
            _recordTime(b),
          );
        },
      );
    }

    groups.sort(
      (a, b) => _groupLatestTime(b)
          .compareTo(
            _groupLatestTime(a),
          ),
    );

    return groups;
  }

  bool _isAutoUpgradeGroup(
    List<TrainingRecord> group,
  ) {
    if (group.length < 2) {
      return false;
    }

    final sessionId =
        group.first.sessionId?.trim();

    if (sessionId == null ||
        !sessionId.startsWith('auto:')) {
      return false;
    }

    if (!group.every(
      (record) =>
          record.sessionId?.trim() ==
          sessionId,
    )) {
      return false;
    }

    final levels = group
        .map((record) => record.difficulty)
        .toSet()
        .toList()
      ..sort();

    if (levels.length < 2) {
      return false;
    }

    for (int i = 1;
        i < levels.length;
        i++) {
      if (levels[i] !=
          levels[i - 1] + 1) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isTherapistPatientMode) {
      return _buildTherapistPatientHistory();
    }

    return _buildLegacyHistory();
  }

  // ═════════════════════════════════════════════════════════════
  // 治療師患者歷史
  // ═════════════════════════════════════════════════════════════

  Widget _buildTherapistPatientHistory() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        title: Text(
          widget.patientName == null ||
                  widget.patientName!.trim().isEmpty
              ? '患者訓練紀錄'
              : '${widget.patientName}的訓練紀錄',
        ),
        backgroundColor: Colors.white,
        foregroundColor:
            const Color(0xFF1A1D2E),
        elevation: 0,
      ),

      body: FutureBuilder<List<TrainingRecord>>(
        future: _patientHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _Message(
              message:
                  '讀取患者訓練紀錄失敗\n${snapshot.error}',
              action: () {
                setState(() {
                  _patientHistory =
                      _loadPatientHistory();
                });
              },
            );
          }

          final records =
              snapshot.data ??
              const <TrainingRecord>[];

          if (records.isEmpty) {
            return const _Message(
              message:
                  '患者目前沒有已上傳的訓練紀錄',
            );
          }

          final groups =
              _groupPatientRecords(records);

          return RefreshIndicator(
            onRefresh: _refreshPatientHistory,

            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                30,
              ),

              children: [
                _buildHistoryTitle(
                  groups.length,
                ),

                const SizedBox(height: 14),

                ...groups.map(
                  (group) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 14,
                    ),
                    child:
                        _isAutoUpgradeGroup(group)
                            ? _TherapistAutoUpgradeCard(
                                records: group,
                              )
                            : _TherapistHistoryCard(
                                record: group.first,
                              ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTitle(int count) {
    return Row(
      children: [
        const Text(
          '歷史詳細紀錄',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(width: 8),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),

          decoration: BoxDecoration(
            color: const Color(0xFFE2E6FF),
            borderRadius:
                BorderRadius.circular(10),
          ),

          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF4A65FF),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════
  // 原本病患姿勢訓練紀錄
  // 完全保留原本行為
  // ═════════════════════════════════════════════════════════════

  Widget _buildLegacyHistory() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      appBar: AppBar(
        title: const Text('姿勢訓練紀錄'),
        backgroundColor: Colors.white,
        foregroundColor:
            const Color(0xFF1A1D2E),
      ),

      body:
          FutureBuilder<List<TrainingSessionResult>>(
        future: _legacyResults,

        builder: (_, snapshot) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _Message(
              message: '讀取訓練紀錄失敗',
              action: () {
                setState(() {
                  _legacyResults =
                      _repository.getMyResults();
                });
              },
            );
          }

          final results =
              snapshot.data ??
              const <TrainingSessionResult>[];

          if (results.isEmpty) {
            return const _Message(
              message:
                  '尚無已完成的姿勢訓練紀錄',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _legacyResults =
                    _repository.getMyResults();
              });

              await _legacyResults;
            },

            child: ListView.separated(
              key: const Key(
                'training-result-history-list',
              ),

              padding:
                  const EdgeInsets.all(16),

              itemCount: results.length,

              separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),

              itemBuilder: (_, index) =>
                  _ResultCard(
                result: results[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 治療師看到的自由訓練歷史卡片
// ═══════════════════════════════════════════════════════════════

class _TherapistHistoryCard
    extends StatelessWidget {
  const _TherapistHistoryCard({
    required this.record,
  });

  final TrainingRecord record;

  @override
  Widget build(BuildContext context) {
    final mistakeCount =
        record.mistakeLogs.length;

    final hasMistakes =
        mistakeCount > 0;

    final completed =
        record.completedReps < 0
            ? 0
            : record.completedReps;

    final target =
        record.targetReps < 0
            ? 0
            : record.targetReps;

    final minutes =
        record.durationSeconds ~/ 60;

    final seconds =
        record.durationSeconds % 60;

    final videoUrl =
        record.videoUrl?.trim();

    final hasNetworkVideo =
        videoUrl != null &&
        videoUrl.isNotEmpty;

    return Container(
      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color:
              const Color(0xFFD9DDF2),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // 左側完成次數方塊
              Container(
                width: 64,
                height: 64,

                alignment:
                    Alignment.center,

                decoration:
                    BoxDecoration(
                  color: hasMistakes
                      ? const Color(
                          0xFFFFE1E5,
                        )
                      : const Color(
                          0xFFE0F2E7,
                        ),

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child: Text(
                  '$completed',

                  style: TextStyle(
                    color: hasMistakes
                        ? const Color(
                            0xFFFF4B4B,
                          )
                        : const Color(
                            0xFF35A853,
                          ),

                    fontSize: 26,

                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // 中間資料
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      record.actionName,

                      maxLines: 1,

                      overflow:
                          TextOverflow
                              .ellipsis,

                      style:
                          const TextStyle(
                        color: AppColors
                            .primaryText,

                        fontSize: 17,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      '${record.timestamp}'
                      '  •  Lv.${record.difficulty}'
                      '  •  '
                      '$minutes:${seconds.toString().padLeft(2, '0')}',

                      style:
                          const TextStyle(
                        color:
                            Color(0xFF73798C),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 右側失誤 + 次數
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,

                children: [
                  Text(
                    hasMistakes
                        ? '❌ $mistakeCount 次失誤'
                        : '✅ 完美',

                    style: TextStyle(
                      color: hasMistakes
                          ? const Color(
                              0xFFFF4B4B,
                            )
                          : const Color(
                              0xFF4CAF50,
                            ),

                      fontSize: 13,

                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    '$completed / $target',

                    style:
                        const TextStyle(
                      color: AppColors
                          .secondaryText,

                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ─────────────────────────────────────────────────
          // 治療師只有播放，不提供「分析錄影」
          // ─────────────────────────────────────────────────

          if (hasNetworkVideo) ...[
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,

              child: OutlinedButton.icon(
                key: Key(
                  'therapist-play-video-${record.id ?? record.timestamp}',
                ),

                onPressed: () {
                  final requesterId =
                      int.tryParse(
                    AppSession.userId ?? '',
                  );

                  final token =
                      AppSession
                          .customExerciseToken;

                  final headers =
                      <String, String>{
                    if (requesterId != null)
                      'X-User-Id':
                          '$requesterId',

                    if (token != null &&
                        token
                            .trim()
                            .isNotEmpty)
                      'X-Custom-Exercise-Token':
                          token.trim(),
                  };

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          NetworkVideoPlaybackScreen(
                        videoUrl: videoUrl,
                        title:
                            '${record.actionName} · ${record.timestamp}',

                        // ✅ 最新 NetworkVideoPlaybackScreen
                        // 只有 httpHeaders
                        httpHeaders: headers,
                      ),
                    ),
                  );
                },

                icon: const Icon(
                  Icons
                      .play_circle_outline,
                  size: 20,
                ),

                label:
                    const Text(
                  '播放錄影',
                ),

                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(
                    0xFF4A65FF,
                  ),

                  side:
                      const BorderSide(
                    color:
                        Color(
                      0xFF9DAAFF,
                    ),
                  ),

                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 12,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),

            Container(
              width: double.infinity,

              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 10,
              ),

              alignment:
                  Alignment.center,

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF0F1F5,
                ),

                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),

              child:
                  const Text(
                '此筆紀錄沒有錄影',

                style:
                    TextStyle(
                  color:
                      Color(
                    0xFF8A8F9E,
                  ),

                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 治療師看到的「自動升級」群組卡片
//
// 只提供播放錄影，不提供分析錄影。
// ═══════════════════════════════════════════════════════════════

class _TherapistAutoUpgradeCard
    extends StatelessWidget {
  const _TherapistAutoUpgradeCard({
    required this.records,
  });

  final List<TrainingRecord> records;

  @override
  Widget build(BuildContext context) {
    final sorted =
        List<TrainingRecord>.from(records)
          ..sort(
            (a, b) =>
                a.difficulty.compareTo(
              b.difficulty,
            ),
          );

    final first = sorted.first;

    final levels = sorted
        .map((record) => record.difficulty)
        .toSet()
        .toList()
      ..sort();

    final firstLevel = levels.first;
    final lastLevel = levels.last;

    final totalMistakes = sorted.fold<int>(
      0,
      (sum, record) =>
          sum + record.mistakeLogs.length,
    );

    final allComplete = sorted.every(
      (record) =>
          record.targetReps > 0 &&
          record.completedReps >=
              record.targetReps,
    );

    TrainingRecord? videoRecord;

    for (final record in sorted) {
      final url = record.videoUrl?.trim();

      if (url != null && url.isNotEmpty) {
        videoRecord = record;
        break;
      }
    }

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD9DDF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFE2E6FF),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      '${sorted.length}',
                      style: const TextStyle(
                        color:
                            Color(0xFF4A65FF),
                        fontSize: 24,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const Text(
                      '階',
                      style: TextStyle(
                        color:
                            Color(0xFF4A65FF),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      first.actionName,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:
                            AppColors.primaryText,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      first.timestamp,
                      style: const TextStyle(
                        color:
                            Color(0xFF73798C),
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '自動升級 · '
                      'Lv.$firstLevel → Lv.$lastLevel',
                      style: const TextStyle(
                        color:
                            Color(0xFF4A65FF),
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    allComplete
                        ? '✅ 完成'
                        : '尚未完成',
                    style: TextStyle(
                      color: allComplete
                          ? const Color(
                              0xFF4CAF50,
                            )
                          : const Color(
                              0xFFFF4B4B,
                            ),
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    totalMistakes == 0
                        ? '0 次失誤'
                        : '$totalMistakes 次失誤',
                    style: const TextStyle(
                      color:
                          AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 同一場自動升級影片只顯示一個播放按鈕。
          if (videoRecord != null) ...[
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key(
                  'therapist-play-session-'
                  '${first.sessionId ?? first.timestamp}',
                ),
                onPressed: () {
                  final requesterId =
                      int.tryParse(
                    AppSession.userId ?? '',
                  );

                  final token =
                      AppSession
                          .customExerciseToken;

                  final headers =
                      <String, String>{
                    if (requesterId != null)
                      'X-User-Id':
                          '$requesterId',
                    if (token != null &&
                        token
                            .trim()
                            .isNotEmpty)
                      'X-Custom-Exercise-Token':
                          token.trim(),
                  };

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          NetworkVideoPlaybackScreen(
                        videoUrl:
                            videoRecord!.videoUrl!,
                        title:
                            '${first.actionName} · '
                            '${first.timestamp}',
                        httpHeaders: headers,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.play_circle_outline,
                  size: 20,
                ),
                label:
                    const Text('播放錄影'),
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(
                    0xFF4A65FF,
                  ),
                  side: const BorderSide(
                    color:
                        Color(0xFF9DAAFF),
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                vertical: 10,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFF0F1F5),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Text(
                '此場訓練沒有已上傳錄影',
                style: TextStyle(
                  color:
                      Color(0xFF8A8F9E),
                  fontSize: 12,
                ),
              ),
            ),
          ],

          Theme(
            data: Theme.of(context).copyWith(
              dividerColor:
                  Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding:
                  const EdgeInsets.only(
                bottom: 6,
              ),
              title: const Text(
                '查看各難度結果',
                style: TextStyle(
                  color:
                      Color(0xFF4A65FF),
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${sorted.length} 個難度紀錄',
                style: const TextStyle(
                  color:
                      AppColors.secondaryText,
                  fontSize: 11,
                ),
              ),
              children: [
                for (int i = 0;
                    i < sorted.length;
                    i++) ...[
                  _TherapistLevelResultRow(
                    record: sorted[i],
                  ),
                  if (i !=
                      sorted.length - 1)
                    const Divider(
                      height: 18,
                      color:
                          Color(0xFFDDE0F0),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TherapistLevelResultRow
    extends StatelessWidget {
  const _TherapistLevelResultRow({
    required this.record,
  });

  final TrainingRecord record;

  @override
  Widget build(BuildContext context) {
    final completed =
        record.completedReps < 0
            ? 0
            : record.completedReps;

    final target =
        record.targetReps < 0
            ? 0
            : record.targetReps;

    final minutes =
        record.durationSeconds ~/ 60;

    final seconds =
        record.durationSeconds % 60;

    final mistakes =
        record.mistakeLogs;

    final isComplete =
        target > 0 &&
        completed >= target;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFE2E6FF),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Text(
                  'Lv.${record.difficulty}',
                  style: const TextStyle(
                    color:
                        Color(0xFF4A65FF),
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  '$completed / $target 次'
                  '  •  '
                  '$minutes:'
                  '${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color:
                        Color(0xFF374151),
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),

              Text(
                !isComplete
                    ? '尚未完成'
                    : mistakes.isEmpty
                        ? '✅ 完美'
                        : '❌ '
                            '${mistakes.length} '
                            '次失誤',
                style: TextStyle(
                  color: isComplete &&
                          mistakes.isEmpty
                      ? const Color(
                          0xFF4CAF50,
                        )
                      : const Color(
                          0xFFFF4B4B,
                        ),
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          if (mistakes.isNotEmpty) ...[
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    const Color(0xFFFFF5F5),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: mistakes
                    .map(
                      (log) => Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 3,
                        ),
                        child: Text(
                          '• $log',
                          style:
                              const TextStyle(
                            color:
                                Color(0xFF9B4D4D),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 原本姿勢訓練卡片
// ═══════════════════════════════════════════════════════════════

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
  });

  final TrainingSessionResult result;

  @override
  Widget build(BuildContext context) {
    String two(int value) =>
        value
            .toString()
            .padLeft(2, '0');

    final completed =
        result.completedAt.toLocal();

    final time =
        '${completed.year}/'
        '${two(completed.month)}/'
        '${two(completed.day)} '
        '${two(completed.hour)}:'
        '${two(completed.minute)}';

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,

      child: ListTile(
        key: Key(
          'training-result-${result.sessionId}',
        ),

        leading:
            const CircleAvatar(
          backgroundColor:
              Color(0xFFE8F5E9),

          foregroundColor:
              Color(0xFF2E7D32),

          child:
              Icon(Icons.check),
        ),

        title: Text(
          result.exerciseName,

          style:
              const TextStyle(
            color:
                AppColors.primaryText,

            fontWeight:
                FontWeight.w800,
          ),
        ),

        subtitle: Text(
          '$time\n'
          '完成 ${result.completedReps} 次／'
          '${result.completedSets} 組',

          style:
              const TextStyle(
            color:
                AppColors.secondaryText,
          ),
        ),

        isThreeLine: true,

        trailing: Text(
          '${result.score.toStringAsFixed(0)} 分',

          style:
              const TextStyle(
            color:
                Color(0xFF2E7D32),

            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 共用訊息畫面
// ═══════════════════════════════════════════════════════════════

class _Message extends StatelessWidget {
  const _Message({
    required this.message,
    this.action,
  });

  final String message;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            const Icon(
              Icons.history,
              size: 48,
              color:
                  Color(0xFF9CA3AF),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              message,
              textAlign:
                  TextAlign.center,
            ),

            if (action != null) ...[
              const SizedBox(
                height: 10,
              ),

              OutlinedButton(
                onPressed: action,
                child:
                    const Text(
                  '重試',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}