import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/notification/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await NotificationService().init();
  runApp(const RehabAssistApp());
}

class RehabAssistApp extends StatelessWidget {
  const RehabAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RehabAssist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A65FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      //home: const HomeScreen(),
      home: const SplashScreen(),
    );
  }
}