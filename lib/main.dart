import 'package:flutter/material.dart';

import 'api_client.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';
import 'splash_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  ApiClient.onSessionExpired = () async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(welcomeMessage: 'Session expired. Please sign in again.'),
      ),
      (route) => false,
    );
  };

  ApiClient.onAccountLocked = () async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      (route) => false,
    );
  };

  runApp(const FinancialPlannerApp());
}

class FinancialPlannerApp extends StatelessWidget {
  const FinancialPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Financial Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2A3EDB),
      ),
      home: const SplashScreen(),
    );
  }
}
