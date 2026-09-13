import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import '../providers/patients_providers.dart';
import '../../sessions/providers/sessions_providers.dart';
import '../../../rust/db/models.dart';

class PatientBodyEvolutionScreen extends ConsumerStatefulWidget {
  final String patientId;

  const PatientBodyEvolutionScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientBodyEvolutionScreen> createState() => _PatientBodyEvolutionScreenState();
}

enum MetricType {
  grasaCorporal('Grasa Corporal', '%', Icons.pie_chart_outline),
  peso('Peso', 'kg', Icons.scale_outlined),
  imc('IMC', '', Icons.speed_outlined),
  aguaCorporal('Agua Corporal', '%', Icons.water_drop_outlined);

  final String label;
  final String unit;
  final IconData icon;
  const MetricType(this.label, this.unit, this.icon);
}

class _PatientBodyEvolutionScreenState extends ConsumerState<PatientBodyEvolutionScreen> {
  MetricType _selectedMetric = MetricType.grasaCorporal;

  double? _extractNumeric(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final cleaned = val.split(RegExp(r'[/–-]')).first.replaceAll(',', '.').trim();
    return double.tryParse(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final pId = PlatformInt64.parse(widget.patientId);
    final patientAsync = ref.watch(patientDetailProvider(pId));
    final sessionsAsync = ref.watch(patientCorporalSessionsProvider(pId));

    return Scaffold(
      appBar: AppBar(
        title: patientAsync.maybeWhen(
          data: (p) => Text(
            p != null ? 'Evolución Corporal — ${p.nombre} ${p.apellido}' : 'Evolución Corporal',
          ),
          orElse: () => const Text('Evolución Corporal'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(patientCorporalSessionsProvider(pId)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => context.push('/sessions/new/${widget.patientId}'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva Medición'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error al cargar mediciones: $err')),
        data: (sessions) {
          // Filter sessions that have at least one corporal measurement
          final validSessions = sessions.where((s) {
            final y = DateTime.tryParse(s.fecha)?.year;
            if (y != null && y < 2010) return false;
            return s.tipo == 'corporal' ||
                s.grasaCorporal != null ||
                s.peso != null ||
                s.imc != null ||
                s.aguaCorporal != null ||
                s.medidaCadera != null ||
                s.medidaCintura != null;
          }).toList();

          if (validSessions.isEmpty) {
            return _buildEmptyState(context);
          }

          // Sort chronologically ascending for progression
          validSessions.sort((a, b) => a.fecha.compareTo(b.fecha));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI summary cards
                _buildKpiSummaryGrid(context, validSessions),
                const SizedBox(height: 24),

                // Chart Section
                _buildChartCard(context, validSessions),
                const SizedBox(height: 24),

                // Complete Measurement Table
                _buildHistoryTableCard(context, validSessions),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.monitor_weight_outlined,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No se tiene información',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Este paciente no tiene registros de mediciones corporales.\n'
                  'Es posible que únicamente realice tratamientos o sesiones faciales.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.push('/sessions/new/${widget.patientId}'),
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar Primera Medición Corporal'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiSummaryGrid(BuildContext context, List<Sesion> sessions) {
    // For each metric, find the latest session with that measurement and the initial one
    final lastFatSession = sessions.reversed.firstWhereOrNull((s) => s.grasaCorporal != null);
    final firstFatSession = sessions.firstWhereOrNull((s) => s.grasaCorporal != null);
    final currentFat = lastFatSession?.grasaCorporal;
    final initialFat = firstFatSession?.grasaCorporal;
    final diffFat = (currentFat != null && initialFat != null) ? currentFat - initialFat : null;

    final lastWeightSession = sessions.reversed.firstWhereOrNull((s) => s.peso != null && s.peso!.trim().isNotEmpty);
    final firstWeightSession = sessions.firstWhereOrNull((s) => s.peso != null && s.peso!.trim().isNotEmpty);
    final currentWeightNum = _extractNumeric(lastWeightSession?.peso);
    final initialWeightNum = _extractNumeric(firstWeightSession?.peso);
    final diffWeight = (currentWeightNum != null && initialWeightNum != null) ? currentWeightNum - initialWeightNum : null;

    final lastImcSession = sessions.reversed.firstWhereOrNull((s) => s.imc != null);
    final firstImcSession = sessions.firstWhereOrNull((s) => s.imc != null);
    final currentImc = lastImcSession?.imc;
    final initialImc = firstImcSession?.imc;
    final diffImc = (currentImc != null && initialImc != null) ? currentImc - initialImc : null;

    final lastWaterSession = sessions.reversed.firstWhereOrNull((s) => s.aguaCorporal != null);
    final firstWaterSession = sessions.firstWhereOrNull((s) => s.aguaCorporal != null);
    final currentWater = lastWaterSession?.aguaCorporal;
    final initialWater = firstWaterSession?.aguaCorporal;
    final diffWater = (currentWater != null && initialWater != null) ? currentWater - initialWater : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1000 ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);
        final double aspectRatio = constraints.maxWidth >= 1200
            ? 1.6
            : (constraints.maxWidth >= 1000
                ? 1.35
                : (constraints.maxWidth >= 600 ? 1.75 : 2.5));

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: [
            _buildKpiCard(
              context,
              title: '% Grasa Corporal',
              value: currentFat != null ? '${currentFat.toStringAsFixed(1)}%' : 'N/D',
              subtitle: initialFat != null ? 'Inicial: ${initialFat.toStringAsFixed(1)}%' : null,
              diff: diffFat,
              unit: '%',
              isLowerBetter: true,
              icon: Icons.pie_chart_outline,
            ),
            _buildKpiCard(
              context,
              title: 'Peso Corporal',
              value: lastWeightSession?.peso ?? (currentWeightNum != null ? '${currentWeightNum.toStringAsFixed(1)} kg' : 'N/D'),
              subtitle: firstWeightSession?.peso != null ? 'Inicial: ${firstWeightSession!.peso}' : null,
              diff: diffWeight,
              unit: ' kg',
              isLowerBetter: true,
              icon: Icons.scale_outlined,
            ),
            _buildKpiCard(
              context,
              title: 'Índice Masa Corporal (IMC)',
              value: currentImc != null ? currentImc.toStringAsFixed(1) : 'N/D',
              subtitle: initialImc != null ? 'Inicial: ${initialImc.toStringAsFixed(1)}' : null,
              diff: diffImc,
              unit: '',
              isLowerBetter: true,
              icon: Icons.speed_outlined,
            ),
            _buildKpiCard(
              context,
              title: '% Agua Corporal',
              value: currentWater != null ? '${currentWater.toStringAsFixed(1)}%' : 'N/D',
              subtitle: initialWater != null ? 'Inicial: ${initialWater.toStringAsFixed(1)}%' : null,
              diff: diffWater,
              unit: '%',
              isLowerBetter: false, // Higher water is usually better hydration
              icon: Icons.water_drop_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    String? subtitle,
    double? diff,
    required String unit,
    required bool isLowerBetter,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    Color badgeColor = theme.colorScheme.onSurfaceVariant;
    IconData? badgeIcon;
    String badgeText = '';

    if (diff != null && diff.abs() > 0.01) {
      final isGood = isLowerBetter ? diff < 0 : diff > 0;
      badgeColor = isGood ? Colors.green : Colors.orange;
      badgeIcon = diff < 0 ? Icons.arrow_downward : Icons.arrow_upward;
      badgeText = '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}$unit';
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 18, color: theme.colorScheme.primary),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                if (badgeIcon != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 14, color: badgeColor),
                        Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (subtitle != null)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, List<Sesion> sessions) {
    final theme = Theme.of(context);

    // Extract spots according to selected metric
    final List<FlSpot> spots = [];
    final List<String> dateLabels = [];

    for (int i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      double? val;
      switch (_selectedMetric) {
        case MetricType.grasaCorporal:
          val = s.grasaCorporal;
          break;
        case MetricType.peso:
          val = _extractNumeric(s.peso);
          break;
        case MetricType.imc:
          val = s.imc;
          break;
        case MetricType.aguaCorporal:
          val = s.aguaCorporal;
          break;
      }

      if (val != null) {
        spots.add(FlSpot(spots.length.toDouble(), val));
        dateLabels.add(s.fecha);
      }
    }

    double minY = spots.isNotEmpty ? spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) : 0;
    double maxY = spots.isNotEmpty ? spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) : 100;

    final paddingY = (maxY - minY) * 0.2;
    minY = (minY - paddingY).clamp(0, 500);
    maxY = maxY + paddingY;
    if (maxY <= minY) maxY = minY + 10;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progresión de Masa Corporal en el Tiempo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visualiza la evolución cronológica del paciente sesión a sesión',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                // Metric Selector SegmentedButton with horizontal scroll protection
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<MetricType>(
                    segments: MetricType.values.map((m) {
                      return ButtonSegment<MetricType>(
                        value: m,
                        label: Text(m.label),
                        icon: Icon(m.icon, size: 16),
                      );
                    }).toList(),
                    selected: {_selectedMetric},
                    onSelectionChanged: (set) {
                      setState(() {
                        _selectedMetric = set.first;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (spots.isEmpty)
              const SizedBox(
                height: 260,
                child: Center(
                  child: Text('No hay datos suficientes para graficar esta métrica.'),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: Padding(
                  padding: const EdgeInsets.only(right: 24.0, left: 8.0, bottom: 8.0),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: (spots.length / 6).clamp(1, 50).toDouble(),
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < dateLabels.length) {
                                final d = dateLabels[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    d,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (val, meta) {
                              return Text(
                                '${val.toStringAsFixed(1)}${_selectedMetric.unit}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: theme.colorScheme.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: spots.length <= 40,
                            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                              radius: 4,
                              color: theme.colorScheme.primary,
                              strokeWidth: 2,
                              strokeColor: theme.colorScheme.surface,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.primary.withValues(alpha: 0.35),
                                theme.colorScheme.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => theme.colorScheme.secondary,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.spotIndex;
                              final date = idx < dateLabels.length ? dateLabels[idx] : '';
                              return LineTooltipItem(
                                '$date\n${spot.y.toStringAsFixed(1)} ${_selectedMetric.unit}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTableCard(BuildContext context, List<Sesion> sessions) {
    final theme = Theme.of(context);
    // Reverse for table so newest is on top
    final reversedSessions = sessions.reversed.toList();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial Completo de Mediciones',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sessions.length} registros corporales ordenados del más reciente al más antiguo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/sessions/new/${widget.patientId}'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar Registro'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Sesión / Detalle')),
                  DataColumn(label: Text('Peso (kg)')),
                  DataColumn(label: Text('IMC')),
                  DataColumn(label: Text('% Grasa')),
                  DataColumn(label: Text('% Agua')),
                  DataColumn(label: Text('Cintura')),
                  DataColumn(label: Text('Cadera')),
                  DataColumn(label: Text('Brazos')),
                  DataColumn(label: Text('Pecho/Busto')),
                  DataColumn(label: Text('Piernas')),
                  DataColumn(label: Text('Acción')),
                ],
                rows: reversedSessions.map((s) {
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        s.fecha,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )),
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            s.notasSesion ?? 'Sesión Corporal',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(s.peso ?? '-')),
                      DataCell(Text(s.imc != null ? s.imc!.toStringAsFixed(1) : '-')),
                      DataCell(
                        Text(
                          s.grasaCorporal != null ? '${s.grasaCorporal!.toStringAsFixed(1)}%' : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      DataCell(Text(s.aguaCorporal != null ? '${s.aguaCorporal!.toStringAsFixed(1)}%' : '-')),
                      DataCell(Text(s.medidaCintura ?? '-')),
                      DataCell(Text(s.medidaCadera ?? '-')),
                      DataCell(Text(s.medidaBrazos ?? '-')),
                      DataCell(Text(s.medidaPecho ?? '-')),
                      DataCell(Text(s.medidaPiernas ?? '-')),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Editar Sesión',
                          onPressed: () {
                            context.push('/sessions/edit/${s.pacienteId}', extra: s);
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _IterableExtensions<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
