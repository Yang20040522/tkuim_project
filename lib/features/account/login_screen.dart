// lib/features/account/login_screen.dart
import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';

import 'auth_service.dart';
import 'google_auth_service.dart';
import 'home_router.dart';
import 'patient_google_auth_button.dart';
import 'patient_login_session.dart';
import 'user_role.dart';

import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  final PatientGoogleAuthCoordinator? googleAuthCoordinator;

  const LoginScreen({
    super.key,
    required this.role,
    this.googleAuthCoordinator,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '請輸入電子郵件或帳號 ID';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '請輸入密碼';
    }
    if (value.length < 6) {
      return '密碼至少需要 6 個字元';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(
        identifier: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        await _completePatientLogin(
          result,
          fallbackEmail: _emailController.text.trim(),
        );
      } else {
        _showError(result.message ?? '登入失敗,請再試一次');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('無法連線到伺服器,請確認網路狀態或稍後再試');
    }
  }

  Future<void> _completePatientLogin(
    LoginResult result, {
    String fallbackEmail = '',
  }) async {
    try {
      await PatientLoginSession.save(
        result,
        fallbackEmail: fallbackEmail,
      );
    } on PatientRoleException {
      _showError('此帳號無法使用患者登入');
      return;
    } on InvalidPatientSessionException {
      _showError('伺服器登入資料不完整，請稍後再試');
      return;
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => homeForRole(UserRole.patient)),
      (route) => false,
    );
  }

  void _showError(String message) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  color: const Color(0xFF1A1D2E),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: 12),
                const Text(
                  '登入帳號',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '以${widget.role.label}身分登入',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                _buildLabel('電子郵件或帳號 ID'),
                const SizedBox(height: 8),
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildLabel('密碼'),
                const SizedBox(height: 8),
                _buildPasswordField(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('忘記密碼功能即將開放'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color(0xFF1A1D2E),
                        ),
                      );
                    },
                    child: const Text(
                      '忘記密碼？',
                      style: TextStyle(
                        color: Color(0xFF4A65FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildLoginButton(),
                if (widget.role == UserRole.patient) ...[
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Color(0xFFDDE0F0))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '或',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ),
                      Expanded(child: Divider(color: Color(0xFFDDE0F0))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PatientGoogleAuthButton(
                    label: '使用 Google 登入',
                    coordinator: widget.googleAuthCoordinator,
                    onAuthenticated: _completePatientLogin,
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegisterScreen(
                            role: widget.role,
                            googleAuthCoordinator: widget.googleAuthCoordinator,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      '還沒有帳號？前往註冊',
                      style: TextStyle(
                        color: Color(0xFF4A65FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF1A1D2E),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.hintText, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.secondaryText, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE0F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE0F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4A65FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE24B4A)),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1D2E)),
      decoration: _fieldDecoration(
        hint: 'example@email.com 或 rehab123',
        icon: Icons.person_outline,
      ),
      validator: _validateIdentifier,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.password],
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1D2E)),
      decoration: _fieldDecoration(
        hint: '請輸入密碼',
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: AppColors.hintText,
            size: 20,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
      validator: _validatePassword,
      onFieldSubmitted: (_) => _handleLogin(),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A65FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '登入',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}
