// lib/features/account/therapist_home_screen.dart
import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';

import '../chat/chat_backend.dart';
import '../chat/chat_home_screen.dart';
import '../custom_exercise/custom_exercise_editor_page.dart';
import '../custom_exercise/custom_exercise_assignment_page.dart';
import '../custom_exercise/custom_exercise_list_page.dart';
import '../custom_exercise/unified_exercise_assignment_page.dart';
import '../custom_exercise/repositories/custom_exercise_assignment_repository_selection.dart';
import '../custom_exercise/repositories/custom_exercise_repository.dart';
import '../custom_exercise/repositories/custom_exercise_repository_selection.dart';
import '../plan/therapist_plan_management_page.dart';
import '../rehab_ml/therapist_research_samples_page.dart';
import '../rehab_ml/ml_research_api.dart';
import '../rehab_ml/research_management_page.dart';
import '../../models/custom_rehab_exercise.dart';
import 'app_session.dart';
import 'patient_management_page.dart';
import 'repositories/therapist_patient_repository.dart';
import 'repositories/therapist_patient_repository_selection.dart';
import 'role_select_screen.dart';

class TherapistHomeScreen extends StatefulWidget {
  const TherapistHomeScreen({
    super.key,
    this.chatBackend,
    this.researchRemote,
    this.patientRepository,
    this.exerciseRepository,
  });

  final ChatBackend? chatBackend;
  final MlResearchRemote? researchRemote;
  final TherapistPatientRepository? patientRepository;
  final CustomExerciseRepository? exerciseRepository;

  @override
  State<TherapistHomeScreen> createState() => _TherapistHomeScreenState();
}

