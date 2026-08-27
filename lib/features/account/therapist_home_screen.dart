// lib/features/account/therapist_home_screen.dart
// 治療師端佔位畫面,功能待開發。
import 'package:flutter/material.dart';

import 'app_session.dart';
import 'role_select_screen.dart';

class TherapistHomeScreen extends StatelessWidget {
  const TherapistHomeScreen({super.key});

  void _logout(BuildContext context) async {
    await AppSession.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '治療師',
                    style: TextStyle(
                      color: Color(0xFF1A1D2E),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _logout(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE24B4A),
                    ),
                    child: const Text('登出'),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.medical_services_outlined,
                  color: Color(0xFF9CA3AF), size: 48),
              const SizedBox(height: 16),
              const Text(
                '治療師端建置中',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '登入流程已可運作,功能待後續開發',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}