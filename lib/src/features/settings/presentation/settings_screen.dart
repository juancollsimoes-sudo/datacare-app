import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Apariencia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Tema de la aplicación'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ThemeMode>(
                  value: themeMode,
                  onChanged: (ThemeMode? newMode) {
                    if (newMode != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(newMode);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Información de la Clínica',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.local_hospital),
            title: Text('Nombre de la Clínica'),
            subtitle: Text('DataCare Estética'),
          ),
          const ListTile(
            leading: Icon(Icons.location_on),
            title: Text('Dirección'),
            subtitle: Text('Av. Principal 123, Ciudad'),
          ),
          const ListTile(
            leading: Icon(Icons.phone),
            title: Text('Teléfono'),
            subtitle: Text('+1 234 567 8900'),
          ),
        ],
      ),
    );
  }
}
