import 'package:flutter/material.dart';
import '../../../shared/widgets/placeholder_screen.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Importar Datos',
      icon: Icons.upload,
    );
  }
}
