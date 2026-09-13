import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../providers/sessions_providers.dart';
import '../../treatments/providers/treatments_providers.dart';
import '../../../rust/db/models.dart';
import '../../photos/presentation/session_gallery_widget.dart' as import_photos;

class SessionFormScreen extends ConsumerStatefulWidget {
  final PlatformInt64 patientId;
  final Sesion? session;

  const SessionFormScreen({
    super.key,
    required this.patientId,
    this.session,
  });

  @override
  ConsumerState<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends ConsumerState<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _tipo = 'facial';
  PlatformInt64? _selectedTratamientoId;
  late TextEditingController _fechaController;
  late TextEditingController _notasController;
  late TextEditingController _productosController;
  late TextEditingController _precioController;
  bool _pagado = false;

  // Corporal measurement controllers
  late TextEditingController _pesoController;
  late TextEditingController _alturaController;
  late TextEditingController _imcController;
  late TextEditingController _grasaController;
  late TextEditingController _aguaController;
  late TextEditingController _caderaController;
  late TextEditingController _cinturaController;
  late TextEditingController _brazosController;
  late TextEditingController _pechoController;
  late TextEditingController _piernasController;

  @override
  void initState() {
    super.initState();
    _tipo = widget.session?.tipo ?? 'facial';
    _selectedTratamientoId = widget.session?.tratamientoId;
    _fechaController = TextEditingController(
        text: widget.session?.fecha ?? DateTime.now().toIso8601String().split('T')[0]);
    _notasController = TextEditingController(text: widget.session?.notasSesion ?? '');
    _productosController = TextEditingController(text: widget.session?.productosUsados ?? '');
    _precioController = TextEditingController(text: widget.session?.precioCobrado?.toString() ?? '');
    _pagado = widget.session?.pagado ?? false;

    _pesoController = TextEditingController(text: widget.session?.peso ?? '');
    _alturaController = TextEditingController(text: widget.session?.altura?.toString() ?? '');
    _imcController = TextEditingController(text: widget.session?.imc?.toString() ?? '');
    _grasaController = TextEditingController(text: widget.session?.grasaCorporal?.toString() ?? '');
    _aguaController = TextEditingController(text: widget.session?.aguaCorporal?.toString() ?? '');
    _caderaController = TextEditingController(text: widget.session?.medidaCadera ?? '');
    _cinturaController = TextEditingController(text: widget.session?.medidaCintura ?? '');
    _brazosController = TextEditingController(text: widget.session?.medidaBrazos ?? '');
    _pechoController = TextEditingController(text: widget.session?.medidaPecho ?? '');
    _piernasController = TextEditingController(text: widget.session?.medidaPiernas ?? '');
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _notasController.dispose();
    _productosController.dispose();
    _precioController.dispose();

    _pesoController.dispose();
    _alturaController.dispose();
    _imcController.dispose();
    _grasaController.dispose();
    _aguaController.dispose();
    _caderaController.dispose();
    _cinturaController.dispose();
    _brazosController.dispose();
    _pechoController.dispose();
    _piernasController.dispose();
    super.dispose();
  }

