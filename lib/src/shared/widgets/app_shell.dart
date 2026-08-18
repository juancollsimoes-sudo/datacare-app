import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isExtended = true;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/patients')) return 1;
    if (location.startsWith('/sessions')) return 2;
    if (location.startsWith('/treatments')) return 3;
    if (location.startsWith('/import')) return 4;
    if (location.startsWith('/reports')) return 5;
    if (location.startsWith('/backup')) return 6;
    if (location.startsWith('/settings')) return 7;
    return 0; // default to Home
  }

  void _onDestinationSelected(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/patients');
        break;
      case 2:
        context.go('/sessions');
        break;
      case 3:
        context.go('/treatments');
        break;
      case 4:
        context.go('/import');
        break;
      case 5:
        context.go('/reports');
        break;
      case 6:
        context.go('/backup');
        break;
      case 7:
        context.go('/settings');
        break;
    }
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Pacientes';
      case 2:
        return 'Sesiones';
      case 3:
        return 'Tratamientos';
      case 4:
        return 'Importar';
      case 5:
        return 'Reportes';
      case 6:
        return 'Backups';
      case 7:
        return 'Configuración';
      default:
        return 'DataCare';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final title = _getTitle(selectedIndex);
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    final destinations = const [
      (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      (Icons.people_outline, Icons.people, 'Pacientes'),
      (Icons.calendar_month_outlined, Icons.calendar_month, 'Sesiones'),
      (Icons.spa_outlined, Icons.spa, 'Tratamientos'),
      (Icons.upload_file_outlined, Icons.upload, 'Importar'),
      (Icons.description_outlined, Icons.description, 'Reportes'),
      (Icons.backup_outlined, Icons.backup, 'Backups'),
      (Icons.settings_outlined, Icons.settings, 'Configuración'),
    ];

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sweet Care Spa',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by Susana Simoes',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (int i = 0; i < destinations.length; i++)
                ListTile(
                  leading: Icon(selectedIndex == i ? destinations[i].$2 : destinations[i].$1),
                  title: Text(destinations[i].$3),
                  selected: selectedIndex == i,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                  onTap: () {
                    Navigator.pop(context);
                    _onDestinationSelected(i, context);
                  },
                ),
            ],
          ),
        ),
        body: widget.child,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              _isExtended = !_isExtended;
            });
          },
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: _isExtended,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onDestinationSelected(index, context),
            destinations: destinations.indexed.map((entry) {
              final (i, d) = entry;
              return NavigationRailDestination(
                icon: Icon(d.$1),
                selectedIcon: Icon(d.$2),
                label: Text(d.$3),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
