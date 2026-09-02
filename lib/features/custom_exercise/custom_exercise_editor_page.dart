import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/custom_rehab_exercise.dart';
import '../account/app_session.dart';
import 'controllers/custom_exercise_editor_controller.dart';
import 'widgets/custom_exercise_3d_viewer.dart';
import 'widgets/joint_rotation_panel.dart';

class CustomExerciseEditorPage extends StatelessWidget {
  final CustomRehabExercise? initialExercise;

  const CustomExerciseEditorPage({super.key, this.initialExercise});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CustomExerciseEditorController(
        initialExercise: initialExercise,
        therapistId: AppSession.userId,
      ),
      child: const _CustomExerciseEditorView(),
    );
  }
}

class _CustomExerciseEditorView extends StatefulWidget {
  const _CustomExerciseEditorView();

  @override
  State<_CustomExerciseEditorView> createState() =>
      _CustomExerciseEditorViewState();
}

class _CustomExerciseEditorViewState extends State<_CustomExerciseEditorView> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final draft = context.read<CustomExerciseEditorController>().draft;
    _nameController = TextEditingController(text: draft.name);
    _descriptionController = TextEditingController(text: draft.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateBasicInfo() {
    context.read<CustomExerciseEditorController>().updateBasicInfo(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        );
  }

  void _showMilestoneMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
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
            _EditorTopBar(onSave: () {
              _updateBasicInfo();
              _showMilestoneMessage('儲存功能將於 Milestone 7 完成');
            }),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: isWide ? _buildWideLayout() : _buildCompactLayout(),
                  );
                },
              ),
            ),
            _EditorFooter(
              onPlay: () => _showMilestoneMessage('播放功能將於 Milestone 5 完成'),
              onPause: () => _showMilestoneMessage('播放功能將於 Milestone 5 完成'),
              onStop: () => _showMilestoneMessage('播放功能將於 Milestone 5 完成'),
            ),
          ],
        ),
      ),
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
              child: Consumer<CustomExerciseEditorController>(
                builder: (_, controller, __) => CustomExercise3dViewer(
                  selectedJoint: controller.selectedJoint,
                  jointRotations: controller.currentPose,
                ),
              ),
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
                  const _EditorSectionPlaceholder(
                    icon: Icons.rule,
                    title: '判定條件與復健設定',
                    description: '設定介面將於後續階段加入',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _TimelinePlaceholder(),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        Consumer<CustomExerciseEditorController>(
          builder: (_, controller, __) => CustomExercise3dViewer(
            selectedJoint: controller.selectedJoint,
            jointRotations: controller.currentPose,
          ),
        ),
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
        const _TimelinePlaceholder(),
        const SizedBox(height: 16),
        const _EditorSectionPlaceholder(
          icon: Icons.rule,
          title: '判定條件與復健設定',
          description: '設定介面將於後續階段加入',
        ),
      ],
    );
  }
}

class _EditorTopBar extends StatelessWidget {
  final VoidCallback onSave;

  const _EditorTopBar({required this.onSave});

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
          FilledButton.icon(
            key: const Key('save-custom-exercise'),
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('儲存動作'),
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

class _TimelinePlaceholder extends StatelessWidget {
  const _TimelinePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.timeline, text: '姿勢時間軸'),
          SizedBox(height: 18),
          Row(
            children: [
              _TimelineDot(label: '起始', active: true),
              Expanded(child: Divider(color: Color(0xFFDDE0F0), thickness: 2)),
              _TimelineDot(label: '新增姿勢', active: false),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Keyframe 操作將於 Milestone 4 加入',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final String label;
  final bool active;

  const _TimelineDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF4A65FF) : Colors.white,
            border: Border.all(color: const Color(0xFF4A65FF), width: 2),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
      ],
    );
  }
}

class _EditorSectionPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EditorSectionPlaceholder({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: icon, text: title),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EditorFooter extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const _EditorFooter({
    required this.onPlay,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
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
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow),
            label: const Text('播放'),
          ),
          OutlinedButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause),
            label: const Text('暫停'),
          ),
          OutlinedButton.icon(
            onPressed: onStop,
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