class _TherapistHomeScreenState extends State<TherapistHomeScreen> {
  late final PageController _pageController;
  late final Widget _chatPage;
  late final TherapistPatientRepository _patientRepository;
  late final CustomExerciseRepository _exerciseRepository;
  int _selectedIndex = 0;
  bool _canManageResearch = false;
  int? _patientCount;
  int? _exerciseCount;
  bool _loadingOverview = true;
  bool _refreshingOverview = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(keepPage: true);
    _chatPage = _TherapistKeepAlivePage(
      child: ChatHomeScreen(backend: widget.chatBackend),
    );
    _patientRepository = widget.patientRepository ?? therapistPatientRepository;
    _exerciseRepository =
        widget.exerciseRepository ?? therapistCustomExerciseRepository;
    _loadOverview();
    _loadResearchAuthority();
  }

  // One read per repository on entry / explicit refresh. No polling or build I/O.
  Future<void> _loadOverview() async {
    if (_refreshingOverview) return;
    _refreshingOverview = true;
    Future<int?> count(Future<List<Object>> Function() load) async {
      try {
        return (await load()).length;
      } catch (_) {
        return null;
      }
    }

    final counts = await Future.wait([
      count(_patientRepository.getPatients),
      count(_exerciseRepository.getAllExercises),
    ]);
    _refreshingOverview = false;
    if (!mounted) return;
    setState(() {
      _patientCount = counts[0];
      _exerciseCount = counts[1];
      _loadingOverview = false;
    });
  }

  Future<void> _loadResearchAuthority() async {
    if (AppSession.userId?.isEmpty != false ||
        AppSession.customExerciseToken?.isEmpty != false) {
      return;
    }
    try {
      final access =
          await (widget.researchRemote ?? MlResearchApi()).authority();
      if (mounted) {
        setState(() => _canManageResearch = access['canManage'] == true);
      }
    } catch (_) {
      if (mounted) setState(() => _canManageResearch = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

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
          repository: _exerciseRepository,
        ),
      ),
    );
  }

  void _openSavedCustomExercises(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomExerciseListPage(
          repository: _exerciseRepository,
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
      MaterialPageRoute(
        builder: (_) => PatientManagementPage(repository: _patientRepository),
      ),
    );
  }

  void _openRehabPlanManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TherapistPlanManagementPage(
          patientRepository: _patientRepository,
        ),
      ),
    );
  }

  void _openResearchSamples(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const TherapistResearchSamplesPage(),
    ));
  }

  void _openResearchManagement(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ResearchManagementPage(remote: widget.researchRemote),
    ));
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
      body: PageView(
        key: const ValueKey('therapist-tab-pages'),
        controller: _pageController,
        onPageChanged: _handlePageChanged,
        children: [
          _TherapistKeepAlivePage(child: _buildHomePage(context)),
          _chatPage,
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        key: const ValueKey('therapist-bottom-navigation'),
        currentIndex: _selectedIndex,
        onTap: _selectPage,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4A65FF),
        unselectedItemColor: AppColors.secondaryText,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_outlined,
              key: ValueKey('therapist-tab-home'),
            ),
            activeIcon: Icon(
              Icons.home,
              key: ValueKey('therapist-tab-home'),
            ),
            label: '首頁',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.chat_bubble_outline,
              key: ValueKey('therapist-tab-chat'),
            ),
            activeIcon: Icon(
              Icons.chat_bubble,
              key: ValueKey('therapist-tab-chat'),
            ),
            label: '訊息',
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage(BuildContext context) {
    final name = AppSession.name?.trim();
    final therapistName = name == null || name.isEmpty ? '治療師' : name;
    final primaryActions = [
      _TherapistFeatureCard(
        key: const Key('open-custom-exercise-editor'),
        icon: Icons.accessibility_new,
        title: '新增自訂復健動作',
        subtitle: '建立姿勢與訓練條件',
        accent: AppColors.primaryBlue,
        onTap: () => _openCustomExerciseEditor(context),
      ),
      _TherapistFeatureCard(
        key: const Key('open-saved-custom-exercises'),
        icon: Icons.folder_open_outlined,
        title: '已儲存自訂動作',
        subtitle: '管理雲端動作資料庫',
        accent: const Color(0xFFAA642C),
        onTap: () => _openSavedCustomExercises(context),
      ),
    ];
    final careActions = [
      _TherapistFeatureCard(
        key: const Key('open-patient-management'),
        icon: Icons.people_outline,
        title: '患者管理',
        subtitle: '管理綁定與訓練紀錄',
        accent: const Color(0xFF25816D),
        onTap: () => _openPatientManagement(context),
      ),
      _TherapistFeatureCard(
        key: const Key('open-unified-exercise-assignment'),
        icon: Icons.assignment_ind_outlined,
        title: '指派復健動作',
        subtitle: '選擇預設或自訂動作',
        accent: const Color(0xFF7656B5),
        onTap: () => _openUnifiedAssignment(context),
      ),
      _TherapistFeatureCard(
        key: const Key('open-rehab-plan-management'),
        icon: Icons.calendar_month_outlined,
        title: '制定復健計畫',
        subtitle: '安排每日組數與次數',
        accent: const Color(0xFF277B9B),
        onTap: () => _openRehabPlanManagement(context),
      ),
    ];

    return ColoredBox(
      color: AppColors.lightSurface,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOverview,
          child: ListView(
            key: const ValueKey('therapist-home-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 23,
                    backgroundColor: Color(0xFFE8ECFF),
                    child: Icon(Icons.medical_services_outlined,
                        color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('您好，',
                            style: TextStyle(
                                color: AppColors.secondaryText, fontSize: 13)),
                        Text(
                          therapistName,
                          key: const Key('therapist-home-name'),
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
              const SizedBox(height: 14),
              const Text('一起幫助患者，讓復健更有效率',
                  style:
                      TextStyle(color: AppColors.secondaryText, fontSize: 13)),
              const SizedBox(height: 24),
              const _SectionHeading(
                title: '照護概覽',
                subtitle: '下拉更新患者與動作數量',
              ),
              const SizedBox(height: 12),
              _DashboardGrid(columns: 3, children: [
                _SummaryCard(
                  key: const Key('summary-patients'),
                  icon: Icons.people_outline,
                  label: '綁定患者',
                  value: _patientCount?.toString() ?? '--',
                  loading: _loadingOverview,
                  onTap: () => _openPatientManagement(context),
                ),
                _SummaryCard(
                  key: const Key('summary-exercises'),
                  icon: Icons.folder_open_outlined,
                  label: '自訂動作',
                  value: _exerciseCount?.toString() ?? '--',
                  loading: _loadingOverview,
                  onTap: () => _openSavedCustomExercises(context),
                ),
                _SummaryCard(
                  icon: Icons.calendar_month_outlined,
                  label: '復健計畫',
                  value: '安排',
                  onTap: () => _openRehabPlanManagement(context),
                ),
              ]),
              if (!_loadingOverview &&
                  (_patientCount == null || _exerciseCount == null)) ...[
                const SizedBox(height: 8),
                const Text('部分概覽暫時無法取得；功能入口仍可使用。',
                    key: Key('overview-unavailable'),
                    style: TextStyle(
                        color: AppColors.secondaryText, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              const _SectionHeading(title: '快速功能', subtitle: '從動作建立到照護安排'),
              const SizedBox(height: 12),
              _DashboardGrid(columns: 2, children: primaryActions),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                // Three care cards only when each can fit readable text.
                final columns = constraints.maxWidth >= 560 &&
                        MediaQuery.textScalerOf(context).scale(16) <= 20
                    ? 3
                    : 2;
                return _DashboardGrid(columns: columns, children: careActions);
              }),
              const SizedBox(height: 24),
              const _SectionHeading(
                  title: '研究工作區', subtitle: '沿用既有研究授權與資料存取規則'),
              const SizedBox(height: 12),
              _TherapistFeatureCard(
                key: const Key('open-research-samples'),
                icon: Icons.science_outlined,
                title: '研究資料標註',
                subtitle: '查看已授權的匿名骨架樣本並標註',
                accent: const Color(0xFF7656B5),
                onTap: () => _openResearchSamples(context),
              ),
              if (_canManageResearch) ...[
                const SizedBox(height: 12),
                _TherapistFeatureCard(
                  key: const Key('open-research-management'),
                  icon: Icons.admin_panel_settings_outlined,
                  title: '研究管理',
                  subtitle: '審核授權、資料狀態與已審核資料匯出',
                  accent: const Color(0xFF277B9B),
                  onTap: () => _openResearchManagement(context),
                ),
              ],
              const SizedBox(height: 20),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: AppColors.secondaryText),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('照護小提醒：先綁定患者，再指派動作與安排復健計畫。',
                        style: TextStyle(
                            color: AppColors.secondaryText, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistKeepAlivePage extends StatefulWidget {
  const _TherapistKeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_TherapistKeepAlivePage> createState() =>
      _TherapistKeepAlivePageState();
}

class _TherapistKeepAlivePageState extends State<_TherapistKeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: AppColors.secondaryText, fontSize: 12)),
        ],
      );
}

/// Non-scrolling rows size to their tallest card, including enlarged text.
class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var offset = 0; offset < columns; offset++) ...[
                    if (offset > 0) const SizedBox(width: 12),
                    Expanded(
                      child: start + offset < children.length
                          ? children[start + offset]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.loading = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primaryBlue, size: 21),
                const SizedBox(height: 10),
                Text(value,
                    style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 23,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 12)),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _TherapistFeatureCard extends StatelessWidget {
  const _TherapistFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F2040),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE7EAF2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: accent, size: 24),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          color: AppColors.secondaryText, size: 20),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                          height: 1.5)),
                ],
              ),
            ),
          ),
        ),
      );
}
