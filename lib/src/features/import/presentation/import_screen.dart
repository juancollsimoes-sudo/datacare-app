import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../rust/api/import_api.dart';

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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User canceled
      }

      setState(() {
        _isLoading = true;
        _selectedFile = result.files.single.path;
      });

      final importResult = await importPacientesFromExcel(filePath: _selectedFile!);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Importación Completada'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total de filas procesadas: ${importResult.total}'),
                Text('Éxitos: ${importResult.exitos}', style: const TextStyle(color: Colors.green)),
                Text('Errores: ${importResult.errores}', style: const TextStyle(color: Colors.red)),
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
                  const Icon(Icons.file_upload, size: 64, color: Colors.blue),
                  const SizedBox(height: 24),
                  const Text(
                    'Importar desde Excel',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecciona un archivo .xlsx para importar pacientes.\nEl archivo debe tener las columnas:\nNombre, Apellido, Teléfono, Email, Notas.',
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
