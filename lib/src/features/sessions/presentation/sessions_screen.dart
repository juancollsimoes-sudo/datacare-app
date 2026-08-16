import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesiones'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Para gestionar sesiones, ve a la sección de Pacientes y selecciona un paciente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/patients'),
              child: const Text('Ir a Pacientes'),
            )
          ],
        ),
      ),
    );
  }
}
