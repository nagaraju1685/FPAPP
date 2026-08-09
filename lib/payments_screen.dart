import 'package:flutter/material.dart';

import 'placeholder_scaffold.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Payments',
      icon: Icons.payments_outlined,
      message: 'View your monthly payments here soon.',
    );
  }
}
