import "dart:typed_data";
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import '../../../rust/api/pdf_api.dart';
import '../providers/patients_providers.dart';
import '../../sessions/providers/sessions_providers.dart';
import '../../../rust/db/models.dart';


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
                  await apiGeneratePatientReport(pacienteId: patientId, outputPath: result);
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildPersonalInfoCard(context, patient),
                      const SizedBox(height: 16),
                      _buildClinicalInfoCard(context, patient),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSessionsCard(context, ref, patientId),
                      const SizedBox(height: 16),
                      // Placeholder para galería de fotos
                      Card(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Galería de Fotos (Próximamente)', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 16),
                              const Text('Aquí se mostrará la galería fotográfica en la Etapa 6.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Información Clínica', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 32),
            _InfoCol(label: 'Alergias', value: patient.alergias),
            const SizedBox(height: 16),
            _InfoCol(label: 'Condiciones Médicas', value: patient.condicionesMedicas),
            const SizedBox(height: 16),
            _InfoCol(label: 'Notas Generales', value: patient.notasGenerales),
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

  Widget _buildSessionsCard(BuildContext context, WidgetRef ref, PlatformInt64 patientId) {
    final sessionsState = ref.watch(patientSessionsProvider(patientId));

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
                Text('Historial de Sesiones', style: Theme.of(context).textTheme.titleLarge),
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
                    return ListTile(
                      title: Text('Fecha: ${sesion.fecha}'),
                      subtitle: Text('Cobrado: \$${sesion.precioCobrado?.toStringAsFixed(2) ?? '0.00'} | Pagado: ${sesion.pagado ? 'Sí' : 'No'}'),
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
