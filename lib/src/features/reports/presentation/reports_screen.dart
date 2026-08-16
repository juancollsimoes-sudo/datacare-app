import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datacare/src/rust/api/db_api.dart';
import 'package:datacare/src/rust/api/pdf_api.dart';
import 'package:datacare/src/rust/db/models.dart';
import 'package:file_picker/file_picker.dart';

final patientsReportProvider = FutureProvider<List<Paciente>>((ref) async {
  final result = await listPacientes(page: 1, pageSize: 1000);
  return result.items;
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Paciente? _selectedPatient;
  bool _isGenerating = false;

  Future<void> _generatePdf() async {
    if (_selectedPatient == null) return;
    
    setState(() => _isGenerating = true);
    try {
      final outputFileUri = await FilePicker.saveFile(
        bytes: Uint8List(0),
        dialogTitle: 'Guardar reporte PDF',
        fileName: 'reporte_${_selectedPatient!.nombre}_${_selectedPatient!.apellido}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFileUri != null) {
        final outputPath = outputFileUri.toFilePath();
        await apiGeneratePatientReport(
          pacienteId: _selectedPatient!.id,
          outputPath: outputPath,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reporte guardado en: $outputPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar reporte: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generar Reporte de Paciente',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            patientsAsync.when(
              data: (patients) {
                return DropdownButton<Paciente>(
                  isExpanded: true,
                  hint: const Text('Seleccionar Paciente'),
                  value: _selectedPatient,
                  items: patients.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text('${p.nombre} ${p.apellido}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedPatient = val;
                    });
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error al cargar pacientes: $err'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: (_selectedPatient != null && !_isGenerating) ? _generatePdf : null,
              icon: _isGenerating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isGenerating ? 'Generando...' : 'Generar Reporte PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

