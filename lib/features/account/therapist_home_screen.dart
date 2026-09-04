// lib/features/account/therapist_home_screen.dart
import 'package:flutter/material.dart';

import '../custom_exercise/custom_exercise_editor_page.dart';
import '../custom_exercise/custom_exercise_assignment_page.dart';
import '../custom_exercise/custom_exercise_list_page.dart';
import '../custom_exercise/unified_exercise_assignment_page.dart';
import '../custom_exercise/repositories/custom_exercise_assignment_repository_selection.dart';
import '../custom_exercise/repositories/custom_exercise_repository.dart';
import '../custom_exercise/repositories/custom_exercise_repository_selection.dart';
import '../../models/custom_rehab_exercise.dart';
import 'app_session.dart';
import 'patient_management_page.dart';
import 'role_select_screen.dart';

class TherapistHomeScreen extends StatelessWidget {
  const TherapistHomeScreen({super.key});

  void _logout(BuildContext context) async {
    await AppSession.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (route) => false,
    );
  }

  void _openCustomExerciseEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomExerciseEditorPage(
          repository: therapistCustomExerciseRepository,
        ),
      ),
    );
  }

  void _openSavedCustomExercises(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomExerciseListPage(
          repository: therapistCustomExerciseRepository,
          editorBuilder: _buildCustomExerciseEditor,
          assignmentBuilder: (exercise) => CustomExerciseAssignmentPage(
            exercise: exercise,
            repository: customExerciseAssignmentRepository,
          ),
        ),
      ),
    );
  }

  void _openUnifiedAssignment(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UnifiedExerciseAssignmentPage(),
      ),
    );
  }

  void _openPatientManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatientManagementPage()),
    );
  }

  Widget _buildCustomExerciseEditor(
    CustomRehabExercise? exercise,
    CustomExerciseRepository repository,
  ) {
    return CustomExerciseEditorPage(
      initialExercise: exercise,
      repository: repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '治療師',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextButton(
                  onPressed: () => _logout(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE24B4A),
                  ),
                  child: const Text('登出'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              '復健動作管理',
              style: TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '建立適合患者需求的自訂復健動作',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
            const SizedBox(height: 18),
            _TherapistFeatureCard(
              key: const Key('open-custom-exercise-editor'),
              icon: Icons.accessibility_new,
              title: '新增自訂復健動作',
              subtitle: '設定人體姿勢、時間軸與復健判定條件',
              onTap: () => _openCustomExerciseEditor(context),
            ),
            const SizedBox(height: 12),
            _TherapistFeatureCard(
              key: const Key('open-saved-custom-exercises'),
              icon: Icons.folder_open_outlined,
              title: '已儲存自訂動作',
              subtitle: '開啟、修改或刪除雲端自訂動作',
              onTap: () => _openSavedCustomExercises(context),
            ),
            const SizedBox(height: 12),
            _TherapistFeatureCard(
              key: const Key('open-patient-management'),
              icon: Icons.people_outline,
              title: '患者管理',
              subtitle: '使用綁定碼新增患者或解除治療關係',
              onTap: () => _openPatientManagement(context),
            ),
            const SizedBox(height: 12),
            _TherapistFeatureCard(
              key: const Key('open-unified-exercise-assignment'),
              icon: Icons.assignment_ind_outlined,
              title: '指派復健動作',
              subtitle: '統一指派預設與自訂復健動作',
              onTap: () => _openUnifiedAssignment(context),
            ),
            const SizedBox(height: 28),
            const Text(
              '患者綁定後即可在指派頁選擇復健動作',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TherapistFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TherapistFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE0F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF1FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF4A65FF), size: 27),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF9CA3AF),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
