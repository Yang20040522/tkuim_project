import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/ui/app_colors.dart';

abstract interface class AppVersionProvider {
  Future<String> loadVersion();
}

class PackageInfoAppVersionProvider implements AppVersionProvider {
  const PackageInfoAppVersionProvider();

  @override
  Future<String> loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final buildNumber = info.buildNumber.trim();
    if (version.isEmpty) return '--';
    return buildNumber.isEmpty ? version : '$version ($buildNumber)';
  }
}

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({
    super.key,
    this.versionProvider,
  });

  final AppVersionProvider? versionProvider;

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  late final AppVersionProvider _versionProvider;
  String _version = '--';

  @override
  void initState() {
    super.initState();
    _versionProvider =
        widget.versionProvider ?? const PackageInfoAppVersionProvider();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await _versionProvider.loadVersion();
      if (!mounted) return;
      setState(() => _version = version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = '--');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: const Text(
          '關於我們',
          style: TextStyle(
            color: Color(0xFF1A1D2E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1D2E)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const _BrandHeader(),
            const SizedBox(height: 20),
            const _AboutCard(
              title: 'RehabAssist',
              icon: Icons.favorite_border_rounded,
              children: [
                _BodyText(
                  'RehabAssist 由 Rehabilitation（復健）與 Assist（協助）兩個概念組成，代表系統透過姿態辨識、即時回饋與復健管理功能，協助使用者進行居家復健訓練，並建立患者與治療師之間的照護與追蹤連結。',
                ),
                SizedBox(height: 12),
                _BodyText(
                  'RehabAssist 的 Logo 以「相機辨識復健動作」為核心概念，結合復健人物、椅子、人體關鍵點與相機取景框，象徵系統利用影像辨識分析復健動作，並將智慧復健延伸至居家環境。',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _AboutCard(
              title: '關於 RehabAssist',
              icon: Icons.health_and_safety_outlined,
              children: [
                _BodyText(
                  'RehabAssist 是一套結合人工智慧姿態辨識、復健訓練管理與遠端照護功能的智慧復健訓練整合平台。',
                ),
                SizedBox(height: 12),
                _BodyText(
                  '系統希望協助具有居家復健需求的使用者，在缺乏治療師即時陪同的情況下，仍能透過動作辨識、即時回饋與訓練紀錄了解目前的訓練狀況，同時讓治療端能透過指派、紀錄與溝通功能持續追蹤居家訓練情形。',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _CoreFeaturesCard(),
            const SizedBox(height: 14),
            const _AboutCard(
              title: '我們的理念',
              icon: Icons.lightbulb_outline_rounded,
              children: [
                _BodyText(
                  '讓復健不再只是完成一次又一次的動作，而是能看見自己的訓練歷程、理解每一次練習的目的，並讓居家訓練與治療端之間建立更清楚的連結。',
                ),
                SizedBox(height: 12),
                _BodyText(
                  'RehabAssist 希望透過一般行動裝置與智慧辨識技術，降低智慧復健的設備門檻，讓居家訓練更容易被持續記錄與追蹤。',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _DevelopmentTeamCard(),
            const SizedBox(height: 14),
            const _TechnologyCard(),
            const SizedBox(height: 14),
            const _AboutCard(
              title: '醫療資訊聲明',
              icon: Icons.medical_information_outlined,
              accentColor: Color(0xFF506B86),
              iconBackground: Color(0xFFEDF3F8),
              children: [
                _BodyText(
                  'RehabAssist 提供復健訓練輔助、動作紀錄與一般性資訊，不能取代醫師、物理治療師或其他醫療專業人員的診斷與治療。若訓練過程中出現明顯疼痛、急性不適或其他異常症狀，請停止訓練並尋求專業醫療協助。',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _VersionCard(version: _version),
            const SizedBox(height: 28),
            const Center(
              child: Column(
                children: [
                  Text(
                    '© 2026 RehabAssist',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '智慧復健訓練整合平台',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1534),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Image.asset(
              'assets/icon/icon.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.health_and_safety_outlined,
                color: Colors.white,
                size: 54,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'RehabAssist',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '智慧復健訓練整合平台',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.title,
    required this.icon,
    required this.children,
    this.accentColor = AppColors.primaryBlue,
    this.iconBackground = const Color(0xFFEFF1FF),
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color accentColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.secondaryText,
        fontSize: 13,
        height: 1.6,
      ),
    );
  }
}

class _CoreFeaturesCard extends StatelessWidget {
  const _CoreFeaturesCard();

  static const _features = [
    _FeatureData(
      Icons.accessibility_new_rounded,
      'AI 姿態辨識',
      '結合 RTMPose WholeBody 與 MediaPipe，支援全身與手部復健動作辨識。',
    ),
    _FeatureData(
      Icons.tips_and_updates_outlined,
      '即時訓練回饋',
      '依據關節角度、姿勢與動作狀態進行判定，提供即時文字與語音提示。',
    ),
    _FeatureData(
      Icons.view_in_ar_outlined,
      '3D 動作示範',
      '在正式訓練前透過 3D 人體模型協助使用者理解動作流程。',
    ),
    _FeatureData(
      Icons.assignment_outlined,
      '復健計畫與動作指派',
      '病患可依復健計畫與治療師指派內容進行訓練。',
    ),
    _FeatureData(
      Icons.insights_outlined,
      '訓練紀錄與分析',
      '保存完成次數、訓練結果與錯誤紀錄，提供後續查看與追蹤。',
    ),
    _FeatureData(
      Icons.tune_rounded,
      '自訂復健動作',
      '治療師可透過 3D 人體模型與關鍵影格建立自訂復健內容。',
    ),
    _FeatureData(
      Icons.smart_toy_outlined,
      'AI 復健助手',
      '提供復健動作、系統操作與一般訓練相關資訊的輔助說明。',
    ),
    _FeatureData(
      Icons.connect_without_contact_outlined,
      '遠端互動',
      '支援病患與治療師聊天、視訊及第二螢幕輔助訓練相關功能。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _AboutCard(
      title: '核心功能',
      icon: Icons.grid_view_rounded,
      children: [
        for (var index = 0; index < _features.length; index++) ...[
          _FeatureRow(data: _features[index]),
          if (index != _features.length - 1)
            const Divider(height: 23, color: Color(0xFFE8EAF1)),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.data});

  final _FeatureData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(data.icon, color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.description,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DevelopmentTeamCard extends StatelessWidget {
  const _DevelopmentTeamCard();

  static const _members = ['楊崇佑', '鄭聿廷', '郭宸佑', '張傑羽', '張峰碩', '劉管亮'];

  @override
  Widget build(BuildContext context) {
    return _AboutCard(
      title: '開發團隊',
      icon: Icons.groups_outlined,
      children: [
        const _TeamInfoRow(label: '組別', value: '資訊應用組'),
        const SizedBox(height: 10),
        const _TeamInfoRow(label: '專題名稱', value: '智慧復健訓練整合平台'),
        const SizedBox(height: 10),
        const _TeamInfoRow(label: '英文名稱', value: 'RehabAssist'),
        const SizedBox(height: 10),
        const _TeamInfoRow(label: '指導老師', value: '魏世杰 老師'),
        const SizedBox(height: 16),
        const Text(
          '專題成員',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final member in _members)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  member,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 15),
        const Text(
          '115 學年度',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TeamInfoRow extends StatelessWidget {
  const _TeamInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TechnologyCard extends StatelessWidget {
  const _TechnologyCard();

  static const _technologies = [
    'Flutter',
    'Dart',
    'Spring Boot',
    'Microsoft SQL Server',
    'RTMPose',
    'MediaPipe',
    'ONNX Runtime',
    'Gemini API',
    'Cloudflare Worker',
    'ZEGO',
  ];

  @override
  Widget build(BuildContext context) {
    return _AboutCard(
      title: '主要技術',
      icon: Icons.memory_outlined,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final technology in _technologies)
              Chip(
                label: Text(technology),
                labelStyle: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: const Color(0xFFF3F5FA),
                side: const BorderSide(color: Color(0xFFE2E5ED)),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primaryBlue, size: 21),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '版本',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            version,
            key: const Key('about-app-version'),
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureData {
  const _FeatureData(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}
