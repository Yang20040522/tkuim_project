import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Existing splash/logout route. The backend-confirmed role now determines
/// the destination; the user no longer preselects patient or therapist.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) => const LoginScreen();
}
