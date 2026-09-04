// lib/features/account/therapist_login_screen.dart
//
// 治療端專用登入頁(空殼,尚未接後端)。
// 目前用固定帳密比對,demo/口試用,之後接真後端時
// 只要把 _handleLogin() 裡的比對邏輯換成打 API 即可。

import 'package:flutter/material.dart';

import 'app_session.dart';
import 'home_router.dart';
import 'user_role.dart';

// 🔧 demo用固定帳密,之後接後端時整段改成呼叫 API
const String _kDemoTherapistEmail = 'therapist@demo.com';
const String _kDemoTherapistPassword = '123456';

class TherapistLoginScreen extends StatefulWidget {
  const TherapistLoginScreen({super.key});

  @override
  State<TherapistLoginScreen> createState() => _TherapistLoginScreenState();
}

class _TherapistLoginScreenState extends State<TherapistLoginScreen> {
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 500)); // 模擬loading

    final emailOk = _emailController.text.trim() == _kDemoTherapistEmail;
    final passwordOk = _passwordController.text == _kDemoTherapistPassword;

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!emailOk || !passwordOk) {
      _showError('帳號或密碼錯誤');
      return;
    }

    await AppSession.save(
      role: UserRole.therapist,
      userId: 'demo-therapist',
      name: '治療師示範帳號',
      email: _kDemoTherapistEmail,
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => homeForRole(UserRole.therapist)),
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
                  '治療師登入',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '目前為demo測試帳號,尚未串接雲端後端',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9E7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF5E5A8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFB8860B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '測試帳號:$_kDemoTherapistEmail\n測試密碼:$_kDemoTherapistPassword',
                          style: const TextStyle(
                              color: Color(0xFF8B6F00), fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text('電子郵件',
                    style: TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      _decoration('example@email.com', Icons.mail_outline),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '請輸入電子郵件' : null,
                ),
                const SizedBox(height: 20),
                const Text('密碼',
                    style: TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _decoration(
                    '請輸入密碼',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '請輸入密碼' : null,
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _emailController.text = _kDemoTherapistEmail;
                      _passwordController.text = _kDemoTherapistPassword;
                    },
                    child: const Text(
                      '帶入測試帳密',
                      style: TextStyle(
                          color: Color(0xFF4A65FF), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A65FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('登入',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE0F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDDE0F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4A65FF), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE24B4A))),
    );
  }
}