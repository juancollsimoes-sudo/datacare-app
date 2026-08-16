import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../providers/sessions_providers.dart';
import '../../treatments/providers/treatments_providers.dart';
import '../../../rust/db/models.dart';

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
  
  PlatformInt64? _selectedTratamientoId;
  late TextEditingController _fechaController;
  late TextEditingController _notasController;
  late TextEditingController _productosController;
  late TextEditingController _precioController;
  bool _pagado = false;

  @override
  void initState() {
    super.initState();
    _selectedTratamientoId = widget.session?.tratamientoId;
    _fechaController = TextEditingController(
        text: widget.session?.fecha ?? DateTime.now().toIso8601String().split('T')[0]);
    _notasController = TextEditingController(text: widget.session?.notasSesion ?? '');
    _productosController = TextEditingController(text: widget.session?.productosUsados ?? '');
    _precioController = TextEditingController(text: widget.session?.precioCobrado?.toString() ?? '');
    _pagado = widget.session?.pagado ?? false;
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _notasController.dispose();
    _productosController.dispose();
    _precioController.dispose();
    super.dispose();
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
              treatmentsState.when(
                data: (treatments) {
                  return DropdownButtonFormField<PlatformInt64>(
                    decoration: const InputDecoration(labelText: 'Tratamiento'),
                    value: _selectedTratamientoId,
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
            ],
          ),
        ),
      ),
    );
  }
}
