import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tripgenie/core/theme/app_theme.dart';
import 'package:tripgenie/core/routes/app_routes.dart';
import 'package:tripgenie/core/services/app_data_reset_service.dart';
import 'package:tripgenie/core/services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env) — REQUIRED for Groq, OpenTripMap, etc.
  await dotenv.load(fileName: ".env");

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

  // Purge local state if requested (development aid)
  if (!kIsWeb) {
    await AppDataResetService.purgeLocalStateIfRequested();
  }

  // Initialize local notifications
  await NotificationService.initialize();

  // Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode');
  if (isDark != null) {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  runApp(const WanderlandApp());
}

class WanderlandApp extends StatelessWidget {
  const WanderlandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp.router(
          title: 'Wanderland',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          routerConfig: AppRoutes.router,
        );
      },
    );
  }
}
