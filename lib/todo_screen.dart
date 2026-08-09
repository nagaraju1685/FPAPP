import 'package:flutter/material.dart';

import 'placeholder_scaffold.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Todo',
      icon: Icons.checklist_outlined,
      message: 'View and edit your todo list here soon.',
    );
  }
}
