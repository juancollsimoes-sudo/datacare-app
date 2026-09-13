import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../providers/patients_providers.dart';
import '../../../rust/db/models.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  final String? id; // if null -> create mode

  const PatientFormScreen({super.key, this.id});

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal Info Controllers
  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _telefonoController;
  late TextEditingController _emailController;
  late TextEditingController _direccionController;

  // Clinical Data Controllers & State
  static const List<String> _enfermedadesOptions = [
    'Diabetes',
    'Hepatitis',
    'Hipertensión',
    'Tabaquismo',
    'Alcoholismo',
    'Tiroides',
    'Cáncer',
  ];
  final Set<String> _selectedEnfermedades = {};
  late TextEditingController _otrasCondicionesController;

  static const List<String> _afeccionesOptions = [
    'Rosácea',
    'Acné',
    'Orzuelos',
    'Dermatitis',
    'Alergia Ocular',
  ];
  final Set<String> _selectedAfecciones = {};
  late TextEditingController _rosaceaNotaController;

  late TextEditingController _alergiasController;
  String _tatuajes = 'No';
  String _cirugiaPlastica = 'No';
  late TextEditingController _antecedentesController;

  // Facial Aspect Controllers & State
  late TextEditingController _ubicacionLesionesController;

  static const List<String> _tipoPielOptions = [
    'Normal',
    'Mixta',
    'Seca',
    'Grasa',
    'Alípida (deshidratada)',
  ];
  final Set<String> _selectedTipoPiel = {};

  static const List<String> _cicatrizacionOptions = [
    'Normal',
    'Hipertrófica',
    'Atrófica',
    'Queloide',
  ];
  String? _selectedCicatrizacion;

  static const List<String> _diagVisualOptions = [
    'Discromías',
    'Brillos',
    'Arrugas tenues',
    'Arrugas profundas',
    'Flacidez muscular',
    'Falta de tono',
    'Poros dilatados',
    'Aspecto cuarteado',
    'Milliums',
  ];
  final Set<String> _selectedDiagVisual = {};

  static const List<String> _diagTactilOptions = [
    'Tacto rugoso',
    'Tacto irregular',
    'Deshidratación',
    'Seca deshidratada',
  ];
  final Set<String> _selectedDiagTactil = {};

  // General Notes Controller
  late TextEditingController _notasController;

  DateTime? _fechaNacimiento;
  bool _isLoading = false;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _apellidoController = TextEditingController();
    _telefonoController = TextEditingController();
    _emailController = TextEditingController();
    _direccionController = TextEditingController();

    _otrasCondicionesController = TextEditingController();
    _rosaceaNotaController = TextEditingController();
    _alergiasController = TextEditingController();
    _antecedentesController = TextEditingController();

    _ubicacionLesionesController = TextEditingController();
    _notasController = TextEditingController();

    if (widget.id == null) {
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();

    _otrasCondicionesController.dispose();
    _rosaceaNotaController.dispose();
    _alergiasController.dispose();
    _antecedentesController.dispose();

    _ubicacionLesionesController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _loadPatient(Paciente paciente) async {
    _nombreController.text = paciente.nombre;
    _apellidoController.text = paciente.apellido;
    _telefonoController.text = paciente.telefono ?? '';
    _emailController.text = paciente.email ?? '';
    _direccionController.text = paciente.direccion ?? '';
    _notasController.text = paciente.notasGenerales ?? '';
    _alergiasController.text = paciente.alergias ?? '';
    _antecedentesController.text = paciente.antecedentesMedicos ?? '';
    _ubicacionLesionesController.text = paciente.ubicacionLesiones ?? '';

    _tatuajes = (paciente.tatuajes?.toLowerCase().startsWith('s') ?? false) ? 'Sí' : 'No';
    _cirugiaPlastica = (paciente.cirugiaPlastica?.toLowerCase().startsWith('s') ?? false) ? 'Sí' : 'No';

    // Parse condiciones médicas (Enfermedades)
    _selectedEnfermedades.clear();
    final List<String> otherCond = [];
    if (paciente.condicionesMedicas != null && paciente.condicionesMedicas!.isNotEmpty) {
      final items = paciente.condicionesMedicas!.split(',').map((s) => s.trim());
      for (final it in items) {
        final match = _enfermedadesOptions.firstWhereOrNull(
          (opt) => opt.toLowerCase() == it.toLowerCase() ||
                   (it.toLowerCase().contains('hiperten') && opt == 'Hipertensión') ||
                   (it.toLowerCase().contains('diabet') && opt == 'Diabetes') ||
                   (it.toLowerCase().contains('tiroid') && opt == 'Tiroides') ||
                   (it.toLowerCase().contains('cancer') && opt == 'Cáncer') ||
                   (it.toLowerCase().contains('hepatit') && opt == 'Hepatitis') ||
                   (it.toLowerCase().contains('tabaqu') && opt == 'Tabaquismo') ||
                   (it.toLowerCase().contains('alcohol') && opt == 'Alcoholismo'),
        );
        if (match != null) {
          _selectedEnfermedades.add(match);
        } else if (it.isNotEmpty) {
          otherCond.add(it);
        }
      }
    }
    _otrasCondicionesController.text = otherCond.join(', ');

    // Parse afecciones dérmicas
    _selectedAfecciones.clear();
    _rosaceaNotaController.clear();
    if (paciente.afeccionesCutaneas != null && paciente.afeccionesCutaneas!.isNotEmpty) {
      final items = paciente.afeccionesCutaneas!.split(',').map((s) => s.trim());
      for (final it in items) {
        if (it.toLowerCase().contains('rosác') || it.toLowerCase().contains('rosac')) {
          _selectedAfecciones.add('Rosácea');
          final paren = RegExp(r'\((.*?)\)').firstMatch(it);
          if (paren != null) {
            _rosaceaNotaController.text = paren.group(1)?.trim() ?? '';
          }
        } else {
          final match = _afeccionesOptions.firstWhereOrNull(
            (opt) => opt.toLowerCase() == it.toLowerCase() ||
                     (it.toLowerCase().contains('acn') && opt == 'Acné') ||
                     (it.toLowerCase().contains('orzuel') && opt == 'Orzuelos') ||
                     (it.toLowerCase().contains('dermatit') && opt == 'Dermatitis') ||
                     (it.toLowerCase().contains('ocul') && opt == 'Alergia Ocular'),
          );
          if (match != null) {
            _selectedAfecciones.add(match);
          }
        }
      }
    }

    // Parse tipo de piel
    _selectedTipoPiel.clear();
    if (paciente.tipoPiel != null && paciente.tipoPiel!.isNotEmpty) {
      final items = paciente.tipoPiel!.split(',').map((s) => s.trim());
      for (final it in items) {
        final match = _tipoPielOptions.firstWhereOrNull(
          (opt) => opt.toLowerCase() == it.toLowerCase() ||
                   (it.toLowerCase().contains('mixt') && opt == 'Mixta') ||
                   (it.toLowerCase().contains('gras') && opt == 'Grasa') ||
                   (it.toLowerCase().contains('sec') && opt == 'Seca') ||
                   (it.toLowerCase().contains('normal') && opt == 'Normal') ||
                   (it.toLowerCase().contains('alipid') && opt == 'Alípida (deshidratada)'),
        );
        if (match != null) {
          _selectedTipoPiel.add(match);
        }
      }
    }

    // Parse cicatrización
    if (paciente.cicatrizacion != null && paciente.cicatrizacion!.isNotEmpty) {
      final val = paciente.cicatrizacion!.trim().toLowerCase();
      _selectedCicatrizacion = _cicatrizacionOptions.firstWhereOrNull(
        (opt) => opt.toLowerCase() == val ||
                 (val.contains('normal') && opt == 'Normal') ||
                 (val.contains('hipertrof') && opt == 'Hipertrófica') ||
                 (val.contains('atrof') && opt == 'Atrófica') ||
                 (val.contains('queloide') && opt == 'Queloide'),
      );
    }

    // Parse diagnóstico visual
    _selectedDiagVisual.clear();
    if (paciente.diagnosticoVisual != null && paciente.diagnosticoVisual!.isNotEmpty) {
      final items = paciente.diagnosticoVisual!.split(',').map((s) => s.trim());
      for (final it in items) {
        final match = _diagVisualOptions.firstWhereOrNull(
          (opt) => opt.toLowerCase() == it.toLowerCase() ||
                   (it.toLowerCase().contains('discrom') && opt == 'Discromías') ||
                   (it.toLowerCase().contains('brillo') && opt == 'Brillos') ||
                   (it.toLowerCase().contains('tenue') && opt == 'Arrugas tenues') ||
                   (it.toLowerCase().contains('profund') && opt == 'Arrugas profundas') ||
                   (it.toLowerCase().contains('flacide') && opt == 'Flacidez muscular') ||
                   (it.toLowerCase().contains('tono') && opt == 'Falta de tono') ||
                   (it.toLowerCase().contains('poro') && opt == 'Poros dilatados') ||
                   (it.toLowerCase().contains('cuartead') && opt == 'Aspecto cuarteado') ||
                   (it.toLowerCase().contains('mili') && opt == 'Milliums') ||
                   (it.toLowerCase().contains('milli') && opt == 'Milliums'),
        );
        if (match != null) {
          _selectedDiagVisual.add(match);
        }
      }
    }

    // Parse diagnóstico táctil
    _selectedDiagTactil.clear();
    if (paciente.diagnosticoTactil != null && paciente.diagnosticoTactil!.isNotEmpty) {
      final items = paciente.diagnosticoTactil!.split(',').map((s) => s.trim());
      for (final it in items) {
        final match = _diagTactilOptions.firstWhereOrNull(
          (opt) => opt.toLowerCase() == it.toLowerCase() ||
                   (it.toLowerCase().contains('rugos') && opt == 'Tacto rugoso') ||
                   (it.toLowerCase().contains('irregula') && opt == 'Tacto irregular') ||
                   (it.toLowerCase().contains('seca') && opt == 'Seca deshidratada') ||
                   (it.toLowerCase().contains('deshidrat') && opt == 'Deshidratación'),
        );
        if (match != null) {
          _selectedDiagTactil.add(match);
        }
      }
    }

    if (paciente.fechaNacimiento != null && paciente.fechaNacimiento!.isNotEmpty) {
      _fechaNacimiento = DateTime.tryParse(paciente.fechaNacimiento!);
    }
    setState(() {
      _isInit = true;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final actionProvider = ref.read(patientsActionProvider);
      final String? fn = _fechaNacimiento != null
          ? '${_fechaNacimiento!.year.toString().padLeft(4, '0')}-${_fechaNacimiento!.month.toString().padLeft(2, '0')}-${_fechaNacimiento!.day.toString().padLeft(2, '0')}'
          : null;

      String? nullableStr(String val) => val.trim().isEmpty ? null : val.trim();

      // Build condiciones médicas string
      final List<String> enfList = [..._selectedEnfermedades];
      if (_otrasCondicionesController.text.trim().isNotEmpty) {
        enfList.add(_otrasCondicionesController.text.trim());
      }
      final String? condicionesMedicas = enfList.isEmpty ? null : enfList.join(', ');

      // Build afecciones cutáneas string
      final List<String> afecList = [];
      for (final a in _selectedAfecciones) {
        if (a == 'Rosácea' && _rosaceaNotaController.text.trim().isNotEmpty) {
          afecList.add('Rosácea (${_rosaceaNotaController.text.trim()})');
        } else {
          afecList.add(a);
        }
      }
      final String? afeccionesCutaneas = afecList.isEmpty ? null : afecList.join(', ');

      final String? tipoPiel = _selectedTipoPiel.isEmpty ? null : _selectedTipoPiel.join(', ');
      final String? cicatrizacion = _selectedCicatrizacion;
      final String? diagVisual = _selectedDiagVisual.isEmpty ? null : _selectedDiagVisual.join(', ');
      final String? diagTactil = _selectedDiagTactil.isEmpty ? null : _selectedDiagTactil.join(', ');
      final String? ubicacionLesiones = nullableStr(_ubicacionLesionesController.text);
      final String? antecedentesMedicos = nullableStr(_antecedentesController.text);
      final String? alergias = nullableStr(_alergiasController.text);
      final String? notasGenerales = nullableStr(_notasController.text);

      if (widget.id == null) {
        // Create
        final p = NuevoPaciente(
          nombre: _nombreController.text.trim(),
          apellido: _apellidoController.text.trim(),
          fechaNacimiento: fn,
          telefono: nullableStr(_telefonoController.text),
          email: nullableStr(_emailController.text),
          direccion: nullableStr(_direccionController.text),
          notasGenerales: notasGenerales,
          alergias: alergias,
          condicionesMedicas: condicionesMedicas,
          afeccionesCutaneas: afeccionesCutaneas,
          tatuajes: _tatuajes,
          cirugiaPlastica: _cirugiaPlastica,
          antecedentesMedicos: antecedentesMedicos,
          ubicacionLesiones: ubicacionLesiones,
          tipoPiel: tipoPiel,
          cicatrizacion: cicatrizacion,
          diagnosticoVisual: diagVisual,
          diagnosticoTactil: diagTactil,
        );
        await actionProvider.addPatient(p);
      } else {
        // Update
        final p = ActualizarPaciente(
          id: PlatformInt64.parse(widget.id!),
          nombre: _nombreController.text.trim(),
          apellido: _apellidoController.text.trim(),
          fechaNacimiento: fn,
          telefono: nullableStr(_telefonoController.text),
          email: nullableStr(_emailController.text),
          direccion: nullableStr(_direccionController.text),
          notasGenerales: notasGenerales,
          alergias: alergias,
          condicionesMedicas: condicionesMedicas,
          afeccionesCutaneas: afeccionesCutaneas,
          tatuajes: _tatuajes,
          cirugiaPlastica: _cirugiaPlastica,
          antecedentesMedicos: antecedentesMedicos,
          ubicacionLesiones: ubicacionLesiones,
          tipoPiel: tipoPiel,
          cicatrizacion: cicatrizacion,
          diagnosticoVisual: diagVisual,
          diagnosticoTactil: diagTactil,
        );
        await actionProvider.editPatient(p);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.id == null ? 'Paciente creado con éxito' : 'Paciente actualizado con éxito')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && !_isInit) {
      final patientAsync = ref.watch(patientDetailProvider(PlatformInt64.parse(widget.id!)));

      return patientAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, st) => Scaffold(body: Center(child: Text('Error: $err'))),
        data: (patient) {
          if (patient == null) return const Scaffold(body: Center(child: Text('Paciente no encontrado')));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadPatient(patient);
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      );
    }

    final isEdit = widget.id != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Paciente' : 'Nuevo Paciente'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. INFORMACIÓN PERSONAL
              _buildSectionCard(
                context,
                title: 'Información Personal',
                icon: Icons.person_outline,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _apellidoController,
                          decoration: const InputDecoration(labelText: 'Apellido *', border: OutlineInputBorder()),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha de Nacimiento',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today, size: 20),
                            ),
                            child: Text(
                              _fechaNacimiento != null
                                  ? '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}'
                                  : 'Seleccionar...',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _telefonoController,
                          decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              if (!val.contains('@')) return 'Email inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _direccionController,
                          decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. DATOS CLÍNICOS
              _buildSectionCard(
                context,
                title: 'Datos Clínicos',
                subtitle: 'Enfermedades generales, afecciones cutáneas y antecedentes médicos',
                icon: Icons.medical_services_outlined,
                children: [
                  Text('Enfermedades Generales', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _enfermedadesOptions.map((enf) {
                      final selected = _selectedEnfermedades.contains(enf);
                      return FilterChip(
                        label: Text(enf),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedEnfermedades.add(enf);
                            } else {
                              _selectedEnfermedades.remove(enf);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otrasCondicionesController,
                    decoration: const InputDecoration(
                      labelText: 'Otras Enfermedades o Condiciones Médicas',
                      border: OutlineInputBorder(),
                      hintText: 'Otras patologías relevantes...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  Text('Afecciones Dérmicas y/o Ojos', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _afeccionesOptions.map((afec) {
                      final selected = _selectedAfecciones.contains(afec);
                      return FilterChip(
                        label: Text(afec),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedAfecciones.add(afec);
                            } else {
                              _selectedAfecciones.remove(afec);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_selectedAfecciones.contains('Rosácea')) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rosaceaNotaController,
                      decoration: const InputDecoration(
                        labelText: 'Detalle / Gravedad de Rosácea',
                        border: OutlineInputBorder(),
                        hintText: 'ej. Grave, Leve, Moderada, Posible...',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _alergiasController,
                    decoration: const InputDecoration(
                      labelText: 'Alergias (¿Cuáles?)',
                      border: OutlineInputBorder(),
                      hintText: 'Medicamentos, cosméticos, alimentos, etc.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Tatuajes & Cirugías Plásticas
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('¿Se ha realizado algún tatuaje?', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'No', label: Text('No')),
                                ButtonSegment(value: 'Sí', label: Text('Sí')),
                              ],
                              selected: {_tatuajes},
                              onSelectionChanged: (val) => setState(() => _tatuajes = val.first),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('¿Se ha realizado cirugía plástica?', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'No', label: Text('No')),
                                ButtonSegment(value: 'Sí', label: Text('Sí')),
                              ],
                              selected: {_cirugiaPlastica},
                              onSelectionChanged: (val) => setState(() => _cirugiaPlastica = val.first),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _antecedentesController,
                    decoration: const InputDecoration(
                      labelText: 'Antecedentes Importantes de Salud o Ginecológicos',
                      border: OutlineInputBorder(),
                      hintText: 'ej. Histerectomía, menopausia, intervenciones previas...',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. ASPECTO DEL PACIENTE (DIAGNÓSTICO FACIAL)
              _buildSectionCard(
                context,
                title: 'Aspecto del Paciente',
                subtitle: 'Diagnóstico facial visual y táctil, tipo de piel y cicatrización',
                icon: Icons.face_retouching_natural_outlined,
                children: [
                  TextFormField(
                    controller: _ubicacionLesionesController,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación de las Lesiones',
                      border: OutlineInputBorder(),
                      hintText: 'ej. Cicatrices de acné en mejillas laterales, manchas solares en frente...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  Text('Tipo de Piel', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tipoPielOptions.map((tipo) {
                      final selected = _selectedTipoPiel.contains(tipo);
                      return FilterChip(
                        label: Text(tipo),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedTipoPiel.add(tipo);
                            } else {
                              _selectedTipoPiel.remove(tipo);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  Text('Cicatrización', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cicatrizacionOptions.map((cic) {
                      final selected = _selectedCicatrizacion == cic;
                      return ChoiceChip(
                        label: Text(cic),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            _selectedCicatrizacion = sel ? cic : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  Text('Diagnóstico Visual', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _diagVisualOptions.map((diag) {
                      final selected = _selectedDiagVisual.contains(diag);
                      return FilterChip(
                        label: Text(diag),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedDiagVisual.add(diag);
                            } else {
                              _selectedDiagVisual.remove(diag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  Text('Diagnóstico Táctil', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _diagTactilOptions.map((diag) {
                      final selected = _selectedDiagTactil.contains(diag);
                      return FilterChip(
                        label: Text(diag),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedDiagTactil.add(diag);
                            } else {
                              _selectedDiagTactil.remove(diag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 4. NOTAS GENERALES
              _buildSectionCard(
                context,
                title: 'Notas Generales',
                subtitle: 'Observaciones generales, plan terapéutico y hábitos',
                icon: Icons.notes_outlined,
                children: [
                  TextFormField(
                    controller: _notasController,
                    decoration: const InputDecoration(
                      labelText: 'Notas / Hábitos Cosméticos / Plan',
                      border: OutlineInputBorder(),
                      hintText: 'Cualquier detalle o preferencia adicional...',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => context.pop(),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Guardar Cambios' : 'Crear Paciente'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
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
