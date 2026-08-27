// lib/features/account/home_router.dart
// 依身分決定登入後的主畫面:病人 → HomeScreen,治療師 → 佔位畫面。
import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import 'therapist_home_screen.dart';
import 'user_role.dart';

Widget homeForRole(UserRole role) {
  switch (role) {
    case UserRole.therapist:
      return const TherapistHomeScreen();
    case UserRole.patient:
      return const HomeScreen();
  }
}