import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/custom_rehab_exercise.dart';
import '../account/app_session.dart';
import 'controllers/custom_exercise_editor_controller.dart';
import 'controllers/custom_exercise_playback_controller.dart';
import 'custom_exercise_list_page.dart';
import 'repositories/custom_exercise_repository.dart';
import 'repositories/local_custom_exercise_repository.dart';
import 'widgets/custom_exercise_3d_viewer.dart';
import 'widgets/joint_rotation_panel.dart';
import 'widgets/keyframe_timeline.dart';
import 'widgets/pose_measurement_rules_editor.dart';

class CustomExerciseEditorPage extends StatelessWidget {
  final CustomRehabExercise? initialExercise;
  final CustomExerciseRepository? repository;

  const CustomExerciseEditorPage({
    super.key,
    this.initialExercise,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedRepository = repository ?? customExerciseRepository;
    return ChangeNotifierProvider(
      create: (_) => CustomExerciseEditorController(
        initialExercise: initialExercise,
        therapistId: AppSession.userId,
      ),
      child: _CustomExerciseEditorView(repository: resolvedRepository),
    );
  }
}

class _CustomExerciseEditorView extends StatefulWidget {
  final CustomExerciseRepository repository;

  const _CustomExerciseEditorView({required this.repository});

  @override
  State<_CustomExerciseEditorView> createState() =>
      _CustomExerciseEditorViewState();
}

class _CustomExerciseEditorViewState extends State<_CustomExerciseEditorView> {
  static const double _viewerHeight = 420;
  static const double _showFloatingThreshold = 0.02;
  static const double _hideFloatingThreshold = 0.18;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _editorViewportKey = GlobalKey();
  final GlobalKey _viewerSlotKey = GlobalKey();
  bool _isSaving = false;
  bool _showFloatingPreview = false;
  bool _viewerGeometryScheduled = false;
  Rect? _mainViewerRect;

  @override
  void initState() {
    super.initState();
    final draft = context.read<CustomExerciseEditorController>().draft;
    _nameController = TextEditingController(text: draft.name);
    _descriptionController = TextEditingController(text: draft.description);
    _scrollController.addListener(_handleEditorScroll);
    _scheduleViewerGeometryUpdate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _scrollController
      ..removeListener(_handleEditorScroll)
      ..dispose();
    super.dispose();
  }

  void _handleEditorScroll() {
    _updateViewerGeometry();
    _scheduleViewerGeometryUpdate();
  }

