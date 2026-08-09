import 'package:flutter/material.dart';

import 'api_client.dart';
import 'landing_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      ApiClient.restoreSession(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
    final username = results[0] as String?;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => username != null
            ? LandingScreen(username: username)
            : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1440), Color(0xFF1B2A6B)],
          ),
        ),
        child: const Center(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(28)),
            child: Image(
              image: AssetImage('icon.png'),
              width: 140,
              height: 140,
            ),
          ),
        ),
      ),
    );
  }
}
