import 'package:flutter/material.dart';
import '../../../shared/widgets/placeholder_screen.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Pacientes',
      icon: Icons.people,
    );
  }
}
