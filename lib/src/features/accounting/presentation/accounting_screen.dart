import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

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

  void _showAddExpenseDialog([Gasto? gasto]) {
    showDialog(
      context: context,
      builder: (context) => AddExpenseDialog(gastoToEdit: gasto),
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
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Modificar'),
                            onTap: () {
                              Navigator.pop(context);
                              if (isExpense) {
                                _showAddExpenseDialog(item as Gasto);
                              } else {
                                final sesion = item as Sesion;
                                context.go('/sessions/edit/${sesion.pacienteId}', extra: sesion);
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete, color: Colors.red),
                            title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                            onTap: () async {
                              Navigator.pop(context);
                              if (isExpense) {
                                try {
                                  await deleteGasto(id: (item as Gasto).id);
                                  _loadData();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error al eliminar gasto: $e')),
                                    );
                                  }
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Las sesiones deben eliminarse o anularse desde la pestaña de Sesiones')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
    final List<FlSpot> incomeSpots = [];
    final List<FlSpot> expenseSpots = [];

    double maxY = 0;

    for (int i = 1; i <= daysInMonth; i++) {
      final inc = incomesByDay[i] ?? 0.0;
      final exp = expensesByDay[i] ?? 0.0;
      incomeSpots.add(FlSpot(i.toDouble(), inc));
      expenseSpots.add(FlSpot(i.toDouble(), exp));
      
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
    }

    // Add some padding to maxY
    maxY = maxY > 0 ? maxY * 1.2 : 100;

    return Padding(
      padding: const EdgeInsets.only(right: 32.0, left: 16.0, top: 40.0, bottom: 16.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: true),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 5,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Día ${value.toInt()}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  return Text('\$${value.toInt()}', style: const TextStyle(fontSize: 12));
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          minX: 1,
          maxX: daysInMonth.toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: incomeSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              color: Colors.red,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.blueGrey.shade800,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final isIncome = touchedSpot.barIndex == 0;
                  return LineTooltipItem(
                    '${isIncome ? 'Ingreso' : 'Gasto'}: \$${touchedSpot.y.toStringAsFixed(2)}',
                    TextStyle(
                      color: isIncome ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
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
  final Gasto? gastoToEdit;
  const AddExpenseDialog({super.key, this.gastoToEdit});

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

  @override
  void initState() {
    super.initState();
    if (widget.gastoToEdit != null) {
      final g = widget.gastoToEdit!;
      _nombreController.text = g.nombre;
      _descripcionController.text = g.descripcion ?? '';
      _montoController.text = g.monto.toString();
      _selectedCategory = g.categoria;
      _selectedDate = DateTime.tryParse(g.fecha) ?? DateTime.now();
    }
  }

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
      if (widget.gastoToEdit == null) {
        final gasto = NuevoGasto(
          nombre: _nombreController.text,
          descripcion: _descripcionController.text.isNotEmpty ? _descripcionController.text : null,
          categoria: _selectedCategory,
          monto: monto,
          fecha: _selectedDate.toIso8601String(),
        );
        await createGasto(gasto: gasto);
      } else {
        final gasto = Gasto(
          id: widget.gastoToEdit!.id,
          nombre: _nombreController.text,
          descripcion: _descripcionController.text.isNotEmpty ? _descripcionController.text : null,
          categoria: _selectedCategory,
          monto: monto,
          fecha: _selectedDate.toIso8601String(),
        );
        await updateGasto(gasto: gasto);
      }
      
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
      title: Text(widget.gastoToEdit == null ? 'Nuevo Gasto' : 'Modificar Gasto'),
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
