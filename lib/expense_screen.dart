import 'package:flutter/material.dart';

import 'placeholder_scaffold.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Daily Expense',
      icon: Icons.receipt_long_outlined,
      message: 'View and add daily expenses here soon.',
    );
  }
}
