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
          const ListTile(
            title: Text(
              'Apariencia',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Tema de la aplicación'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              onChanged: (ThemeMode? newMode) {
                if (newMode != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newMode);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Sistema'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Claro'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Oscuro'),
                ),
              ],
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'Información de la Clínica',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
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
