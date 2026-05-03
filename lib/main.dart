import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Wanderland/core/theme/app_theme.dart';
import 'package:Wanderland/core/routes/app_routes.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locking to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Make status bar transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const WanderlandApp());
}

class WanderlandApp extends StatelessWidget {
  const WanderlandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Wanderland',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRoutes.router,
    );
  }
}