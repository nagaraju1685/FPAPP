import 'package:flutter/material.dart';

class PlaceholderScaffold extends StatelessWidget {
  static const _primaryBlue = Color(0xFF2A3EDB);
  static const _darkNavy = Color(0xFF13205C);

  final String title;
  final IconData icon;
  final String message;

  const PlaceholderScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: _darkNavy,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: _primaryBlue),
              ),
              const SizedBox(height: 20),
              Text(
                '$title — coming soon',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _darkNavy),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
