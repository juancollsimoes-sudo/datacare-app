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
  
  late TextEditingController _nombreController;
  late TextEditingController _apellidoController;
  late TextEditingController _telefonoController;
  late TextEditingController _emailController;
  late TextEditingController _direccionController;
  late TextEditingController _notasController;
  late TextEditingController _alergiasController;
  late TextEditingController _condicionesController;
  
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
    _notasController = TextEditingController();
    _alergiasController = TextEditingController();
    _condicionesController = TextEditingController();
    
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
    _notasController.dispose();
    _alergiasController.dispose();
    _condicionesController.dispose();
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
    _condicionesController.text = paciente.condicionesMedicas ?? '';
    
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
      initialDate: _fechaNacimiento ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
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

      if (widget.id == null) {
        // Create
        final p = NuevoPaciente(
          nombre: _nombreController.text.trim(),
          apellido: _apellidoController.text.trim(),
          fechaNacimiento: fn,
          telefono: nullableStr(_telefonoController.text),
          email: nullableStr(_emailController.text),
          direccion: nullableStr(_direccionController.text),
          notasGenerales: nullableStr(_notasController.text),
          alergias: nullableStr(_alergiasController.text),
          condicionesMedicas: nullableStr(_condicionesController.text),
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
          notasGenerales: nullableStr(_notasController.text),
          alergias: nullableStr(_alergiasController.text),
          condicionesMedicas: nullableStr(_condicionesController.text),
        );
        await actionProvider.editPatient(p);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.id == null ? 'Paciente creado' : 'Paciente actualizado')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Paciente' : 'Nuevo Paciente'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Información Personal', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
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
                        ),
                        child: Text(
                          _fechaNacimiento != null 
                              ? '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}'
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
              const SizedBox(height: 32),
              Text('Información Clínica', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alergiasController,
                decoration: const InputDecoration(labelText: 'Alergias', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _condicionesController,
                decoration: const InputDecoration(labelText: 'Condiciones Médicas', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notasController,
                decoration: const InputDecoration(labelText: 'Notas Generales', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(isEdit ? 'Actualizar' : 'Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
