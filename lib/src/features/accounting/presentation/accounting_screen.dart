import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../rust/api/db_api.dart';
import '../../../rust/db/models.dart';

class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});

  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen> {
  bool _isLoading = true;
  List<dynamic> _transactions = []; // Will hold both Gasto and Sesion

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final gastos = await listGastos();
      final ingresos = await listIngresos();

      final combined = [...gastos, ...ingresos];
      // Sort by date descending
      combined.sort((a, b) {
        final dateA = a is Gasto ? a.fecha : (a as Sesion).fecha;
        final dateB = b is Gasto ? b.fecha : (b as Sesion).fecha;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _transactions = combined;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddExpenseDialog(),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contaduría'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text('No hay registros.'))
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final item = _transactions[index];
                    final isExpense = item is Gasto;
                    
                    final title = isExpense ? item.nombre : 'Sesión (ID: ${(item as Sesion).id})';
                    final date = isExpense ? item.fecha : (item as Sesion).fecha;
                    final amount = isExpense ? item.monto : ((item as Sesion).precioCobrado ?? 0.0);
                    final description = isExpense ? (item.descripcion ?? '') : (item.observaciones ?? '');
                    
                    // Parse date for better formatting if needed, assuming ISO format
                    String formattedDate = date;
                    try {
                      final parsed = DateTime.parse(date);
                      formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(parsed);
                    } catch (_) {}

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isExpense ? Colors.red.shade100 : Colors.green.shade100,
                        child: Icon(
                          isExpense ? Icons.remove : Icons.add,
                          color: isExpense ? Colors.red : Colors.green,
                        ),
                      ),
                      title: Text(title),
                      subtitle: Text('$formattedDate ${description.isNotEmpty ? "- $description" : ""}'),
                      trailing: Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isExpense ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        tooltip: 'Agregar Gasto',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  
  String _selectedCategory = 'Otro';
  final List<String> _categories = [
    'Producto',
    'Máquina',
    'Mantenimiento',
    'Impuesto',
    'Otro'
  ];

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      final monto = double.parse(_montoController.text);
      final gasto = NuevoGasto(
        nombre: _nombreController.text,
        descripcion: _descripcionController.text.isNotEmpty ? _descripcionController.text : null,
        categoria: _selectedCategory,
        monto: monto,
        fecha: _selectedDate.toIso8601String(),
      );
      
      await createGasto(gasto: gasto);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo Gasto'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categories.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedCategory = v);
                  }
                },
              ),
              TextFormField(
                controller: _montoController,
                decoration: const InputDecoration(labelText: 'Monto'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (double.tryParse(v) == null) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fecha: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveExpense,
          child: _isSaving 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Guardar'),
        ),
      ],
    );
  }
}