  void _scheduleViewerGeometryUpdate() {
    if (_viewerGeometryScheduled) return;
    _viewerGeometryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewerGeometryScheduled = false;
      _updateViewerGeometry();
    });
  }

  void _updateViewerGeometry() {
    if (!mounted) return;
    final viewportBox =
        _editorViewportKey.currentContext?.findRenderObject() as RenderBox?;
    final slotBox =
        _viewerSlotKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null ||
        slotBox == null ||
        !viewportBox.attached ||
        !slotBox.attached ||
        !viewportBox.hasSize ||
        !slotBox.hasSize) {
      return;
    }

    final viewportGlobalRect =
        viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    final slotGlobalRect = slotBox.localToGlobal(Offset.zero) & slotBox.size;
    final intersection = viewportGlobalRect.intersect(slotGlobalRect);
    final visibleHeight = intersection.isEmpty ? 0.0 : intersection.height;
    final visibleFraction = slotBox.size.height == 0
        ? 0.0
        : (visibleHeight / slotBox.size.height).clamp(0.0, 1.0);
    final nextFloating = _showFloatingPreview
        ? visibleFraction < _hideFloatingThreshold
        : visibleFraction <= _showFloatingThreshold;
    final localTopLeft = viewportBox.globalToLocal(slotGlobalRect.topLeft);
    final nextMainRect = localTopLeft & slotBox.size;

    if (_mainViewerRect == nextMainRect &&
        _showFloatingPreview == nextFloating) {
      return;
    }
    setState(() {
      _mainViewerRect = nextMainRect;
      _showFloatingPreview = nextFloating;
    });
  }

  void _updateBasicInfo() {
    context.read<CustomExerciseEditorController>().updateBasicInfo(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveExercise() async {
    _updateBasicInfo();
    final controller = context.read<CustomExerciseEditorController>();
    final validationError = controller.saveValidationError;
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final exercise = controller.createSaveSnapshot();
      if (controller.isEditing) {
        await widget.repository.updateExercise(exercise);
      } else {
        await widget.repository.saveExercise(exercise);
      }
      if (!mounted) return;
      controller.markSaved(exercise);
      _showMessage('自訂動作已儲存');
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('儲存失敗：$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openSavedExercises() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomExerciseListPage(
          repository: widget.repository,
          editorBuilder: (exercise, repository) => CustomExerciseEditorPage(
            initialExercise: exercise,
            repository: repository,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _EditorTopBar(
              isSaving: _isSaving,
              onBrowse: _openSavedExercises,
              onSave: _saveExercise,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  _scheduleViewerGeometryUpdate();
                  return _buildEditorViewport(constraints, isWide);
                },
              ),
            ),
            Consumer<CustomExerciseEditorController>(
              builder: (_, controller, __) => _EditorFooter(
                canPlay: controller.canPlay,
                playbackStatus: controller.playbackStatus,
                onPlay: controller.playbackStatus ==
                        CustomExercisePlaybackStatus.paused
                    ? controller.resumePreview
                    : controller.playPreview,
                onPause: controller.pausePreview,
                onStop: controller.stopPreview,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorViewport(BoxConstraints constraints, bool isWide) {
    final mainRect = _mainViewerRect;
    final floatingWidth =
        (constraints.maxWidth * 0.34).clamp(140.0, 220.0).toDouble();
    final floatingRect = Rect.fromLTWH(
      constraints.maxWidth - floatingWidth - 12,
      12,
      floatingWidth,
      floatingWidth * 1.28,
    );
    final viewerRect = _showFloatingPreview ? floatingRect : mainRect;

    return Stack(
      key: _editorViewportKey,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            key: const Key('custom-exercise-editor-scroll-view'),
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: isWide ? _buildWideLayout() : _buildCompactLayout(),
          ),
        ),
        if (viewerRect != null)
          Positioned.fromRect(
            rect: viewerRect,
            child: IgnorePointer(
              ignoring: _showFloatingPreview,
              child: Material(
                key: const Key('shared-editor-viewer-layer'),
                elevation: _showFloatingPreview ? 8 : 0,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: _buildViewer(
                  height: viewerRect.height,
                  compactPreview: _showFloatingPreview,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildViewerSlot(),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _BasicInfoCard(
                    nameController: _nameController,
                    descriptionController: _descriptionController,
                    onChanged: _updateBasicInfo,
                  ),
                  const SizedBox(height: 16),
                  Consumer<CustomExerciseEditorController>(
                    builder: (_, controller, __) => JointRotationPanel(
                      selectedJoint: controller.selectedJoint,
                      joints: controller.controllableJoints,
                      rotation: controller.selectedJointRotation,
                      onJointSelected: controller.selectJoint,
                      onChanged: controller.updateSelectedJointRotation,
                      onResetSelected: controller.resetSelectedJointRotation,
                      onResetAll: controller.resetAllJointRotations,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const PoseMeasurementRulesEditor(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTimeline(),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        _buildViewerSlot(),
        const SizedBox(height: 16),
        _BasicInfoCard(
          nameController: _nameController,
          descriptionController: _descriptionController,
          onChanged: _updateBasicInfo,
        ),
        const SizedBox(height: 16),
        Consumer<CustomExerciseEditorController>(
          builder: (_, controller, __) => JointRotationPanel(
            selectedJoint: controller.selectedJoint,
            joints: controller.controllableJoints,
            rotation: controller.selectedJointRotation,
            onJointSelected: controller.selectJoint,
            onChanged: controller.updateSelectedJointRotation,
            onResetSelected: controller.resetSelectedJointRotation,
            onResetAll: controller.resetAllJointRotations,
          ),
        ),
        const SizedBox(height: 16),
        _buildTimeline(),
        const SizedBox(height: 16),
        const PoseMeasurementRulesEditor(),
      ],
    );
  }

  Widget _buildViewerSlot() {
    return SizedBox(
      key: _viewerSlotKey,
      width: double.infinity,
      height: _viewerHeight,
    );
  }

  Widget _buildViewer({
    required double height,
    required bool compactPreview,
  }) {
    return Consumer<CustomExerciseEditorController>(
      builder: (_, controller, __) => CustomExercise3dViewer(
        key: const ValueKey('shared-custom-exercise-3d-viewer'),
        selectedJoint: controller.selectedJoint,
        jointRotations: controller.currentPose,
        keyframes: controller.keyframes,
        duration: controller.draft.duration,
        playbackStatus: controller.playbackStatus,
        onPlaybackProgress: controller.updatePlaybackProgress,
        onPlaybackCompleted: controller.completePreview,
        height: height,
        compactPreview: compactPreview,
      ),
    );
  }

  Widget _buildTimeline() {
    return Consumer<CustomExerciseEditorController>(
      builder: (_, controller, __) => KeyframeTimeline(
        keyframes: controller.keyframes,
        selectedKeyframeId: controller.selectedKeyframeId,
        playbackTime: controller.playbackTime,
        duration: controller.draft.duration,
        canPlay: controller.canPlay,
        onAdd: controller.addKeyframeFromCurrentPose,
        onSelected: controller.selectKeyframe,
        onDeleted: controller.deleteKeyframe,
      ),
    );
  }
}

class _EditorTopBar extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onBrowse;
  final bool isSaving;

  const _EditorTopBar({
    required this.onSave,
    required this.onBrowse,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: const Color(0xFF374151),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自訂復健動作',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '建立姿勢與關鍵幀動畫',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('open-saved-custom-exercises'),
            tooltip: '已儲存動作',
            onPressed: onBrowse,
            icon: const Icon(Icons.folder_open_outlined),
            color: const Color(0xFF4A65FF),
          ),
          FilledButton.icon(
            key: const Key('save-custom-exercise'),
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(isSaving ? '儲存中' : '儲存動作'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A65FF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _BasicInfoCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final VoidCallback onChanged;

  const _BasicInfoCard({
    required this.nameController,
    required this.descriptionController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.edit_note, text: '動作資料'),
          const SizedBox(height: 14),
          TextField(
            key: const Key('custom-exercise-name'),
            controller: nameController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: '動作名稱',
              hintText: '例如：右肩抬舉訓練',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('custom-exercise-description'),
            controller: descriptionController,
            onChanged: (_) => onChanged(),
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '動作說明',
              hintText: '描述患者應如何完成這個動作',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorFooter extends StatelessWidget {
  final bool canPlay;
  final CustomExercisePlaybackStatus playbackStatus;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const _EditorFooter({
    required this.canPlay,
    required this.playbackStatus,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaying = playbackStatus == CustomExercisePlaybackStatus.playing;
    final isPaused = playbackStatus == CustomExercisePlaybackStatus.paused;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDDE0F0))),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('play-keyframes'),
            onPressed: canPlay && !isPlaying ? onPlay : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(isPaused ? '繼續' : '播放'),
          ),
          OutlinedButton.icon(
            key: const Key('pause-keyframes'),
            onPressed: isPlaying ? onPause : null,
            icon: const Icon(Icons.pause),
            label: const Text('暫停'),
          ),
          OutlinedButton.icon(
            key: const Key('stop-keyframes'),
            onPressed: isPlaying || isPaused ? onStop : null,
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
          ),
        ],
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  final Widget child;

  const _EditorCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4A65FF), size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1A1D2E),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
