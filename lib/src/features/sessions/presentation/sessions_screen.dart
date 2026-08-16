import 'package:flutter/material.dart';
import '../../../shared/widgets/placeholder_screen.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Sesiones',
      icon: Icons.calendar_month,
    );
  }
}
