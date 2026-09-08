import 'core/platform/app_platform.dart';
import 'core/ui/tv_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ← 新增
//import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/notification/notification_service.dart';
import 'core/ui/app_theme.dart';
import 'features/call/zego_call_invitation_service.dart';

import 'package:provider/provider.dart';
import 'services/history_service.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppPlatform.configure();
  await SystemChrome.setPreferredOrientations(AppPlatform.current.isTv
      ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
      : [DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await initializeOptionalNotifications(capabilities: AppPlatform.current,
      initialize: () => NotificationService().init());
  if (AppPlatform.current.supportsVideoCalls) {
  ZegoCallInvitationService.instance
    ..setNavigatorKey(rootNavigatorKey)
    ..setScaffoldMessengerKey(rootScaffoldMessengerKey);
  }
  //runApp(const RehabAssistApp());
  runApp(
    ChangeNotifierProvider.value(
      value: HistoryService(),
      child: const RehabAssistApp(),
    ),
  );
}

class RehabAssistApp extends StatelessWidget {
  const RehabAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'RehabAssist',
      debugShowCheckedModeBanner: false,
      // ↓ 新增這三塊
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'TW'),
      // ↑ 新增結束
      theme: AppPlatform.current.isTv ? tvTheme() : AppTheme.light,
      builder: (context, child) => AppPlatform.current.isTv
          ? TvRemoteScope(child: child!) : child!,
      //home: const HomeScreen(),
      home: const SplashScreen(),
    );
  }
}
