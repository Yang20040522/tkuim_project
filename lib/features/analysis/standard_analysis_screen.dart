// lib/features/demo/standard_analysis_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  動作標準分析
//
//  功能:
//    ✅ 內建預設影片 + 使用者自選影片
//    ✅ 逐幀骨架偵測(RTMPose 全身 133 點)
//    ✅ 多維度特徵萃取(主要關節、對稱性、穩定性、動作次數)
//    ✅ 儲存為 JSON 模板(給未來病人動作比對用)
// ══════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../account/app_session.dart';
import '../account/user_role.dart';
import 'body/body_motion_template.dart';
import 'hand/hand_motion_template.dart';
import 'models/environment_metadata.dart';
import 'models/video_segment.dart';
import 'motion_feature_extractor.dart';
import 'storage/local_motion_template_repository.dart';
import 'hand_analysis_service.dart';
import 'hand_feature_extractor.dart';
import 'video_analysis_service.dart';
import 'widgets/video_segment_selector.dart';

class StandardAnalysisScreen extends StatefulWidget {
  const StandardAnalysisScreen({super.key});

  @override
  State<StandardAnalysisScreen> createState() => _StandardAnalysisScreenState();
}

class _StandardAnalysisScreenState extends State<StandardAnalysisScreen> {
  final LocalMotionTemplateRepository _templateRepository =
      LocalMotionTemplateRepository();

  // ── 預設影片清單 ──
  static const List<Map<String, String>> _presetVideos = [
    {
      'name': '站姿抬腳(示範)',
      'actionType': '站姿抬腳',
      'assetPath': 'assets/preset_videos/standing_knee_raise_demo.mp4',
    },
    // 未來擴充加在這裡
  ];

  // ── 選擇狀態 ──
  String? _selectedVideoPath;
  String _currentActionType = '';
  bool _isPreset = false; // 是否為內建影片
  bool _isAnalyzing = false;
  VideoSegment? _selectedSegment;

  CameraView _cameraView = CameraView.front;
  SupportType _supportType = SupportType.none;
  BodySide _supportSide = BodySide.none;
  BodySide _movementSide = BodySide.none;

  // ── 分析類型(全身 / 手部) ──
  String _analysisType = 'body'; // 'body' 或 'hand'

  // ── 手部分析結果(如果是手部) ──
  HandAnalysisResult? _handResult;
  HandVideoAnalysisResult? _handVideoAnalysis;
  BodyVideoAnalysisResult? _bodyVideoAnalysis;

  // ── 使用者輸入動作名稱 ──
  final TextEditingController _actionNameController = TextEditingController();

  // ── 分析進度 ──
  int _totalFrames = 0;
  int _processedFrames = 0;
  int _framesWithPose = 0;

  // ── 多維度分析資料 ──
  final List<List<Offset>> _framePoses = [];
  final List<List<double>> _frameScores = [];
  // ── 分析結果 ──
  List<int> _mainJointIndices = [];
  Map<int, double> _jointTotalMovement = {};
  int _estimatedReps = 0;
  double _symmetryScore = 0;
  double _stabilityScore = 0;

