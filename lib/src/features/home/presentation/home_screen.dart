import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_providers.dart';
import '../../../core/services/auto_updater_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AutoUpdaterService.checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(dashboardStatsProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Text(
                'Resumen',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                alignment: WrapAlignment.start,
                children: [
                  _buildStatCard(
                    context,
                    title: 'Pacientes Activos',
                    value: stats.totalPacientesActivos.toString(),
                    icon: Icons.people,
                    index: 0,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Sesiones este Mes',
                    value: stats.sesionesEsteMes.toString(),
                    icon: Icons.calendar_today,
                    index: 1,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Tratamientos',
                    value: stats.tratamientosRegistrados.toString(),
                    icon: Icons.medical_services,
                    index: 2,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Aquí podrías agregar más secciones del dashboard en el futuro
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error al cargar los datos',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.refresh(dashboardStatsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required int index,
  }) {
    final theme = Theme.of(context);

    // Determine colors based on card index
    final Color containerColor;
    final Color iconColor;
    switch (index) {
      case 0: // Pacientes
        containerColor = theme.colorScheme.primaryContainer;
        iconColor = theme.colorScheme.primary;
        break;
      case 1: // Sesiones
        containerColor = theme.colorScheme.tertiaryContainer;
        iconColor = theme.colorScheme.tertiary;
        break;
      case 2: // Tratamientos
        containerColor = theme.colorScheme.secondaryContainer;
        iconColor = theme.colorScheme.secondary;
        break;
      default:
        containerColor = theme.colorScheme.primaryContainer;
        iconColor = theme.colorScheme.primary;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
