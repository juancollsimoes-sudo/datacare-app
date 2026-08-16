import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:datacare/src/rust/api/backup_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;

  Future<void> _createBackup() async {
    final outputDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Seleccionar Carpeta para Copia de Seguridad',
    );

    if (outputDir == null) return;
    
    final outputPath = '$outputDir/datacare_backup.zip';

    setState(() => _isLoading = true);
    try {
      await createBackup(outputPath: outputPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copia de seguridad creada en: $outputPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear copia: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar Copia de Seguridad',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.isEmpty || result.single.path == null) return;
    final zipPath = result.single.path!;

    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Advertencia'),
        content: const Text(
            'Restaurar una copia de seguridad sobrescribirá todos los datos actuales. '
            'La aplicación deberá reiniciarse después de la restauración. ¿Estás seguro de que deseas continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.warning),
            label: const Text('Restaurar Datos'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await restoreBackup(zipPath: zipPath);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restauración Completada'),
            content: const Text('La copia de seguridad se ha restaurado correctamente. Por favor, reinicia la aplicación para aplicar los cambios.'),
            actions: [
              FilledButton(
                onPressed: () => exit(0),
                child: const Text('Cerrar Aplicación'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Copias de Seguridad'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.security, size: 100, color: Colors.blueGrey),
                    const SizedBox(height: 32),
                    Text(
                      'Protege tus datos',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Crea una copia de seguridad de tu base de datos y fotos, o restaura una copia anterior. Es recomendable hacer copias de seguridad periódicamente.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    FilledButton.icon(
                      onPressed: _createBackup,
                      icon: const Icon(Icons.download),
                      label: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Crear Copia de Seguridad', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _restoreBackup,
                      icon: const Icon(Icons.upload),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                      ),
                      label: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Restaurar Copia de Seguridad', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