  void _calculateImc() {
    final pesoText = _pesoController.text.trim();
    final alturaText = _alturaController.text.trim();
    if (pesoText.isEmpty || alturaText.isEmpty) return;

    final firstPart = pesoText.split(RegExp(r'[/–-]')).first.replaceAll(',', '.').trim();
    final pesoNum = double.tryParse(firstPart);
    final alturaNum = double.tryParse(alturaText.replaceAll(',', '.'));

    if (pesoNum != null && alturaNum != null && alturaNum > 0) {
      final imc = pesoNum / (alturaNum * alturaNum);
      setState(() {
        _imcController.text = imc.toStringAsFixed(1);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _fechaController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _saveSession() async {
    if (!_formKey.currentState!.validate()) return;

    final actionProvider = ref.read(sessionsActionProvider);
    final fecha = _fechaController.text.trim();
    final notas = _notasController.text.trim().isEmpty ? null : _notasController.text.trim();
    final productos = _productosController.text.trim().isEmpty ? null : _productosController.text.trim();
    final precioText = _precioController.text.trim();
    final precio = precioText.isNotEmpty ? double.parse(precioText) : null;

    final isCorporal = _tipo == 'corporal';
    final peso = isCorporal && _pesoController.text.trim().isNotEmpty ? _pesoController.text.trim() : null;
    final altura = isCorporal && _alturaController.text.trim().isNotEmpty ? double.tryParse(_alturaController.text.trim().replaceAll(',', '.')) : null;
    final imc = isCorporal && _imcController.text.trim().isNotEmpty ? double.tryParse(_imcController.text.trim().replaceAll(',', '.')) : null;
    final grasa = isCorporal && _grasaController.text.trim().isNotEmpty ? double.tryParse(_grasaController.text.trim().replaceAll(',', '.')) : null;
    final agua = isCorporal && _aguaController.text.trim().isNotEmpty ? double.tryParse(_aguaController.text.trim().replaceAll(',', '.')) : null;
    final cadera = isCorporal && _caderaController.text.trim().isNotEmpty ? _caderaController.text.trim() : null;
    final cintura = isCorporal && _cinturaController.text.trim().isNotEmpty ? _cinturaController.text.trim() : null;
    final brazos = isCorporal && _brazosController.text.trim().isNotEmpty ? _brazosController.text.trim() : null;
    final pecho = isCorporal && _pechoController.text.trim().isNotEmpty ? _pechoController.text.trim() : null;
    final piernas = isCorporal && _piernasController.text.trim().isNotEmpty ? _piernasController.text.trim() : null;

    try {
      if (widget.session == null) {
        final nueva = NuevaSesion(
          pacienteId: widget.patientId,
          tratamientoId: _selectedTratamientoId,
          fecha: fecha,
          notasSesion: notas,
          productosUsados: productos,
          precioCobrado: precio,
          pagado: _pagado,
          tipo: _tipo,
          peso: peso,
          altura: altura,
          imc: imc,
          grasaCorporal: grasa,
          aguaCorporal: agua,
          medidaCadera: cadera,
          medidaCintura: cintura,
          medidaBrazos: brazos,
          medidaPecho: pecho,
          medidaPiernas: piernas,
        );
        await actionProvider.addSession(nueva);
      } else {
        final actualizar = ActualizarSesion(
          id: widget.session!.id,
          tratamientoId: _selectedTratamientoId,
          fecha: fecha,
          notasSesion: notas,
          productosUsados: productos,
          precioCobrado: precio,
          pagado: _pagado,
          tipo: _tipo,
          peso: peso,
          altura: altura,
          imc: imc,
          grasaCorporal: grasa,
          aguaCorporal: agua,
          medidaCadera: cadera,
          medidaCintura: cintura,
          medidaBrazos: brazos,
          medidaPecho: pecho,
          medidaPiernas: piernas,
        );
        await actionProvider.editSession(actualizar, widget.patientId);
      }
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión guardada exitosamente.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.session != null;
    final treatmentsState = ref.watch(treatmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Sesión' : 'Nueva Sesión'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tipo de Sesión',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'facial',
                              icon: Icon(Icons.face),
                              label: Text('Facial'),
                            ),
                            ButtonSegment<String>(
                              value: 'corporal',
                              icon: Icon(Icons.accessibility_new),
                              label: Text('Corporal (Masa y Medidas)'),
                            ),
                          ],
                          selected: {_tipo},
                          onSelectionChanged: (newSelection) {
                            setState(() {
                              _tipo = newSelection.first;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fechaController,
                decoration: const InputDecoration(
                  labelText: 'Fecha (YYYY-MM-DD) *',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Este campo es requerido'
                    : null,
              ),
              const SizedBox(height: 16),
              if (_tipo == 'corporal') ...[
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.monitor_weight_outlined, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Evaluación y Medición Corporal',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Masa corporal, grasa, agua y medidas anatómicas',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Composición Corporal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _pesoController,
                                decoration: const InputDecoration(
                                  labelText: 'Peso (kg)',
                                  hintText: 'Ej: 64.5 o 64.5/64.0',
                                  prefixIcon: Icon(Icons.scale),
                                ),
                                onChanged: (_) => _calculateImc(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _alturaController,
                                decoration: const InputDecoration(
                                  labelText: 'Altura (m)',
                                  hintText: 'Ej: 1.63',
                                  prefixIcon: Icon(Icons.height),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => _calculateImc(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _imcController,
                                decoration: const InputDecoration(
                                  labelText: 'IMC (Índice Masa Corporal)',
                                  hintText: 'Ej: 24.3',
                                  prefixIcon: Icon(Icons.speed),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: _calculateImc,
                              icon: const Icon(Icons.calculate, size: 18),
                              label: const Text('Calcular'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _grasaController,
                                decoration: const InputDecoration(
                                  labelText: 'Grasa Corporal (%)',
                                  hintText: 'Ej: 28.6',
                                  prefixIcon: Icon(Icons.pie_chart_outline),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _aguaController,
                                decoration: const InputDecoration(
                                  labelText: 'Agua Corporal (%)',
                                  hintText: 'Ej: 49.0',
                                  prefixIcon: Icon(Icons.water_drop_outlined),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text('Medidas Anatómicas (cm)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cinturaController,
                                decoration: const InputDecoration(
                                  labelText: 'Cintura (cm)',
                                  hintText: 'Ej: 70 o 70/69',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _caderaController,
                                decoration: const InputDecoration(
                                  labelText: 'Cadera (cm)',
                                  hintText: 'Ej: 101 o 98/97',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _brazosController,
                                decoration: const InputDecoration(
                                  labelText: 'Brazos (cm)',
                                  hintText: 'Ej: 27 o 26/25.5',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _pechoController,
                                decoration: const InputDecoration(
                                  labelText: 'Pecho / Busto (cm)',
                                  hintText: 'Ej: 89 o 38/37.5',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _piernasController,
                          decoration: const InputDecoration(
                            labelText: 'Piernas (cm)',
                            hintText: 'Ej: 55 o 46/46',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              treatmentsState.when(
                data: (treatments) {
                  return DropdownButtonFormField<PlatformInt64>(
                    decoration: const InputDecoration(labelText: 'Tratamiento'),
                    initialValue: _selectedTratamientoId,
                    items: [
                      const DropdownMenuItem<PlatformInt64>(
                        value: null,
                        child: Text('Ninguno / Personalizado'),
                      ),
                      ...treatments.map((t) {
                        return DropdownMenuItem<PlatformInt64>(
                          value: t.id,
                          child: Text(t.nombre),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedTratamientoId = val;
                        if (val != null) {
                          // Auto-fill price
                          final t = treatments.firstWhere((element) => element.id == val);
                          if (t.precio != null && _precioController.text.isEmpty) {
                            _precioController.text = t.precio.toString();
                          }
                        }
                      });
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (err, stack) => Text('Error al cargar tratamientos: $err'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notasController,
                decoration: const InputDecoration(labelText: 'Notas de la sesión'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _productosController,
                decoration: const InputDecoration(labelText: 'Productos Usados'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _precioController,
                decoration: const InputDecoration(labelText: 'Precio Cobrado'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('¿Pagado?'),
                value: _pagado,
                onChanged: (val) => setState(() => _pagado = val),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveSession,
                child: const Text('Guardar'),
              ),
              if (isEditing) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                import_photos.SessionGalleryWidget(
                  sessionId: widget.session!.id,
                  pacienteId: widget.patientId,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
