import 'package:flutter/material.dart';
import '../../../shared/widgets/placeholder_screen.dart';

class PatientDetailScreen extends StatelessWidget {
  final String id;
  const PatientDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Detalle Paciente $id',
      icon: Icons.person,
    );
  }
}
