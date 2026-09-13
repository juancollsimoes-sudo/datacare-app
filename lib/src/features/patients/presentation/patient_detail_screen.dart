import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../../rust/api/pdf_api.dart';
import '../../../rust/db/models.dart';
import '../providers/patients_providers.dart';
import '../../sessions/providers/sessions_providers.dart';
import '../../photos/providers/photos_provider.dart';

class PatientDetailScreen extends ConsumerWidget {
  final String id;

  const PatientDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientId = PlatformInt64.parse(id);
    final patientAsync = ref.watch(patientDetailProvider(patientId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Paciente'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/patients'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar a PDF',
            onPressed: () async {
              try {
                final result = await file_picker.FilePicker.saveFile(bytes: Uint8List(0), 
                  dialogTitle: 'Guardar reporte',
                  fileName: 'reporte_paciente_$id.pdf',
                  allowedExtensions: ['pdf'],
                  type: file_picker.FileType.custom,
                );
                
                if (result != null) {
                  if (kIsWeb) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Los reportes no están disponibles en la versión web')),
                      );
                    }
                    return;
                  }

                  await apiGeneratePatientReport(pacienteId: patientId, outputPath: result.toFilePath());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDF generado exitosamente')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al generar PDF: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.monitor_weight_outlined),
            tooltip: 'Evolución Corporal',
            onPressed: () => context.push('/patients/$id/body-evolution'),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar',
            onPressed: () => context.go('/patients/$id/edit'),
          ),
          patientAsync.maybeWhen(
            data: (patient) => patient != null && patient.activo
                ? IconButton(
                    icon: const Icon(Icons.person_off),
                    tooltip: 'Desactivar',
                    onPressed: () => _confirmDeactivate(context, ref, patientId, '${patient.nombre} ${patient.apellido}'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (patient) {
          if (patient == null) {
            return const Center(child: Text('Paciente no encontrado'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;
              final col1 = Column(
                children: [
                  _buildPersonalInfoCard(context, patient),
                  const SizedBox(height: 16),
                  _buildClinicalInfoCard(context, patient),
                  const SizedBox(height: 16),
                  _buildFacialAspectCard(context, patient),
                ],
              );
              final col2 = Column(
                children: [
                  _buildCorporalEvolutionCard(context, ref, patientId),
                  const SizedBox(height: 16),
                  _buildSessionsCard(context, ref, patientId),
                  const SizedBox(height: 16),
                  _buildPatientGalleryCard(context, ref, patientId),
                ],
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: col1),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: col2),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          col1,
                          const SizedBox(height: 16),
                          col2,
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPersonalInfoCard(BuildContext context, dynamic patient) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${patient.nombre} ${patient.apellido}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _InfoRow(icon: Icons.calendar_today, label: 'Nacimiento', value: patient.fechaNacimiento ?? '-'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.phone, label: 'Teléfono', value: patient.telefono ?? '-'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.email, label: 'Email', value: patient.email ?? '-'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.location_on, label: 'Dirección', value: patient.direccion ?? '-'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.app_registration, label: 'Registro', value: patient.fechaRegistro.split('T').first),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.info_outline,
              label: 'Estado',
              value: patient.activo ? 'Activo' : 'Inactivo',
              valueColor: patient.activo ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalInfoCard(BuildContext context, dynamic patient) {
    final theme = Theme.of(context);
    final String? enf = patient.condicionesMedicas;
    final List<String> enfList = (enf != null && enf.trim().isNotEmpty)
        ? enf.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];

    final String? afec = patient.afeccionesCutaneas;
    final List<String> afecList = (afec != null && afec.trim().isNotEmpty)
        ? afec.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services_outlined, size: 24, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Datos Clínicos', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 28),

            // Enfermedades
            Text('Enfermedades Generales', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (enfList.isEmpty)
              const Text('Ninguna registrada', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: enfList.map((e) => Chip(
                  label: Text(e, style: const TextStyle(fontSize: 12)),
                  backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                  side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            const SizedBox(height: 16),

            // Afecciones dérmicas
            Text('Afecciones Dérmicas y/o Ojos', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (afecList.isEmpty)
              const Text('Ninguna registrada', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: afecList.map((a) => Chip(
                  label: Text(a, style: const TextStyle(fontSize: 12)),
                  backgroundColor: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
                  side: BorderSide(color: theme.colorScheme.tertiary.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            const SizedBox(height: 16),

            // Alergias
            _InfoCol(label: 'Alergias', value: patient.alergias),
            const SizedBox(height: 16),

            // Tatuajes & Cirugías Plásticas
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tatuajes', style: TextStyle(color: theme.colorScheme.outline, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          patient.tatuajes ?? 'No',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (patient.tatuajes?.toLowerCase().startsWith('s') ?? false)
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cirugía Plástica', style: TextStyle(color: theme.colorScheme.outline, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          patient.cirugiaPlastica ?? 'No',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (patient.cirugiaPlastica?.toLowerCase().startsWith('s') ?? false)
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Antecedentes
            if (patient.antecedentesMedicos != null && patient.antecedentesMedicos.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Antecedentes de Salud o Ginecológicos', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(patient.antecedentesMedicos, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFacialAspectCard(BuildContext context, dynamic patient) {
    final theme = Theme.of(context);

    final String? diagVis = patient.diagnosticoVisual;
    final List<String> visList = (diagVis != null && diagVis.trim().isNotEmpty)
        ? diagVis.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];

    final String? diagTac = patient.diagnosticoTactil;
    final List<String> tacList = (diagTac != null && diagTac.trim().isNotEmpty)
        ? diagTac.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];

    final String? tipoPiel = patient.tipoPiel;
    final List<String> pielList = (tipoPiel != null && tipoPiel.trim().isNotEmpty)
        ? tipoPiel.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.face_retouching_natural_outlined, size: 24, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Aspecto y Diagnóstico Facial', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 28),

            // Ubicación de lesiones
            if (patient.ubicacionLesiones != null && patient.ubicacionLesiones.trim().isNotEmpty) ...[
              Text('Ubicación de las Lesiones', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Text(patient.ubicacionLesiones, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
              ),
              const SizedBox(height: 16),
            ],

            // Tipo de Piel & Cicatrización
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tipo de Piel', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (pielList.isEmpty)
                        const Text('-', style: TextStyle(color: Colors.grey))
                      else
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: pielList.map((p) => Chip(
                            label: Text(p, style: const TextStyle(fontSize: 11)),
                            backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          )).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cicatrización', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (patient.cicatrizacion == null || patient.cicatrizacion.trim().isEmpty)
                        const Text('-', style: TextStyle(color: Colors.grey))
                      else
                        Chip(
                          label: Text(patient.cicatrizacion, style: const TextStyle(fontSize: 11)),
                          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Diagnóstico Visual
            Text('Diagnóstico Visual', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (visList.isEmpty)
              const Text('Ninguno registrado', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: visList.map((v) => Chip(
                  label: Text(v, style: const TextStyle(fontSize: 11)),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                )).toList(),
              ),
            const SizedBox(height: 16),

            // Diagnóstico Táctil
            Text('Diagnóstico Táctil', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (tacList.isEmpty)
              const Text('Ninguno registrado', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tacList.map((t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 11)),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                )).toList(),
              ),

            if (patient.notasGenerales != null && patient.notasGenerales.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _InfoCol(label: 'Notas Generales / Plan', value: patient.notasGenerales),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref, PlatformInt64 id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar Paciente'),
        content: Text('¿Estás seguro de que deseas desactivar a $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(patientsActionProvider).deactivate(id);
      if (context.mounted) {
        context.go('/patients');
      }
    }
  }

  Widget _buildCorporalEvolutionCard(BuildContext context, WidgetRef ref, PlatformInt64 patientId) {
    final corporalAsync = ref.watch(patientCorporalSessionsProvider(patientId));
    final theme = Theme.of(context);

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.monitor_weight_outlined, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Evolución Corporal',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Composición de masa corporal, grasa y medidas',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/patients/${patientId.toInt()}/body-evolution'),
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('Ver Progresión'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            corporalAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Text('Error al cargar mediciones corporales: $err'),
              data: (sessions) {
                final valid = sessions.where((s) {
                  final y = DateTime.tryParse(s.fecha)?.year;
                  if (y != null && y < 2010) return false;
                  return s.tipo == 'corporal' ||
                    s.grasaCorporal != null ||
                    s.peso != null ||
                    s.imc != null ||
                    s.medidaCadera != null;
                }).toList();

                if (valid.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No se tiene información de mediciones corporales para este paciente (únicamente realiza tratamientos faciales).',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                valid.sort((a, b) => a.fecha.compareTo(b.fecha));

                final lastFat = valid.reversed.firstWhereOrNull((s) => s.grasaCorporal != null);
                final firstFat = valid.firstWhereOrNull((s) => s.grasaCorporal != null);

                final lastWeight = valid.reversed.firstWhereOrNull((s) => s.peso != null && s.peso!.trim().isNotEmpty);
                final firstWeight = valid.firstWhereOrNull((s) => s.peso != null && s.peso!.trim().isNotEmpty);

                final lastImc = valid.reversed.firstWhereOrNull((s) => s.imc != null);
                final firstImc = valid.firstWhereOrNull((s) => s.imc != null);

                final latestSession = valid.last;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMiniStat(
                      context,
                      label: '% Grasa Actual',
                      value: lastFat?.grasaCorporal != null ? '${lastFat!.grasaCorporal!.toStringAsFixed(1)}%' : '-',
                      initialValue: firstFat?.grasaCorporal != null ? 'Inicial: ${firstFat!.grasaCorporal!.toStringAsFixed(1)}%' : null,
                    ),
                    _buildMiniStat(
                      context,
                      label: 'Peso Actual',
                      value: lastWeight?.peso ?? '-',
                      initialValue: firstWeight?.peso != null ? 'Inicial: ${firstWeight!.peso}' : null,
                    ),
                    _buildMiniStat(
                      context,
                      label: 'IMC Actual',
                      value: lastImc?.imc != null ? lastImc!.imc!.toStringAsFixed(1) : '-',
                      initialValue: firstImc?.imc != null ? 'Inicial: ${firstImc!.imc!.toStringAsFixed(1)}' : null,
                    ),
                    _buildMiniStat(
                      context,
                      label: 'Total Sesiones',
                      value: '${valid.length}',
                      initialValue: 'Última: ${latestSession.fecha.split('T')[0]}',
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, {required String label, required String value, String? initialValue}) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (initialValue != null) ...[
            const SizedBox(height: 2),
            Text(
              initialValue,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionsCard(BuildContext context, WidgetRef ref, PlatformInt64 patientId) {
    final sessionsState = ref.watch(patientSessionsProvider(patientId));
    final theme = Theme.of(context);

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Historial de Sesiones', 
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => context.push('/sessions/new/$patientId'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva Sesión'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            sessionsState.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const Text('No hay sesiones registradas para este paciente.');
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.items.length,
                  itemBuilder: (context, index) {
                    final sesion = data.items[index];
                    final isCorporal = sesion.tipo == 'corporal';

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCorporal
                              ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                              : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCorporal ? Icons.accessibility_new : Icons.face,
                          size: 20,
                          color: isCorporal ? theme.colorScheme.tertiary : theme.colorScheme.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text('Fecha: ${sesion.fecha}'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCorporal
                                  ? theme.colorScheme.tertiaryContainer
                                  : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCorporal ? 'Corporal' : 'Facial',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCorporal
                                    ? theme.colorScheme.onTertiaryContainer
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        isCorporal && (sesion.peso != null || sesion.grasaCorporal != null)
                            ? 'Peso: ${sesion.peso ?? '-'} | Grasa: ${sesion.grasaCorporal != null ? '${sesion.grasaCorporal}%' : '-'} | Cobrado: \$${sesion.precioCobrado?.toStringAsFixed(2) ?? '0.00'}'
                            : 'Cobrado: \$${sesion.precioCobrado?.toStringAsFixed(2) ?? '0.00'} | Pagado: ${sesion.pagado ? 'Sí' : 'No'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.push('/sessions/edit/$patientId', extra: sesion);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Text('Error al cargar sesiones: $err'),
            ),
          ],
        ),
      ),
    );
  }
}


class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
          ),
        ),
      ],
    );
  }
}

class _InfoCol extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoCol({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final text = value == null || value!.trim().isEmpty ? 'Ninguna' : value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 4),
        Text(text),
      ],
    );
  }
}

Widget _buildPatientGalleryCard(BuildContext context, WidgetRef ref, PlatformInt64 patientId) {
  final photosState = ref.watch(patientPhotosProvider(patientId));

  return Card(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Galería del Paciente', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          photosState.when(
            data: (photos) {
              if (photos.isEmpty) {
                return const Text('No hay fotografías asociadas a este paciente en ninguna sesión.');
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => _openUnifiedGallery(context, photos, index),
                        child: Hero(
                          tag: 'patient_${photo.id}',
                          child: kIsWeb 
                            ? Image.network(
                                Uri.base.resolve('/photos/${(photo.rutaThumb ?? photo.rutaFoto).split('photos/').last}').toString(),
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(photo.rutaThumb ?? photo.rutaFoto),
                                fit: BoxFit.cover,
                              ),
                        ),
                      ),
                      if (photo.tipo != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              photo.tipo!.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text('Error al cargar fotos: $err'),
          ),
        ],
      ),
    ),
  );
}

void _openUnifiedGallery(BuildContext context, List<FotoSesion> photos, int initialIndex) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Visor de fotos del paciente')),
        body: PhotoViewGallery.builder(
          itemCount: photos.length,
          builder: (context, index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: kIsWeb
                  ? NetworkImage(Uri.base.resolve('/photos/${photos[index].rutaFoto.split('photos/').last}').toString()) as ImageProvider
                  : FileImage(File(photos[index].rutaFoto)),
              initialScale: PhotoViewComputedScale.contained,
              heroAttributes: PhotoViewHeroAttributes(tag: 'patient_${photos[index].id}'),
            );
          },
          pageController: PageController(initialPage: initialIndex),
        ),
      ),
    ),
  );
}

extension _IterableExtensions<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
