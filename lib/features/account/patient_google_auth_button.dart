import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'google_auth_service.dart';
import 'user_avatar_repository.dart';

typedef PatientGoogleAuthenticated = Future<void> Function(LoginResult result);

class PatientGoogleAuthButton extends StatefulWidget {
  const PatientGoogleAuthButton({
    super.key,
    required this.label,
    required this.onAuthenticated,
    this.coordinator,
    this.avatarRepository,
  });

  final String label;
  final PatientGoogleAuthenticated onAuthenticated;
  final PatientGoogleAuthCoordinator? coordinator;
  final UserAvatarRepository? avatarRepository;

  @override
  State<PatientGoogleAuthButton> createState() =>
      _PatientGoogleAuthButtonState();
}

class _PatientGoogleAuthButtonState extends State<PatientGoogleAuthButton> {
  late final PatientGoogleAuthCoordinator _coordinator;
  late final UserAvatarRepository _avatarRepository;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _coordinator = widget.coordinator ?? PatientGoogleAuthCoordinator();
    _avatarRepository = widget.avatarRepository ?? LocalUserAvatarRepository();
  }

  Future<void> _authenticate() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final result = await _coordinator.authenticate();
    if (!mounted) return;

    if (result.status == PatientGoogleAuthStatus.success) {
      await _rememberGooglePhoto(result);
      await widget.onAuthenticated(result.loginResult!);
    } else if (result.status == PatientGoogleAuthStatus.linkRequired) {
      final linkedResult = await _showLinkDialog();
      if (linkedResult != null && mounted) {
        await _rememberGooglePhoto(linkedResult);
        await widget.onAuthenticated(linkedResult.loginResult!);
      }
    } else {
      _showMessage(result.message ?? 'Google 登入失敗，請稍後再試');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<PatientGoogleAuthResult?> _showLinkDialog() async {
    return showDialog<PatientGoogleAuthResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GoogleAccountLinkDialog(coordinator: _coordinator),
    );
  }

  Future<void> _rememberGooglePhoto(PatientGoogleAuthResult result) async {
    final userId = result.loginResult?.userId?.trim();
    if (userId == null || userId.isEmpty) return;
    try {
      await _avatarRepository.saveGooglePhotoUrl(
        'user_$userId',
        result.googlePhotoUrl,
      );
    } catch (_) {
      // Avatar persistence must never block an otherwise valid login.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFE24B4A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        key: const Key('patient-google-auth-button'),
        onPressed: _isLoading ? null : _authenticate,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A1D2E),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDDE0F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.g_mobiledata, size: 28),
        label: Text(
          _isLoading ? 'Google 登入中…' : widget.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GoogleAccountLinkDialog extends StatefulWidget {
  const _GoogleAccountLinkDialog({required this.coordinator});

  final PatientGoogleAuthCoordinator coordinator;

  @override
  State<_GoogleAccountLinkDialog> createState() =>
      _GoogleAccountLinkDialogState();
}

class _GoogleAccountLinkDialogState extends State<_GoogleAccountLinkDialog> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = '請輸入原帳號密碼');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final linkResult = await widget.coordinator.link(
      _passwordController.text,
    );
    if (!mounted) return;
    if (linkResult.status == PatientGoogleAuthStatus.success) {
      Navigator.of(context).pop(linkResult);
      return;
    }
    setState(() {
      _submitting = false;
      _errorMessage = linkResult.message ?? '帳號連結失敗，請稍後再試';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('連結既有帳號'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('此 Google 帳號的電子郵件已存在患者帳號。'),
            const SizedBox(height: 8),
            const Text('請輸入原帳號密碼以完成連結。'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('google-link-password-field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              enabled: !_submitting,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '原帳號密碼',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  widget.coordinator.cancelPendingLink();
                  Navigator.of(context).pop();
                },
          child: const Text('取消'),
        ),
        ElevatedButton(
          key: const Key('google-link-confirm-button'),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('確認連結'),
        ),
      ],
    );
  }
}
