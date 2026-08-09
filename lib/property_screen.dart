import 'package:flutter/material.dart';

import 'placeholder_scaffold.dart';

class PropertyScreen extends StatelessWidget {
  const PropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Property',
      icon: Icons.home_work_outlined,
      message: 'View and manage your properties here soon.',
    );
  }
}
