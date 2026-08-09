import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financial_planner/main.dart';

void main() {
  testWidgets('Login screen shows title and fields', (WidgetTester tester) async {
    await tester.pumpWidget(const FinancialPlannerApp());

    expect(find.text('Financial Planner'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
