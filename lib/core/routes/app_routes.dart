import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:tripgenie/features/auth/screens/splash_screen.dart';
import 'package:tripgenie/features/auth/screens/login_screen.dart';
import 'package:tripgenie/features/home/screens/main_navigation.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const MainNavigation(),
      ),
    ],
  );
}