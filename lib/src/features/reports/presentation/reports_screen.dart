import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:datacare/src/rust/db/models.dart';
import 'package:datacare/src/core/api/api_provider.dart';

final patientsReportProvider = FutureProvider<List<Paciente>>((ref) async {
  final api = ref.read(apiClientProvider);
  final result = await api.listPacientes(page: 1, pageSize: 1000);
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
  bool _isGeneratingAccounting = false;
  DateTime _selectedAccountingDate = DateTime.now();

  static const List<String> _monthNames = [
    '',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  Future<void> _generatePdf() async {
    if (_selectedPatient == null) return;

    setState(() => _isGenerating = true);
    try {
      final api = ref.read(apiClientProvider);
      final pdfBytes = await api.generatePatientReportBytes(
        pacienteId: _selectedPatient!.id,
      );

      final safeName = '${_selectedPatient!.nombre}_${_selectedPatient!.apellido}'
          .replaceAll(RegExp(r'[^\w\-]'), '_');
      final outputFileUri = await FilePicker.saveFile(
        bytes: Uint8List.fromList(pdfBytes),
        dialogTitle: 'Guardar reporte PDF de paciente',
        fileName: 'reporte_$safeName.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFileUri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte PDF de paciente guardado exitosamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Future<void> _generateAccountingClosingPdf() async {
    setState(() => _isGeneratingAccounting = true);
    try {
      final api = ref.read(apiClientProvider);
      final year = _selectedAccountingDate.year;
      final month = _selectedAccountingDate.month;
      final pdfBytes = await api.generateAccountingReportBytes(
        year: year,
        month: month,
      );

      final monthPadded = month.toString().padLeft(2, '0');
      final fileName = 'cierre_contable_${year}_$monthPadded.pdf';
      final outputFileUri = await FilePicker.saveFile(
        bytes: Uint8List.fromList(pdfBytes),
        dialogTitle: 'Guardar Cierre Contable en PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFileUri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cierre contable de ${_monthNames[month]} $year guardado en PDF.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar cierre contable: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAccounting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsReportProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes y Cierres PDF'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Generar Reporte Clínico de Paciente',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    patientsAsync.when(
                      data: (patients) {
                        return DropdownButtonFormField<Paciente>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Paciente',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _selectedPatient,
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
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: (_selectedPatient != null && !_isGenerating) ? _generatePdf : null,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_isGenerating ? 'Generando...' : 'Generar Reporte PDF de Paciente'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Cierre Contable Mensual en PDF',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Exporta el cierre contable del mes incluyendo ingresos por paciente, gastos operativos, renglón de gastos personales totalizado y saldo neto.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              _selectedAccountingDate = DateTime(
                                _selectedAccountingDate.year,
                                _selectedAccountingDate.month - 1,
                              );
                            });
                          },
                        ),
                        Text(
                          '${_monthNames[_selectedAccountingDate.month]} ${_selectedAccountingDate.year}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              _selectedAccountingDate = DateTime(
                                _selectedAccountingDate.year,
                                _selectedAccountingDate.month + 1,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: !_isGeneratingAccounting ? _generateAccountingClosingPdf : null,
                      icon: _isGeneratingAccounting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(
                        _isGeneratingAccounting
                            ? 'Generando PDF...'
                            : 'Exportar Cierre Contable PDF',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


