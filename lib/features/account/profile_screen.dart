// lib/features/account/profile_screen.dart
//
// 個人資料頁 — 底部導覽「個人」tab 對應頁面
// 樣式比照 home_screen.dart 的色票與元件寫法
// 目前不含綁定治療師流程，之後要接時在「帳號尚未綁定」卡片的 onTap 接
// features/account/bind_therapist_screen.dart 即可
//
// 更新內容:
// 1. 右上角鉛筆按鈕可編輯姓名 / 帳號(電話),用 showDialog 跳出輸入框
// 2. 「登出」項目改為導向 login_screen.dart,輸入電子郵件與密碼登入
//    登入成功後會把 email 帶回來更新畫面顯示
//
// 注意:目前姓名/帳號/登入狀態都只存在記憶體中，app 關掉重開就會消失。
// 之後要做到「重開 app 仍記得帳號」，需要搭配本地儲存(例如 shared_preferences)
// 或串接後端 API 來持久化這些資料。

import 'package:flutter/material.dart';

import '../../services/history_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 樣式跟首頁共用同一份 HistoryService,資料才會跟首頁「今日準確度」連動
  final HistoryService _historyService = HistoryService();

  String _userName = '使用者';
  String _userPhone = '尚未設定';
  String? _userEmail; // 登入後才會有值
  int _totalDays = 0;
  String _avgAccuracy = '-- %';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // 累積訓練天數:歷史紀錄裡出現過的不重複日期數
  // 平均準確度:所有紀錄的平均(不只今天),公式跟首頁「今日準確度」同一套換算
  Future<void> _loadStats() async {
    final records = await _historyService.getHistory();
    if (!mounted) return;

    final days = records.map((r) => r.timestamp.substring(0, 10)).toSet();

    String avgText = '-- %';
    if (records.isNotEmpty) {
      final avgMistakes =
          records.map((r) => r.mistakeLogs.length).reduce((a, b) => a + b) /
              records.length;
      final acc = ((10 - avgMistakes) / 10 * 100).clamp(0, 100).round();
      avgText = '$acc %';
    }

    setState(() {
      _totalDays = days.length;
      _avgAccuracy = avgText;
    });
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 即將開放'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1D2E),
      ),
    );
  }

  // 跳出對話框讓使用者輸入姓名 / 帳號(電話)
  void _editProfile() {
    final nameController = TextEditingController(text: _userName);
    final phoneController = TextEditingController(
      text: _userPhone == '尚未設定' ? '' : _userPhone,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '編輯個人資料',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '姓名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: '帳號 / 電話',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A65FF),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _userName = nameController.text.trim().isEmpty
                      ? '使用者'
                      : nameController.text.trim();
                  _userPhone = phoneController.text.trim().isEmpty
                      ? '尚未設定'
                      : phoneController.text.trim();
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  // 導向登入畫面(輸入電子郵件與密碼)
  // 登入成功後會回傳後端給的使用者資料(name, email),更新畫面上的顯示狀態
  Future<void> _goToLogin() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (result != null && result['email'] != null) {
      if (!mounted) return;
      setState(() {
        _userEmail = result['email'];
        // 後端有回傳姓名的話就順便更新姓名顯示
        if (result['name'] != null && result['name']!.isNotEmpty) {
          _userName = result['name']!;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已登入:${_userEmail!}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1A1D2E),
        ),
      );
    }
  }

  void _handleLogout() {
    if (_userEmail == null) {
      // 尚未登入,直接導向登入畫面
      _goToLogin();
      return;
    }
    // 已登入的情況,詢問是否登出
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('登出'),
          content: const Text('確定要登出目前帳號嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE24B4A),
              ),
              onPressed: () {
                setState(() => _userEmail = null);
                Navigator.pop(dialogContext);
              },
              child: const Text('登出'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 20),
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildBindTherapistCard(),
              const SizedBox(height: 24),
              _buildSettingsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Text(
          '個人',
          style: TextStyle(
            color: Color(0xFF1A1D2E),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A65FF), Color(0xFF7B5EA7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName.substring(0, 1) : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userEmail ?? _userPhone,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _editProfile,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Icon(Icons.edit_outlined,
                  color: Color(0xFF6B7280), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(title: '累積訓練天數', value: '$_totalDays 天'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniStatCard(title: '平均準確度', value: _avgAccuracy),
        ),
      ],
    );
  }

  Widget _buildBindTherapistCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.link, color: Color(0xFF4A65FF), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '帳號尚未綁定',
                  style: TextStyle(
                    color: Color(0xFF373F8C),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '綁定治療師或家人以同步復健紀錄',
                  style: TextStyle(color: Color(0xFF4A65FF), fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: Color(0xFF4A65FF), size: 14),
        ],
      ),
    );
    // TODO: 之後要接綁定流程時，外面包一層 GestureDetector，
    // onTap 導到 features/account/bind_therapist_screen.dart
  }

  Widget _buildSettingsList() {
    return Container(
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
      child: Column(
        children: [
          _buildSettingsItem(
            icon: Icons.person_outline,
            label: '帳號資訊',
            onTap: () => _comingSoon('帳號資訊'),
          ),
          _buildDivider(),
          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            label: '通知設定',
            onTap: () => _comingSoon('通知設定'),
          ),
          _buildDivider(),
          _buildSettingsItem(
            icon: Icons.lock_outline,
            label: '隱私權限',
            onTap: () => _comingSoon('隱私權限'),
          ),
          _buildDivider(),
          _buildSettingsItem(
            icon: Icons.info_outline,
            label: '關於我們',
            onTap: () => _comingSoon('關於我們'),
          ),
          _buildDivider(),
          _buildSettingsItem(
            icon: Icons.logout,
            label: _userEmail == null ? '登入' : '登出',
            labelColor: const Color(0xFFE24B4A),
            iconColor: const Color(0xFFE24B4A),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFFDDE0F0), indent: 16, endIndent: 16);
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? const Color(0xFF6B7280), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? const Color(0xFF1A1D2E),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: const Color(0xFF9CA3AF), size: 12),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;

  const _MiniStatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}