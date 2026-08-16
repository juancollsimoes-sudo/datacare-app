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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Pacientes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: Text('Sesiones'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.spa_outlined),
                selectedIcon: Icon(Icons.spa),
                label: Text('Tratamientos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.upload_file_outlined),
                selectedIcon: Icon(Icons.upload),
                label: Text('Importar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: Text('Reportes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.backup_outlined),
                selectedIcon: Icon(Icons.backup),
                label: Text('Backups'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Configuración'),
              ),
            ],
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
