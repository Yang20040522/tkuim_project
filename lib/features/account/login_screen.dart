// lib/features/account/login_screen.dart
import 'package:flutter/material.dart';

import '../../core/ui/app_colors.dart';

import 'auth_service.dart';
import 'forgot_password_page.dart';
import 'google_auth_service.dart';
import 'home_router.dart';
import 'patient_google_auth_button.dart';
import 'patient_login_session.dart';
import 'app_session.dart';
import 'therapist_register_screen.dart';
import 'user_role.dart';

import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole? role;
  final PatientGoogleAuthCoordinator? googleAuthCoordinator;
  final Future<LoginResult> Function(String identifier, String password)? login;
  final Widget Function(UserRole role)? homeBuilder;

  const LoginScreen({
    super.key,
    this.role,
    this.googleAuthCoordinator,
    this.login,
    this.homeBuilder,
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
      final result = await (widget.login
              ?.call(_emailController.text.trim(), _passwordController.text) ??
          AuthService.login(
            identifier: _emailController.text.trim(),
            password: _passwordController.text,
          ));

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        final backendRole = result.backendRole?.toUpperCase();
        if (backendRole == 'PATIENT') {
          await _completePatientLogin(result,
              fallbackEmail: _emailController.text.trim());
        } else if (backendRole == 'THERAPIST') {
          await _completeTherapistLogin(result);
        } else {
          _showError('伺服器回傳的帳號身分無法使用，請聯絡管理員。');
        }
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
      MaterialPageRoute(builder: (_) => _home(UserRole.patient)),
      (route) => false,
    );
  }

  Future<void> _completeTherapistLogin(LoginResult result) async {
    final token = result.customExerciseToken?.trim();
    if ((result.userId ?? '').trim().isEmpty ||
        token == null ||
        token.isEmpty) {
      _showError('伺服器登入資料不完整，請稍後再試');
      return;
    }
    await AppSession.save(
      role: UserRole.therapist,
      userId: result.userId,
      name: result.name,
      email: result.email,
      accountId: result.accountId,
      bindingCode: result.bindingCode,
      friendCode: result.friendCode,
      customExerciseToken: token,
    );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => _home(UserRole.therapist)),
        (route) => false);
  }

  Widget _home(UserRole role) =>
      widget.homeBuilder?.call(role) ?? homeForRole(role);

  Future<void> _openRegistration() async {
    if (widget.role != null) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(
              role: widget.role!,
              googleAuthCoordinator: widget.googleAuthCoordinator,
            ),
          ));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('註冊帳號')),
          ListTile(
            key: const Key('register-patient'),
            leading: const Icon(Icons.self_improvement),
            title: const Text('患者註冊'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(
                      role: UserRole.patient,
                      googleAuthCoordinator: widget.googleAuthCoordinator,
                    ),
                  ));
            },
          ),
          ListTile(
            key: const Key('register-therapist'),
            leading: const Icon(Icons.medical_services_outlined),
            title: const Text('治療師註冊'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TherapistRegisterScreen(),
                  ));
            },
          ),
        ]),
      ),
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
                if (widget.role != null)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: const Color(0xFF1A1D2E),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                const SizedBox(height: 12),
                const Text(
                  'RehabAssist 登入',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.role == null
                      ? '使用既有帳號登入，系統會依後端身分開啟對應功能'
                      : '以${widget.role!.label}身分登入',
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
                    key: const Key('forgot-password-entry'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final message = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordPage(
                            initialIdentifier: _emailController.text.trim(),
                          ),
                        ),
                      );
                      if (!mounted || message == null) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(message),
                          behavior: SnackBarBehavior.floating,
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
                if (widget.role != UserRole.therapist) ...[
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
                    onPressed: _openRegistration,
                    child: const Text(
                      '還沒有帳號？註冊帳號',
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
