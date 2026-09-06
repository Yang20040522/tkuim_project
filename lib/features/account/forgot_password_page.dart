import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_colors.dart';
import 'account_recovery_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.gateway,
    this.initialIdentifier = '',
  });

  final AccountRecoveryGateway? gateway;
  final String initialIdentifier;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AccountRecoveryGateway _gateway;

  bool _codeRequested = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendSeconds = 0;
  String? _error;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? const AccountRecoveryService();
    _identifierController =
        TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _identifierController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode({bool resend = false}) async {
    if (_loading || (resend && _resendSeconds > 0)) return;
    if (!_codeRequested && !_requestFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await _gateway.requestCode(_identifierController.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.success) {
      setState(() => _error = _safeError(result));
      return;
    }
    setState(() {
      _codeRequested = true;
      _error = null;
    });
    _startResendCooldown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resend
              ? '已重新寄送驗證碼，舊驗證碼將失效。'
              : AccountRecoveryService.genericRequestMessage,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _submitReset() async {
    if (_loading || !_resetFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _gateway.resetPassword(
      identifier: _identifierController.text.trim(),
      code: _codeController.text,
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.success) {
      setState(() => _error = _safeError(result));
      return;
    }
    Navigator.of(context).pop('密碼已更新，請使用新密碼登入');
  }

  String _safeError(AccountRecoveryResult result) {
    return switch (result.errorCode) {
      'INVALID_OR_EXPIRED_RESET_CODE' => '驗證碼無效或已過期',
      'TOO_MANY_ATTEMPTS' => '驗證失敗次數過多，請重新取得驗證碼',
      'INVALID_NEW_PASSWORD' => '新密碼至少需要 6 個字元',
      _ => result.message.isEmpty ? '操作失敗，請稍後再試' : result.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('忘記密碼')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _codeRequested ? _buildResetStep() : _buildRequestStep(),
        ),
      ),
    );
  }

  Widget _buildRequestStep() {
    return Form(
      key: _requestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '重設帳號密碼',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            '請輸入註冊 Email 或帳號 ID，我們會將驗證碼寄到帳號綁定的 Email。',
            style: TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('forgot-password-identifier'),
            controller: _identifierController,
            decoration: const InputDecoration(
              labelText: 'Email 或帳號 ID',
              hintText: '請輸入 Email 或帳號 ID',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? '請輸入 Email 或帳號 ID'
                : null,
          ),
          _errorMessage(),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('forgot-password-request-code'),
            onPressed: _loading ? null : _requestCode,
            child: Text(_loading ? '處理中…' : '寄送驗證碼'),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            AccountRecoveryService.genericRequestMessage,
            key: Key('recovery-generic-message'),
            style: TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('forgot-password-code'),
            controller: _codeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: '6 位數驗證碼',
              hintText: '請輸入驗證碼',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
            validator: (value) =>
                value == null || !RegExp(r'^\d{6}$').hasMatch(value)
                    ? '請輸入 6 位數驗證碼'
                    : null,
          ),
          const SizedBox(height: 16),
          _passwordField(
            key: const Key('forgot-password-new-password'),
            controller: _newPasswordController,
            label: '新密碼',
            obscure: _obscurePassword,
            onToggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            validator: (value) {
              if (value == null || value.isEmpty) return '請輸入新密碼';
              if (value.length < 6) return '新密碼至少需要 6 個字元';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _passwordField(
            key: const Key('forgot-password-confirm-password'),
            controller: _confirmPasswordController,
            label: '確認新密碼',
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            validator: (value) =>
                value != _newPasswordController.text ? '兩次輸入的密碼不一致' : null,
          ),
          _errorMessage(),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('forgot-password-submit'),
            onPressed: _loading ? null : _submitReset,
            child: Text(_loading ? '更新中…' : '更新密碼'),
          ),
          const SizedBox(height: 10),
          TextButton(
            key: const Key('forgot-password-resend'),
            onPressed: _loading || _resendSeconds > 0
                ? null
                : () => _requestCode(resend: true),
            child: Text(
              _resendSeconds > 0 ? '重新寄送驗證碼（$_resendSeconds 秒）' : '重新寄送驗證碼',
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: '至少 6 個字元',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
        ),
      ),
      validator: validator,
    );
  }

  Widget _errorMessage() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        _error!,
        key: const Key('forgot-password-error'),
        style: const TextStyle(color: Color(0xFFC62828)),
      ),
    );
  }
}
