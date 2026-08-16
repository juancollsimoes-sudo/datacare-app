import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../providers/treatments_providers.dart';
import '../../../rust/db/models.dart';

class TreatmentFormScreen extends ConsumerStatefulWidget {
  final Tratamiento? treatment;

  const TreatmentFormScreen({super.key, this.treatment});

  @override
  ConsumerState<TreatmentFormScreen> createState() => _TreatmentFormScreenState();
}

class _TreatmentFormScreenState extends ConsumerState<TreatmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  late TextEditingController _duracionController;
  late TextEditingController _precioController;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.treatment?.nombre ?? '');
    _descripcionController = TextEditingController(text: widget.treatment?.descripcion ?? '');
    _duracionController = TextEditingController(text: widget.treatment?.duracionMin?.toString() ?? '');
    _precioController = TextEditingController(text: widget.treatment?.precio?.toString() ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _duracionController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _saveTreatment() async {
    if (!_formKey.currentState!.validate()) return;

    final actionProvider = ref.read(treatmentsActionProvider);
    final nombre = _nombreController.text.trim();
    final descripcion = _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim();
    final duracionText = _duracionController.text.trim();
    final precioText = _precioController.text.trim();

    final duracion = duracionText.isNotEmpty ? PlatformInt64.parse(duracionText) : null;
    final precio = precioText.isNotEmpty ? double.parse(precioText) : null;

    try {
      if (widget.treatment == null) {
        final nuevo = NuevoTratamiento(
          nombre: nombre,
          descripcion: descripcion,
          duracionMin: duracion,
          precio: precio,
        );
        await actionProvider.addTreatment(nuevo);
      } else {
        final actualizar = ActualizarTratamiento(
          id: widget.treatment!.id,
          nombre: nombre,
          descripcion: descripcion,
          duracionMin: duracion,
          precio: precio,
        );
        await actionProvider.editTreatment(actualizar);
      }
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tratamiento guardado exitosamente.')),
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
    final isEditing = widget.treatment != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tratamiento' : 'Nuevo Tratamiento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Este campo es requerido'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _duracionController,
                decoration: const InputDecoration(labelText: 'Duración (minutos)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _precioController,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveTreatment,
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
