import 'package:flutter/material.dart';
import '../../../shared/widgets/placeholder_screen.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Backups',
      icon: Icons.backup,
    );
  }
}