  @override
  void dispose() {
    _actionNameController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  //  1. 選影片來源
  // ═══════════════════════════════════════════════════════════════

  void _showVideoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '選擇影片來源',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading:
                    const Icon(Icons.video_library, color: Color(0xFF4A65FF)),
                title: const Text('內建示範影片'),
                subtitle: Text('${_presetVideos.length} 支可選'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPresetVideoPicker();
                },
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.folder_open, color: Color(0xFF4CAF50)),
                title: const Text('選我的影片'),
                subtitle: const Text('從相簿選擇 + 手動輸入動作名稱'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCustomVideo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPresetVideoPicker() async {
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('選內建示範影片',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ..._presetVideos.map((v) => ListTile(
                    leading: const Icon(Icons.movie, color: Color(0xFF4A65FF)),
                    title: Text(v['name']!),
                    subtitle: Text('動作類型:${v['actionType']}'),
                    onTap: () => Navigator.pop(ctx, v),
                  )),
            ],
          ),
        ),
      ),
    );

    if (picked == null) return;
    final tempPath = await _copyAssetToTemp(picked['assetPath']!);

    setState(() {
      _selectedVideoPath = tempPath;
      _currentActionType = picked['actionType']!;
      _isPreset = true;
      _resetAnalysisState();
    });
  }

  Future<void> _pickCustomVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) return;

    final actionName = await _askActionName();
    if (actionName == null || actionName.isEmpty) return;

    setState(() {
      _selectedVideoPath = result.files.single.path;
      _currentActionType = actionName;
      _isPreset = false;
      _resetAnalysisState();
    });
  }

  Future<String?> _askActionName() async {
    _actionNameController.text = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('這是什麼動作?'),
        content: TextField(
          controller: _actionNameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '例如:站姿抬腳、翻掌、側捏',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, _actionNameController.text.trim()),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  void _resetAnalysisState() {
    _totalFrames = 0;
    _processedFrames = 0;
    _framesWithPose = 0;
    _framePoses.clear();
    _frameScores.clear();
    _mainJointIndices = [];
    _jointTotalMovement = {};
    _estimatedReps = 0;
    _symmetryScore = 0;
    _stabilityScore = 0;
    _selectedSegment = null;
    _bodyVideoAnalysis = null;
    _handVideoAnalysis = null;
    _handResult = null;
  }

  Future<String> _copyAssetToTemp(String assetPath) async {
    final bytes = await DefaultAssetBundle.of(context).load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file.path;
  }

  // ═══════════════════════════════════════════════════════════════
  //  2. 開始分析
  // ═══════════════════════════════════════════════════════════════

  Future<void> _startAnalysis() async {
    if (_selectedVideoPath == null || _selectedSegment == null) return;

    if (_analysisType == 'hand') {
      await _startHandAnalysis();
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _processedFrames = 0;
      _framesWithPose = 0;
      _framePoses.clear();
      _frameScores.clear();
      _bodyVideoAnalysis = null;
    });

    try {
      final segment = _selectedSegment!;
      final analysis = await VideoAnalysisService.analyzeVideoDetailed(
        videoPath: _selectedVideoPath!,
        fps: 2,
        startTime: segment.startTime,
        endTime: segment.endTime,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _processedFrames = (progress * 100).round();
            _totalFrames = 100;
          });
        },
      );

      if (!mounted) return;
      final summary = analysis.summary;
      setState(() {
        _bodyVideoAnalysis = analysis;
        _processedFrames = analysis.attemptedFrameCount;
        _totalFrames = analysis.attemptedFrameCount;
        _framesWithPose = analysis.validFrameCount;
        _framePoses.addAll(analysis.attemptedFrames
            .where((frame) => frame.isValid)
            .map((frame) => frame.landmarks!));
        _frameScores.addAll(analysis.attemptedFrames
            .where((frame) => frame.isValid)
            .map((frame) => frame.scores!));
        if (summary != null) _applyBodySummary(summary);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary == null
              ? '分析完成，但可用骨架幀數不足。'
              : '分析完成:${analysis.attemptedFrameCount} 幀,'
                  '成功偵測 ${analysis.validFrameCount} 幀'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析錯誤:$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  /// 手部影片分析(獨立於全身分析)
  Future<void> _startHandAnalysis() async {
    if (_selectedVideoPath == null || _selectedSegment == null) return;

    setState(() {
      _isAnalyzing = true;
      _processedFrames = 0;
      _framesWithPose = 0;
      _handResult = null;
      _handVideoAnalysis = null;
    });

    try {
      final segment = _selectedSegment!;
      final analysis = await HandAnalysisService.analyzeVideoDetailed(
        videoPath: _selectedVideoPath!,
        fps: 3,
        startTime: segment.startTime,
        endTime: segment.endTime,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _processedFrames = (p * 100).round();
              _totalFrames = 100;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _handVideoAnalysis = analysis;
          _handResult = analysis.summary;
          _processedFrames = analysis.attemptedFrameCount;
          _totalFrames = analysis.attemptedFrameCount;
          _framesWithPose = analysis.validFrameCount;
        });

        if (analysis.summary == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('分析失敗:無法從影片偵測到手部')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('手部分析完成:${analysis.attemptedFrameCount} 幀,'
                  '有效 ${analysis.validFrameCount} 幀,'
                  '${analysis.summary!.estimatedReps} 次動作'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析錯誤:$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _applyBodySummary(MotionAnalysisResult result) {
    _mainJointIndices = result.mainJointIndices;
    _jointTotalMovement = result.jointTotalMovement;
    _estimatedReps = result.estimatedReps;
    _symmetryScore = result.symmetryScore;
    _stabilityScore = result.stabilityScore;
  }

  /// 顯示關節名稱(委派)
  String _jointName(int index) => MotionFeatureExtractor.jointName(index);

  // ═══════════════════════════════════════════════════════════════
  //  4. 儲存 JSON 模板
  // ═══════════════════════════════════════════════════════════════

  Future<void> _saveAsTemplate() async {
    // 判斷是否有可儲存的分析結果
    final bool hasBody =
        _analysisType == 'body' && _bodyVideoAnalysis?.summary != null;
    final bool hasHand =
        _analysisType == 'hand' && _handVideoAnalysis?.summary != null;
    if (!hasBody && !hasHand) return;

    // 讓使用者輸入模板名稱
    // 讓使用者輸入模板名稱。
    // 不使用臨時 TextEditingController，避免 Dialog 關閉動畫期間
    // controller 已 dispose 但 TextField 仍在 Widget tree 中。
    final defaultTemplateName = '$_currentActionType 標準模板';
    var pendingTemplateName = defaultTemplateName;

    final saveName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('儲存為模板'),
        content: TextFormField(
          initialValue: defaultTemplateName,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '模板名稱',
          ),
          onChanged: (value) {
            pendingTemplateName = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              pendingTemplateName.trim(),
            ),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (saveName == null || saveName.isEmpty) return;

    try {
      Map<String, dynamic> data;
      final environment = EnvironmentMetadata(
        cameraView: _cameraView,
        supportType: _supportType,
        supportSide: _supportSide,
        movementSide: _movementSide,
      );
      final creatorId = AppSession.role == UserRole.therapist
          ? AppSession.userId?.trim()
          : null;

      if (hasBody) {
        final build = BodyMotionTemplate.build(
          analysis: _bodyVideoAnalysis!,
          templateName: saveName,
          actionType: _currentActionType,
          environment: environment,
          createdByTherapistId: creatorId,
        );
        if (build.template == null) {
          await _showQualityFailure(build.qualitySummary.messages);
          return;
        }
        data = build.template!.toJson();
      } else {
        final build = HandMotionTemplate.build(
          analysis: _handVideoAnalysis!,
          templateName: saveName,
          actionType: _currentActionType,
          environment: environment,
          createdByTherapistId: creatorId,
        );
        if (build.template == null) {
          await _showQualityFailure(build.qualitySummary.messages);
          return;
        }
        data = build.template!.toJson();
      }

      final file = await _templateRepository.saveTemplateJson(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('模板已儲存(${_analysisType == "hand" ? "手部" : "全身"}):'
                '${file.path.split('/').last}'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗:$e')),
        );
      }
    }
  }

  Future<void> _showQualityFailure(List<String> reasons) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('無法建立標準模板'),
        content: Text(reasons.map((reason) => '• $reason').join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('重新選擇區段'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
//  5. 已存模板管理(顯示清單 + 刪除)
// ═══════════════════════════════════════════════════════════════

  Future<void> _showSavedTemplates() async {
    final templates = await _loadAllTemplates();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open, color: Color(0xFF4A65FF)),
                      const SizedBox(width: 8),
                      Text(
                        '已存模板 (${templates.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1D2E),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: templates.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 64, color: Color(0xFF9CA3AF)),
                              SizedBox(height: 12),
                              Text(
                                '尚未儲存任何模板',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: templates.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final t = templates[i];
                            return _buildTemplateCard(t, () async {
                              final ok = await _confirmDelete(
                                  ctx, t['templateName'] ?? '');
                              if (ok == true) {
                                await _deleteTemplate(t['_filePath']);
                                setSheetState(() {
                                  templates.removeAt(i);
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已刪除模板'),
                                      backgroundColor: Color(0xFFF44336),
                                    ),
                                  );
                                }
                              }
                            });
                          },
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 讀取所有 JSON 模板(從手機內部目錄)
  Future<List<Map<String, dynamic>>> _loadAllTemplates() =>
      _templateRepository.listTemplateJson();

  /// 刪除模板檔
  Future<void> _deleteTemplate(String path) =>
      _templateRepository.deleteTemplate(path);

  /// 刪除確認 dialog
  Future<bool?> _confirmDelete(BuildContext ctx, String name) async {
    return showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('確定刪除?'),
        content: Text('將永久刪除模板「$name」,無法復原'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              foregroundColor: Colors.white,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  /// 單一模板卡片
  Widget _buildTemplateCard(Map<String, dynamic> t, VoidCallback onDelete) {
    final name = t['templateName'] ?? '未命名';
    final actionType = t['actionType'] ?? '未知動作';
    final createdAt = t['createdAt'] ?? '';
    final createdShort =
        createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
    final reps = t['estimatedReps'] ?? 0;
    final sym = (t['symmetryScore'] ?? 0.0) as num;
    final sta = (t['stabilityScore'] ?? 0.0) as num;
    final frames = t['totalFrames'] ?? 0;
    final isHand = t['modelType'] == HandMotionTemplate.modelType;
    final sampleCount = t['sampleCount'] ?? 0;
    final regularity = (t['regularityScore'] ?? 0.0) as num;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D2E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$actionType · $createdShort',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFF44336)),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _miniChip('$reps 次', const Color(0xFF4CAF50)),
              if (isHand)
                _miniChip('規律 ${(regularity * 100).toStringAsFixed(0)}%',
                    const Color(0xFF4A65FF))
              else ...[
                _miniChip('對稱 ${(sym * 100).toStringAsFixed(0)}%',
                    const Color(0xFF4A65FF)),
                _miniChip('穩定 ${(sta * 100).toStringAsFixed(0)}%',
                    const Color(0xFFFF9800)),
              ],
              _miniChip('$frames 幀', const Color(0xFF6B7280)),
              if (sampleCount != 0)
                _miniChip('$sampleCount 點模板', const Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEnvironmentMetadataSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '拍攝與動作資訊',
            style: TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metadataDropdown<CameraView>(
                  label: '鏡頭視角',
                  value: _cameraView,
                  values: CameraView.values,
                  valueLabel: (value) => value.label,
                  onChanged: (value) => setState(() => _cameraView = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metadataDropdown<SupportType>(
                  label: '支撐物',
                  value: _supportType,
                  values: SupportType.values,
                  valueLabel: (value) => value.label,
                  onChanged: (value) => setState(() => _supportType = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metadataDropdown<BodySide>(
                  label: '支撐側',
                  value: _supportSide,
                  values: BodySide.values,
                  valueLabel: (value) => value.label,
                  onChanged: (value) => setState(() => _supportSide = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metadataDropdown<BodySide>(
                  label: '動作側',
                  value: _movementSide,
                  values: BodySide.values,
                  valueLabel: (value) => value.label,
                  onChanged: (value) => setState(() => _movementSide = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metadataDropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) valueLabel,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(valueLabel(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _isAnalyzing
          ? null
          : (newValue) {
              if (newValue != null) onChanged(newValue);
            },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  UI
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool hasVideo = _selectedVideoPath != null;
    final String fileName = hasVideo ? _selectedVideoPath!.split('/').last : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('AI 標準模板管理'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '從治療師示範影片建立可驗證的 One-shot 動作模板',
              style: TextStyle(
                  color: Color(0xFF1A1D2E),
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '選擇影片與有效區段，填寫拍攝環境後再進行離線分析。',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),

            // ── 查看已存模板按鈕 ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showSavedTemplates,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('查看已存模板',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A65FF),
                  side: const BorderSide(color: Color(0xFF4A65FF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 選擇分析類型 ──
            const Text(
              '選擇分析類型',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _buildAnalysisTypeCard(
                  type: 'body',
                  icon: Icons.accessibility_new,
                  title: '全身動作',
                  subtitle: 'RTMPose 133 點',
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildAnalysisTypeCard(
                  type: 'hand',
                  icon: Icons.back_hand,
                  title: '手部動作',
                  subtitle: 'MediaPipe 21 點',
                )),
              ],
            ),

            const SizedBox(height: 24),

            // 選影片區塊
            GestureDetector(
              onTap: _isAnalyzing ? null : _showVideoSourcePicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasVideo
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFDDE0F0),
                    width: hasVideo ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      hasVideo ? Icons.check_circle : Icons.video_call_outlined,
                      color: hasVideo
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF9CA3AF),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasVideo ? fileName : '點擊選擇影片',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontWeight:
                            hasVideo ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasVideo) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isPreset
                              ? const Color(0xFFE0E7FF)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_isPreset ? "內建" : "自選"} · $_currentActionType',
                          style: TextStyle(
                            color: _isPreset
                                ? const Color(0xFF4A65FF)
                                : const Color(0xFF2E7D32),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (hasVideo) ...[
              const SizedBox(height: 16),
              VideoSegmentSelector(
                key: ValueKey(_selectedVideoPath),
                videoPath: _selectedVideoPath!,
                enabled: !_isAnalyzing,
                onSegmentChanged: (segment) {
                  if (!mounted) return;
                  if (_selectedSegment == segment) return;
                  setState(() {
                    _resetAnalysisState();
                    _selectedSegment = segment;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildEnvironmentMetadataSection(),
            ],

            const SizedBox(height: 20),

            // 分析按鈕
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: !hasVideo || _selectedSegment == null || _isAnalyzing
                    ? null
                    : _startAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A65FF),
                  disabledBackgroundColor: const Color(0xFFEDEFF7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isAnalyzing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('開始分析',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 20),

            // 進度
            if (_isAnalyzing || _processedFrames > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE0F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _isAnalyzing
                            ? '分析進度：$_processedFrames%'
                            : '分析完成：$_processedFrames / $_totalFrames 幀',
                        style: const TextStyle(
                            color: Color(0xFF1A1D2E),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (!_isAnalyzing)
                      Text(
                          '${_analysisType == "hand" ? "有效手部" : "有效骨架"}：'
                          '$_framesWithPose 幀',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _totalFrames == 0
                          ? 0
                          : _processedFrames / _totalFrames,
                      backgroundColor: const Color(0xFFEDEFF7),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4A65FF)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 多維度分析結果
            if (_mainJointIndices.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF4A65FF), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.analytics,
                            color: Color(0xFF4A65FF), size: 18),
                        SizedBox(width: 6),
                        Text('動作特徵分析',
                            style: TextStyle(
                                color: Color(0xFF1A1D2E),
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('偵測的主要活動關節',
                        style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _mainJointIndices.map((idx) {
                        final movement = _jointTotalMovement[idx] ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '${_jointName(idx)} (${movement.toStringAsFixed(2)})',
                            style: const TextStyle(
                                color: Color(0xFF4A65FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24),
                    _buildAngleStat(
                        '估算動作次數', '$_estimatedReps 次', const Color(0xFF4CAF50)),
                    const SizedBox(height: 8),
                    _buildAngleStat(
                      '左右對稱性',
                      '${(_symmetryScore * 100).toStringAsFixed(0)}%',
                      _symmetryScore > 0.7
                          ? const Color(0xFF4CAF50)
                          : _symmetryScore > 0.4
                              ? const Color(0xFFFF9800)
                              : const Color(0xFFF44336),
                    ),
                    const SizedBox(height: 8),
                    _buildAngleStat(
                      '軀幹穩定性',
                      '${(_stabilityScore * 100).toStringAsFixed(0)}%',
                      _stabilityScore > 0.7
                          ? const Color(0xFF4CAF50)
                          : _stabilityScore > 0.4
                              ? const Color(0xFFFF9800)
                              : const Color(0xFFF44336),
                    ),
                    const SizedBox(height: 8),
                    _buildAngleStat('分析資料點', '${_framePoses.length} 幀',
                        const Color(0xFF6B7280)),
                    const SizedBox(height: 16),

                    // ── 儲存為模板按鈕 ──
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _saveAsTemplate,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('儲存為模板',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '💡 儲存後可作為病人動作比對的參考模板',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // ══════════════════════════════════════════════════════════════
            // 手部分析結果(僅在手部分析模式顯示)
            // ══════════════════════════════════════════════════════════════
            if (_handResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF4A65FF), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 標題 ──
                    const Row(
                      children: [
                        Icon(Icons.back_hand,
                            color: Color(0xFF4A65FF), size: 18),
                        SizedBox(width: 6),
                        Text(
                          '手部動作特徵分析',
                          style: TextStyle(
                            color: Color(0xFF1A1D2E),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── 1. 主要活動手指 ──
                    const Text(
                      '主要活動手指',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _handResult!.mainFingerIndices.map((idx) {
                        final movement =
                            _handResult!.fingerTotalMovement[idx] ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${HandFeatureExtractor.fingerName(idx)} (${movement.toStringAsFixed(2)})',
                            style: const TextStyle(
                              color: Color(0xFF4A65FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const Divider(height: 24),

                    // ── 2. 動作次數 ──
                    _buildAngleStat(
                      '估算動作次數',
                      '${_handResult!.estimatedReps} 次',
                      const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 8),

                    // ── 3. 動作規律性 ──
                    _buildAngleStat(
                      '動作規律性',
                      '${(_handResult!.regularityScore * 100).toStringAsFixed(0)}%',
                      _handResult!.regularityScore > 0.7
                          ? const Color(0xFF4CAF50)
                          : _handResult!.regularityScore > 0.4
                              ? const Color(0xFFFF9800)
                              : const Color(0xFFF44336),
                    ),
                    const SizedBox(height: 8),

                    // ── 4. 拇指-食指開合距離 ──
                    _buildAngleStat(
                      '開合距離範圍',
                      '${_handResult!.minPinchDistance.toStringAsFixed(3)} → '
                          '${_handResult!.maxPinchDistance.toStringAsFixed(3)}',
                      const Color(0xFF4A65FF),
                    ),
                    const SizedBox(height: 8),
                    _buildAngleStat(
                      '平均開合距離',
                      _handResult!.avgPinchDistance.toStringAsFixed(3),
                      const Color(0xFF6B7280),
                    ),
                    const SizedBox(height: 8),

                    // ── 5. 手腕旋轉角度 ──
                    _buildAngleStat(
                      '手腕 2D 方向代理範圍',
                      '${_handResult!.wristRotationRange.toStringAsFixed(1)}°',
                      const Color(0xFFFF9800),
                    ),
                    const SizedBox(height: 8),

                    // ── 6. 分析資料點 ──
                    _buildAngleStat(
                      '分析資料點',
                      '${_handResult!.totalFrames} 幀',
                      const Color(0xFF6B7280),
                    ),

                    const SizedBox(height: 12),

                    // ── 說明 ──
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '💡 手部復健指標:主要活動手指、動作次數、'
                        '開合幅度(側捏/抓握指標)、手腕 2D 方向代理(翻掌參考)、'
                        '動作規律性(復健穩定度)',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ── 儲存為模板按鈕(手部) ──
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _saveAsTemplate,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('儲存為手部模板',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '💡 儲存後可作為手部訓練病人動作比對的參考模板',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAngleStat(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  /// 分析類型切換卡
  Widget _buildAnalysisTypeCard({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool isSelected = _analysisType == type;
    return GestureDetector(
      onTap: _isAnalyzing
          ? null
          : () {
              setState(() {
                _analysisType = type;
                // 換類型時清空既有選擇
                _selectedVideoPath = null;
                _currentActionType = '';
                _resetAnalysisState();
                _handResult = null;
              });
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A65FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4A65FF) : const Color(0xFFDDE0F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
