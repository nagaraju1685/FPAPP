import 'package:flutter/material.dart';

import 'splash_screen.dart';

void main() {
  runApp(const FinancialPlannerApp());
}

class FinancialPlannerApp extends StatelessWidget {
  const FinancialPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
