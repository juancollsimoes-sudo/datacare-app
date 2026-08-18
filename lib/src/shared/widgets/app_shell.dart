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
                decoration: const BoxDecoration(color: Color(0xFF1A1B3A)),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Sweet Care Spa',
                        style: TextStyle(
                          color: Color(0xFFD4B896),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'by Susana Simoes',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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
                  selectedColor: const Color(0xFFC77D9C),
                  selectedTileColor: const Color(0xFFC77D9C).withOpacity(0.08),
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
          Container(
            color: const Color(0xFF1A1B3A),
            child: NavigationRail(
              extended: _isExtended,
              backgroundColor: Colors.transparent,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onDestinationSelected(index, context),
              selectedIconTheme: const IconThemeData(color: Color(0xFFC77D9C)),
              unselectedIconTheme: const IconThemeData(color: Colors.white70),
              indicatorColor: const Color(0xFF252745),
              destinations: destinations.indexed.map((entry) {
                final (i, d) = entry;
                final isSelected = i == selectedIndex;
                return NavigationRailDestination(
                  icon: Icon(d.$1),
                  selectedIcon: Icon(d.$2),
                  label: Text(d.$3, style: TextStyle(color: isSelected ? const Color(0xFFC77D9C) : Colors.white70)),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
