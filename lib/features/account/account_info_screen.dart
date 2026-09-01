// lib/features/account/account_info_screen.dart
//
// 帳號資訊頁面:姓名 / Email / 生日 / 年齡 / 密碼狀態。
//
// 姓名可編輯(同步回 AppSession),Email 目前只顯示、不可編輯
// (從登入來源帶入,例如 Google 登入的信箱)。
// 生日可透過日期選擇器設定,年齡由生日自動算出、不可直接編輯。
// 密碼欄位只顯示「已設定 / 尚未設定」狀態,不會顯示明文密碼,
// 要更改請透過「變更密碼」按鈕(見 account_profile_service.dart
// 開頭說明,目前只是本機占位機制)。

import 'package:flutter/material.dart';
import 'app_session.dart';
import 'account_profile_service.dart';

// 🖥️ 電視投放新增(跟其他畫面保持一致的返回同步行為)
import '../tv_cast/socket_client_service.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _service = AccountProfileService();
  final _clientService = SocketClientService();

  bool _loading = true;
  String _name = '使用者';
  String? _email;
  DateTime? _birthday;
  int? _age;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final birthday = await _service.getBirthday();
    final hasPassword = await _service.hasPasswordSet();
    if (!mounted) return;
    setState(() {
      _name = (AppSession.name != null && AppSession.name!.isNotEmpty)
          ? AppSession.name!
          : '使用者';
      _email = AppSession.email;
      _birthday = birthday;
      _age = _service.calculateAge(birthday);
      _hasPassword = hasPassword;
      _loading = false;
    });
  }

  String get _birthdayText {
    if (_birthday == null) return '尚未設定';
    final b = _birthday!;
    return '${b.year}/${b.month.toString().padLeft(2, '0')}/${b.day.toString().padLeft(2, '0')}';
  }

  String get _ageText => _age == null ? '尚未設定' : '$_age 歲';

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('編輯姓名', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '姓名',
            border: OutlineInputBorder(),
          ),
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
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final newName = result.isEmpty ? '使用者' : result;
    AppSession.name = newName;
    if (!mounted) return;
    setState(() => _name = newName);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: '選擇生日',
    );
    if (picked == null) return;

    await _service.setBirthday(picked);
    if (!mounted) return;
    setState(() {
      _birthday = picked;
      _age = _service.calculateAge(picked);
    });
  }

  Future<void> _changePassword() async {
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                _hasPassword ? '變更密碼' : '設定密碼',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '新密碼',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '確認新密碼',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A65FF),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final newPw = newController.text;
                    final confirmPw = confirmController.text;

                    if (newPw.length < 6) {
                      setDialogState(() => errorText = '密碼至少需要 6 個字元');
                      return;
                    }
                    if (newPw != confirmPw) {
                      setDialogState(() => errorText = '兩次輸入的密碼不一致');
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    await _service.setPassword(newController.text);
    if (!mounted) return;
    setState(() => _hasPassword = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('密碼已更新')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _clientService.isConnected) {
          _clientService.sendCommand({'type': 'POP_SCREEN'});
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () {
              if (_clientService.isConnected) {
                _clientService.sendCommand({'type': 'POP_SCREEN'});
              }
              Navigator.of(context).pop();
            },
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          title: const Text(
            '帳號資訊',
            style: TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1A1D2E)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionCard(
                    children: [
                      _buildInfoTile(
                        icon: Icons.badge_outlined,
                        label: '姓名',
                        value: _name,
                        onTap: _editName,
                      ),
                      _buildDivider(),
                      _buildInfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: _email ?? '尚未設定',
                        onTap: null, // 從登入來源帶入,不可編輯
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    children: [
                      _buildInfoTile(
                        icon: Icons.cake_outlined,
                        label: '生日',
                        value: _birthdayText,
                        onTap: _pickBirthday,
                      ),
                      _buildDivider(),
                      _buildInfoTile(
                        icon: Icons.numbers_outlined,
                        label: '年齡',
                        value: _ageText,
                        onTap: null, // 由生日自動算出,不可直接編輯
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    children: [
                      _buildInfoTile(
                        icon: Icons.lock_outline,
                        label: '密碼',
                        value: _hasPassword ? '已設定' : '尚未設定',
                        onTap: _changePassword,
                        trailingLabel: _hasPassword ? '變更密碼' : '設定密碼',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '目前個人資訊僅儲存於本機裝置,尚未與雲端帳號同步。',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
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
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFFDDE0F0), indent: 16, endIndent: 16);
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    String? trailingLabel,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6B7280), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1A1D2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Text(
                trailingLabel ?? '編輯',
                style: const TextStyle(
                  color: Color(0xFF4A65FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}