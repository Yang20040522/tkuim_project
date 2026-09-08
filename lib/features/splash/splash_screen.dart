import '../../core/platform/app_platform.dart';
// lib/features/splash/splash_screen.dart
import 'package:flutter/material.dart';
import '../account/app_session.dart';
import '../account/home_router.dart';
import '../account/role_select_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 先把上次登入狀態讀回來
    try {
      await AppSession.load();
    } catch (error, stack) {
      debugPrint('Session restore failed: $error\n$stack');
    }
    if (!mounted) return;

    // 維持原本 1.5 秒的 splash 顯示時間
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    _goNext();
  }

  void _goNext() {
    final role = AppSession.role;

    // 有登入紀錄 → 直接進對應身分的首頁;沒有 → 照原本流程去選身分
    final target = (AppSession.isLoggedIn && role != null)
        ? homeForRole(role)
        : const RoleSelectScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: AppPlatform.current.isTv
          ? const Text('RehabAssist TV', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold))
          : Image.asset(
          'assets/splash/splash.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}