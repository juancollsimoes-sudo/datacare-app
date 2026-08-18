import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../rust/api/import_api.dart';
import '../../patients/providers/patients_providers.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _isLoading = false;
  String? _selectedFile;

  Future<void> _pickAndImport() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result.isEmpty || result.first.path == null) {
        return; // User canceled
      }

      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La importación no está disponible en la versión web')),
          );
        }
        return;
      }

      setState(() {
        _isLoading = true;
        _selectedFile = result.first.path;
      });

      final importResult = await importPacientesFromExcel(filePath: _selectedFile!);

      // Refresh providers so the new patients show up in the list and dashboard
      ref.read(patientsProvider.notifier).refresh();
      // Also invalidate stats if you have a dashboard provider (optional, we can just invalidate the patients)

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Importación Completada'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _resultRow(Icons.people, 'Pacientes procesados', '${importResult.total}', null),
                _resultRow(Icons.check_circle, 'Pacientes importados', '${importResult.exitos}', Colors.green),
                _resultRow(Icons.event_note, 'Sesiones importadas', '${importResult.sesionesCreadas}', Colors.blue),
                _resultRow(Icons.people_outline, 'Duplicados (omitidos)', '${importResult.duplicados}', Colors.orange),
                _resultRow(Icons.error_outline, 'Errores', '${importResult.errores}', Colors.red),
                if (importResult.detalle.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Detalle de errores:'),
                  Container(
                    height: 100,
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: Text(importResult.detalle, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _resultRow(IconData icon, String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Pacientes'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_upload_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 24),
                  Text('Importar desde Excel', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecciona los archivos Excel (.xlsx) de historias clínicas\npara importar pacientes y sus sesiones a DataCare.\n\nCada hoja del Excel se importará como un paciente.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: _pickAndImport,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Seleccionar Archivo Excel'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  if (_selectedFile != null && !_isLoading) ...[
                    const SizedBox(height: 16),
                    Text('Último archivo procesado: ${_selectedFile!.split('/').last}'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
