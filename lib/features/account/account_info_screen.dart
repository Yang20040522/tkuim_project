import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tv_cast/socket_client_service.dart';
import 'account_api_service.dart';
import 'account_profile_service.dart';
import 'api_service.dart';
import 'app_session.dart';
import 'google_auth_service.dart';
import 'role_select_screen.dart';
import 'user_role.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({
    super.key,
    this.accountService,
    this.googleCredentialProvider,
  });

  final AccountProfileService? accountService;
  final PatientGoogleCredentialProvider? googleCredentialProvider;

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  late final AccountProfileService _service;
  late final PatientGoogleCredentialProvider _googleCredentialProvider;
  final _clientService = SocketClientService();

  bool _loading = true;
  bool _busy = false;
  AccountInfo? _account;
  DateTime? _birthday;
  int? _age;
  String? _loadError;
  String? _nameOverride;

  @override
  void initState() {
    super.initState();
    _service = widget.accountService ?? AccountProfileService();
    _googleCredentialProvider =
        widget.googleCredentialProvider ?? GoogleSignInCredentialProvider();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final birthday = await _service.getBirthday();
      final account = await _service.getAccountInfo();
      await _updateSessionFromAccount(account);
      if (!mounted) return;
      setState(() {
        _account = account;
        _birthday = birthday;
        _age = _service.calculateAge(birthday);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _safeMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _updateSessionFromAccount(AccountInfo account) {
    final role = account.role.toUpperCase() == 'THERAPIST'
        ? UserRole.therapist
        : UserRole.patient;
    return AppSession.save(
      role: role,
      userId: account.userId,
      name: account.name,
      email: account.email,
      accountId: account.accountId,
      bindingCode: account.bindingCode,
      customExerciseToken: AppSession.customExerciseToken,
    );
  }

  String get _name {
    if (_nameOverride?.isNotEmpty == true) return _nameOverride!;
    final name = _account?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return AppSession.name?.trim().isNotEmpty == true
        ? AppSession.name!.trim()
        : '使用者';
  }

  String? get _email => _account?.email ?? AppSession.email;
  String? get _bindingCode => _account?.bindingCode ?? AppSession.bindingCode;
  bool get _hasPassword => _account?.hasPassword ?? false;
  bool get _googleLinked => _account?.googleLinked ?? false;

  String get _birthdayText {
    if (_birthday == null) return '尚未設定';
    final birthday = _birthday!;
    return '${birthday.year}/${birthday.month.toString().padLeft(2, '0')}/'
        '${birthday.day.toString().padLeft(2, '0')}';
  }

  String get _ageText => _age == null ? '尚未設定' : '$_age 歲';

  Future<void> _editName() async {
    var candidateName = _name;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('編輯姓名'),
        content: TextFormField(
          initialValue: candidateName,
          autofocus: true,
          onChanged: (value) => candidateName = value,
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
            onPressed: () => Navigator.pop(
              dialogContext,
              candidateName.trim().isEmpty ? '使用者' : candidateName.trim(),
            ),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    AppSession.name = result;
    setState(() => _nameOverride = result);
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

  Future<void> _editAccountId() async {
    if (_account == null || _busy) return;
    var candidateAccountId = _account?.accountId ?? '';
    String? validation;
    final accountId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_account?.accountId == null ? '設定帳號 ID' : '修改帳號 ID'),
          content: TextFormField(
            key: const Key('account-id-field'),
            initialValue: candidateAccountId,
            onChanged: (value) => candidateAccountId = value,
            autofocus: true,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: '帳號 ID',
              hintText: '例如 rehab123',
              helperText: '僅能使用英文字母與數字，長度 4～20 個字元',
              errorText: validation,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              key: const Key('save-account-id'),
              onPressed: () {
                final value = candidateAccountId.trim();
                if (value.length < 4 || value.length > 20) {
                  setDialogState(
                    () => validation = '帳號 ID 長度需為 4～20 個字元',
                  );
                  return;
                }
                if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(value)) {
                  setDialogState(
                    () => validation = '帳號 ID 僅能使用英文字母與數字',
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    if (accountId == null) return;

    await _runAccountOperation(() async {
      final updated = await _service.updateAccountId(accountId);
      await _updateSessionFromAccount(updated);
      if (!mounted) return;
      setState(() => _account = updated);
      _showMessage('帳號 ID 已更新');
    });
  }

  Future<void> _changePassword() async {
    if (_account == null || _busy) return;
    final wasPasswordSet = _hasPassword;
    var currentPassword = '';
    var newPassword = '';
    var confirmPassword = '';
    String? validation;

    final change = await showDialog<_PasswordChange>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_hasPassword ? '變更密碼' : '設定密碼'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasPassword) ...[
                  TextField(
                    key: const Key('current-password-field'),
                    onChanged: (value) => currentPassword = value,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '目前密碼',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  key: const Key('new-password-field'),
                  onChanged: (value) => newPassword = value,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '新密碼',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('confirm-password-field'),
                  onChanged: (value) => confirmPassword = value,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '確認新密碼',
                    errorText: validation,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              key: const Key('save-password'),
              onPressed: () {
                if (_hasPassword && currentPassword.isEmpty) {
                  setDialogState(() => validation = '請輸入目前密碼');
                  return;
                }
                if (newPassword.length < 6) {
                  setDialogState(() => validation = '密碼至少需要 6 個字元');
                  return;
                }
                if (newPassword != confirmPassword) {
                  setDialogState(() => validation = '兩次輸入的密碼不一致');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _PasswordChange(
                    currentPassword: _hasPassword ? currentPassword : null,
                    newPassword: newPassword,
                  ),
                );
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    if (change == null) return;

    await _runAccountOperation(() async {
      final updated = await _service.updatePassword(
        currentPassword: change.currentPassword,
        newPassword: change.newPassword,
      );
      if (!mounted) return;
      setState(() => _account = updated);
      _showMessage(wasPasswordSet ? '密碼已更新' : '密碼已設定');
    });
  }

  Future<void> _bindGoogle() async {
    if (_account == null || _busy || _googleLinked) return;
    await _runAccountOperation(() async {
      final credential = await _googleCredentialProvider.authenticate();
      final result = await _service.linkGoogle(credential.idToken);
      if (!result.success || result.backendRole?.toUpperCase() != 'PATIENT') {
        throw AuthApiFailure(
          statusCode: 403,
          code: result.errorCode,
          message: result.message ?? 'Google 帳號綁定失敗，請稍後再試',
        );
      }
      await AppSession.save(
        role: UserRole.patient,
        userId: result.userId,
        name: result.name,
        email: result.email,
        accountId: result.accountId,
        bindingCode: result.bindingCode,
        customExerciseToken: result.customExerciseToken,
      );
      final refreshed = await _service.getAccountInfo();
      if (!mounted) return;
      setState(() => _account = refreshed);
      _showMessage('Google 帳號已綁定');
    });
  }

  Future<void> _deleteAccount() async {
    if (_account == null || _busy) return;
    final proceed = await _confirm(
      title: '註銷帳號',
      message: '註銷後將無法復原，與此帳號相關的資料將被永久刪除。',
      confirmText: '我了解，繼續',
      destructive: true,
    );
    if (!proceed) return;

    String? currentPassword;
    String? idToken;
    if (_hasPassword) {
      currentPassword = await _requestDeletionPassword();
      if (currentPassword == null) return;
    } else {
      try {
        idToken = (await _googleCredentialProvider.authenticate()).idToken;
      } on GoogleAuthCancelledException {
        _showError('Google 驗證已取消');
        return;
      } catch (error) {
        _showError(_safeMessage(error));
        return;
      }
    }

    final finalConfirmation = await _confirm(
      title: '最後確認',
      message: '確定要永久註銷此帳號嗎？此動作無法復原。',
      confirmText: '永久註銷',
      destructive: true,
    );
    if (!finalConfirmation) return;

    await _runAccountOperation(() async {
      await _service.deleteAccount(
        currentPassword: currentPassword,
        idToken: idToken,
      );
      await _service.clearAll();
      await AppSession.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (route) => false,
      );
    });
  }

  Future<String?> _requestDeletionPassword() {
    var password = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('驗證目前密碼'),
        content: TextField(
          key: const Key('delete-account-password-field'),
          onChanged: (value) => password = value,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '目前密碼',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            key: const Key('verify-delete-account'),
            onPressed: () {
              if (password.isNotEmpty) {
                Navigator.pop(dialogContext, password);
              }
            },
            child: const Text('驗證'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                key: Key('confirm-${confirmText.hashCode}'),
                style: destructive
                    ? ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE24B4A),
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runAccountOperation(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } on GoogleAuthCancelledException {
      _showError('Google 操作已取消');
    } catch (error) {
      _showError(_safeMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _safeMessage(Object error) {
    if (error is AuthApiFailure) {
      switch (error.code) {
        case 'ACCOUNT_ID_ALREADY_IN_USE':
          return '此帳號 ID 已被使用';
        case 'GOOGLE_EMAIL_ALREADY_IN_USE':
          return '此 Google 電子郵件已綁定其他帳號，無法使用。';
        case 'GOOGLE_ACCOUNT_CONFLICT':
          return '此帳號已綁定其他 Google 帳號';
        case 'INVALID_CREDENTIALS':
          return '帳號或密碼錯誤';
        case 'UNAUTHORIZED':
          return '登入狀態已失效，請重新登入';
      }
      return error.message;
    }
    if (error is GoogleAuthException) return error.message;
    return '帳號操作失敗，請稍後再試';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE24B4A),
      ),
    );
  }

  Future<void> _copyBindingCode() async {
    final code = _bindingCode?.trim();
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    _showMessage('綁定碼已複製');
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
          leading: IconButton(
            onPressed: () {
              if (_clientService.isConnected) {
                _clientService.sendCommand({'type': 'POP_SCREEN'});
              }
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
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
            : Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_loadError != null) _buildLoadError(),
                      _buildSectionCard(
                        children: [
                          _buildInfoTile(
                            icon: Icons.badge_outlined,
                            label: '姓名',
                            value: _name,
                            onTap: _editName,
                          ),
                          _divider(),
                          _buildInfoTile(
                            icon: Icons.email_outlined,
                            label: '電子郵件',
                            value: _email ?? '尚未設定',
                          ),
                          _divider(),
                          _buildInfoTile(
                            key: const Key('account-id-tile'),
                            icon: Icons.alternate_email,
                            label: '帳號 ID',
                            value: _account?.accountId ?? '尚未設定',
                            onTap: _account == null ? null : _editAccountId,
                            trailingLabel: _account?.accountId == null
                                ? '設定帳號 ID'
                                : '修改帳號 ID',
                          ),
                        ],
                      ),
                      if (AppSession.role == UserRole.patient) ...[
                        const SizedBox(height: 16),
                        _buildBindingCodeCard(),
                        const SizedBox(height: 16),
                        _buildGoogleCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        children: [
                          _buildInfoTile(
                            icon: Icons.cake_outlined,
                            label: '生日',
                            value: _birthdayText,
                            onTap: _pickBirthday,
                          ),
                          _divider(),
                          _buildInfoTile(
                            icon: Icons.numbers_outlined,
                            label: '年齡',
                            value: _ageText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        children: [
                          _buildInfoTile(
                            key: const Key('password-status-tile'),
                            icon: Icons.lock_outline,
                            label: '密碼',
                            value: _hasPassword ? '已設定' : '尚未設定',
                            onTap: _account == null ? null : _changePassword,
                            trailingLabel: _hasPassword ? '變更密碼' : '設定密碼',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        key: const Key('delete-account-button'),
                        onPressed: _account == null ? null : _deleteAccount,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE24B4A),
                          side: const BorderSide(color: Color(0xFFE24B4A)),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('註銷帳號'),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '帳號識別、密碼與 Google 綁定由伺服器安全保存；生日目前僅儲存於本機裝置。',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x22000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_loadError!)),
          TextButton(onPressed: _load, child: const Text('重試')),
        ],
      ),
    );
  }

  Widget _buildGoogleCard() {
    final googleEmail = _account?.googleEmail;
    return _buildSectionCard(
      children: [
        _buildInfoTile(
          key: const Key('google-account-status'),
          icon: Icons.g_mobiledata,
          label: 'Google 帳號',
          value: _googleLinked
              ? '已綁定${googleEmail == null ? '' : '\n$googleEmail'}'
              : '尚未綁定',
          onTap: _account != null && !_googleLinked ? _bindGoogle : null,
          trailingLabel: '綁定 Google 帳號',
        ),
      ],
    );
  }

  Widget _buildBindingCodeCard() {
    final code = _bindingCode?.trim();
    final hasCode = code != null && code.isNotEmpty;
    return Container(
      key: const Key('patient-binding-code-card'),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, color: Color(0xFF4A65FF), size: 20),
              SizedBox(width: 10),
              Text(
                '我的綁定碼',
                style: TextStyle(
                  color: Color(0xFF1A1D2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  hasCode ? code : '尚未取得，請登出後重新登入',
                  key: const Key('patient-binding-code-value'),
                  style: TextStyle(
                    color: hasCode
                        ? const Color(0xFF1A1D2E)
                        : const Color(0xFF9CA3AF),
                    fontSize: hasCode ? 22 : 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: hasCode ? 2 : 0,
                  ),
                ),
              ),
              IconButton.outlined(
                key: const Key('copy-patient-binding-code'),
                tooltip: '複製綁定碼',
                onPressed: hasCode ? _copyBindingCode : null,
                icon: const Icon(Icons.copy_outlined, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '請將此綁定碼提供給您的治療師',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(children: children),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  Widget _divider() => const Divider(
        height: 1,
        color: Color(0xFFDDE0F0),
        indent: 16,
        endIndent: 16,
      );

  Widget _buildInfoTile({
    Key? key,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    String? trailingLabel,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
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
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
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

class _PasswordChange {
  const _PasswordChange({
    required this.currentPassword,
    required this.newPassword,
  });

  final String? currentPassword;
  final String newPassword;
}
