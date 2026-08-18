import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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

  Widget _buildNumericTab() {
    if (_transactions.isEmpty) return const Center(child: Text('No hay registros.'));

    double currentMonthIncome = 0;
    double currentMonthExpenses = 0;
    
    final now = DateTime.now();
    for (final item in _transactions) {
      final dateStr = item is Gasto ? item.fecha : (item as Sesion).fecha;
      try {
        final date = DateTime.parse(dateStr);
        if (date.year == now.year && date.month == now.month) {
          if (item is Gasto) {
            currentMonthExpenses += item.monto;
          } else {
            currentMonthIncome += ((item as Sesion).precioCobrado ?? 0.0);
          }
        }
      } catch (_) {}
    }
    final balance = currentMonthIncome - currentMonthExpenses;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryCard('Ingresos', currentMonthIncome, Colors.green),
              _buildSummaryCard('Gastos', currentMonthExpenses, Colors.red),
              _buildSummaryCard('Saldo', balance, balance >= 0 ? Colors.blue : Colors.orange),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
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
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualTab() {
    if (_transactions.isEmpty) return const Center(child: Text('No hay registros.'));

    // Group by day for the chart
    final Map<int, double> incomesByDay = {};
    final Map<int, double> expensesByDay = {};

    final now = DateTime.now();
    for (final item in _transactions) {
      final dateStr = item is Gasto ? item.fecha : (item as Sesion).fecha;
      try {
        final date = DateTime.parse(dateStr);
        if (date.year == now.year && date.month == now.month) {
          final day = date.day;
          if (item is Gasto) {
            expensesByDay[day] = (expensesByDay[day] ?? 0) + item.monto;
          } else {
            final inc = (item as Sesion).precioCobrado ?? 0.0;
            incomesByDay[day] = (incomesByDay[day] ?? 0) + inc;
          }
        }
      } catch (_) {}
    }

    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final List<BarChartGroupData> barGroups = [];

    for (int i = 1; i <= daysInMonth; i++) {
      final inc = incomesByDay[i] ?? 0.0;
      final exp = expensesByDay[i] ?? 0.0;
      if (inc > 0 || exp > 0) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              if (inc > 0)
                BarChartRodData(toY: inc, color: Colors.green, width: 8),
              if (exp > 0)
                BarChartRodData(toY: exp, color: Colors.red, width: 8),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  'Día ${group.x}\n\$${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contaduría'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Numérico'),
              Tab(text: 'Visual'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildNumericTab(),
                  _buildVisualTab(),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddExpenseDialog,
          tooltip: 'Agregar Gasto',
          child: const Icon(Icons.add),
        ),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
