// lib/features/account/therapist_register_screen.dart
//
// 治療端專用註冊頁(空殼,尚未接後端)。
// UI 比照病人端 register_screen.dart,但呼叫 TherapistAccountService
// (本機儲存),完全獨立於病人端帳號系統。

import 'package:flutter/material.dart';

import 'app_session.dart';
import 'home_router.dart';
import 'therapist_account_service.dart';
import 'user_role.dart';

class TherapistRegisterScreen extends StatefulWidget {
  const TherapistRegisterScreen({super.key});

  @override
  State<TherapistRegisterScreen> createState() =>
      _TherapistRegisterScreenState();
}

class _TherapistRegisterScreenState extends State<TherapistRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _service = TherapistAccountService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? v) =>
      (v == null || v.trim().isEmpty) ? '請輸入姓名' : null;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return '請輸入電子郵件';
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\-\.]+$');
    if (!emailRegex.hasMatch(v.trim())) return '電子郵件格式不正確';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return '請輸入密碼';
    if (v.length < 6) return '密碼至少需要 6 個字元';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (v == null || v.isEmpty) return '請再次輸入密碼';
    if (v != _passwordController.text) return '兩次輸入的密碼不一致';
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final error = await _service.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showError(error);
      return;
    }

    await AppSession.save(
      role: UserRole.therapist,
      userId: 'local-${_emailController.text.trim().hashCode}',
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
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
                  '治療師註冊',
                  style: TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '目前為本機測試帳號,尚未串接雲端後端',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                const SizedBox(height: 32),
                _label('姓名'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: _decoration('你的姓名', Icons.person_outline),
                  validator: _validateName,
                ),
                const SizedBox(height: 20),
                _label('電子郵件'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      _decoration('example@email.com', Icons.mail_outline),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 20),
                _label('密碼'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _decoration(
                    '至少 6 個字元',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 20),
                _label('確認密碼'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _decoration(
                    '再次輸入密碼',
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: _validateConfirmPassword,
                  onFieldSubmitted: (_) => _handleRegister(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
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
                        : const Text('註冊',
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

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFF1A1D2E),
          fontSize: 13,
          fontWeight: FontWeight.w700));

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