import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_provider.dart';
import '../../../rust/api/pdf_api.dart';
import '../../../rust/db/models.dart';

bool isPersonalExpenseCategory(String? categoria) {
  if (categoria == null) return false;
  return categoria.trim().toLowerCase().contains('personal');
}

String spanishMonthName(int month) {
  const names = [
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
  if (month >= 1 && month <= 12) return names[month];
  return 'Mes';
}

class _AnimatedCurrencyText extends StatelessWidget {
  final double value;
  final TextStyle style;

  const _AnimatedCurrencyText({
    required this.value,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '\$${animatedValue.toStringAsFixed(2)}',
          style: style,
        );
      },
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? (Matrix4.identity()..translateByDouble(0.0, -3.0, 0.0, 1.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.color.withValues(alpha: isDark ? 0.35 : 0.16)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: _isHovered ? 14 : 5,
              offset: Offset(0, _isHovered ? 5 : 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 16, color: widget.color),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AnimatedCurrencyText(
              value: widget.amount,
              style: TextStyle(
                color: widget.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountingScreen extends ConsumerStatefulWidget {
  const AccountingScreen({super.key});

  @override
  ConsumerState<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends ConsumerState<AccountingScreen> {
  bool _isLoading = true;
  bool _isExportingExcel = false;
  List<Gasto> _gastos = [];
  List<Sesion> _ingresos = [];
  Map<int, String> _patientNames = {};
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _exportExpensesExcel() async {
    setState(() => _isExportingExcel = true);
    try {
      final api = ref.read(apiClientProvider);
      final year = _selectedMonth.year;
      final month = _selectedMonth.month;
      final excelBytes = await api.generateExpensesExcelBytes(
        year: year,
        month: month,
      );

      final defaultFileName =
          'gastos_y_compras_${year}_${month.toString().padLeft(2, '0')}.xlsx';

      final outputFileUri = await FilePicker.saveFile(
        bytes: excelBytes,
        dialogTitle: 'Guardar Excel de Gastos y Compras',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFileUri != null) {
        if (!kIsWeb) {
          final outputPath = outputFileUri.toFilePath();
          final file = File(outputPath);
          if (!await file.exists() || await file.length() == 0) {
            await apiGenerateExpensesExcel(
              year: year,
              month: month,
              outputPath: outputPath,
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Excel de Gastos y Compras guardado en: $outputPath',
                ),
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Excel de Gastos y Compras descargado correctamente.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar Excel de gastos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingExcel = false);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.listGastos(),
        api.listIngresos(),
        api.listPacientes(page: 1, pageSize: 1000),
      ]);

      final gastos = results[0] as List<Gasto>;
      final ingresos = results[1] as List<Sesion>;
      final paginatedPacientes = results[2] as PaginatedPacientes;

      final patientMap = <int, String>{};
      for (final p in paginatedPacientes.items) {
        final fullName = '${p.nombre} ${p.apellido}'.trim();
        if (fullName.isNotEmpty) {
          patientMap[p.id.toInt()] = fullName;
        }
      }

      if (mounted) {
        setState(() {
          _gastos = gastos;
          _ingresos = ingresos;
          _patientNames = patientMap;
        });
      }
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

  String _resolvePatientName(Sesion sesion) {
    final fromJoin = sesion.pacienteNombre?.trim();
    if (fromJoin != null && fromJoin.isNotEmpty) {
      return fromJoin;
    }
    final fromMap = _patientNames[sesion.pacienteId.toInt()];
    if (fromMap != null && fromMap.isNotEmpty) {
      return fromMap;
    }
    return 'Paciente #${sesion.pacienteId}';
  }

  bool _isInSelectedMonth(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return parsed.year == _selectedMonth.year &&
          parsed.month == _selectedMonth.month;
    } catch (_) {
      final prefix =
          '${_selectedMonth.year.toString().padLeft(4, '0')}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      return dateStr.trim().startsWith(prefix);
    }
  }

  void _changeMonth(int deltaMonths) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + deltaMonths,
      );
    });
  }

  void _showAddExpenseDialog({Gasto? gasto, String? initialCategory}) {
    showDialog<bool>(
      context: context,
      builder: (context) => AddExpenseDialog(
        gastoToEdit: gasto,
        initialCategory: initialCategory,
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  void _showMonthlyClosingDialog({
    required List<Sesion> monthIngresos,
    required List<Gasto> monthOperationalExpenses,
    required List<Gasto> monthPersonalExpenses,
    required double totalIncome,
    required double subtotalOperationalExpenses,
    required double totalPersonalExpenses,
    required double totalExpenses,
    required double netBalance,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => MonthlyClosingDialog(
        year: _selectedMonth.year,
        month: _selectedMonth.month,
        ingresosCount: monthIngresos.length,
        operationalExpensesCount: monthOperationalExpenses.length,
        personalExpensesCount: monthPersonalExpenses.length,
        totalIncome: totalIncome,
        subtotalOperationalExpenses: subtotalOperationalExpenses,
        totalPersonalExpenses: totalPersonalExpenses,
        totalExpenses: totalExpenses,
        netBalance: netBalance,
      ),
    );
  }

  Future<void> _deleteGastoItem(Gasto item) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.deleteGasto(id: item.id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar gasto: $e')),
        );
      }
    }
  }

  void _showItemActions(dynamic item) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modificar'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (item is Gasto) {
                  _showAddExpenseDialog(gasto: item);
                } else if (item is Sesion) {
                  context.go('/sessions/edit/${item.pacienteId}', extra: item);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (item is Gasto) {
                  await _deleteGastoItem(item);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Las sesiones deben eliminarse o anularse desde la ficha del paciente o Sesiones',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelectorBar({
    required List<Sesion> monthIngresos,
    required List<Gasto> monthOperationalExpenses,
    required List<Gasto> monthPersonalExpenses,
    required double totalIncome,
    required double subtotalOperationalExpenses,
    required double totalPersonalExpenses,
    required double totalExpenses,
    required double netBalance,
  }) {
    final theme = Theme.of(context);
    final monthTitle =
        '${spanishMonthName(_selectedMonth.month)} ${_selectedMonth.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      monthTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('btn_add_personal_expense'),
                onPressed: () => _showAddExpenseDialog(
                  initialCategory: 'Gastos Personales',
                ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Anexar Gasto Personal'),
              ),
              FilledButton.tonalIcon(
                key: const Key('btn_export_expenses_excel'),
                onPressed: _isExportingExcel ? null : _exportExpensesExcel,
                icon: _isExportingExcel
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.table_view_rounded, size: 18),
                label: Text(
                  _isExportingExcel
                      ? 'Exportando Excel...'
                      : 'Descargar Excel (Gastos y Compras)',
                ),
              ),
              FilledButton.icon(
                key: const Key('btn_cierre_contable_pdf'),
                onPressed: () => _showMonthlyClosingDialog(
                  monthIngresos: monthIngresos,
                  monthOperationalExpenses: monthOperationalExpenses,
                  monthPersonalExpenses: monthPersonalExpenses,
                  totalIncome: totalIncome,
                  subtotalOperationalExpenses: subtotalOperationalExpenses,
                  totalPersonalExpenses: totalPersonalExpenses,
                  totalExpenses: totalExpenses,
                  netBalance: netBalance,
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Cierre Contable PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumericTab() {
    final monthIngresos = _ingresos
        .where((s) => _isInSelectedMonth(s.fecha))
        .toList();
    final monthGastos = _gastos
        .where((g) => _isInSelectedMonth(g.fecha))
        .toList();

    final monthPersonalExpenses = monthGastos
        .where((g) => isPersonalExpenseCategory(g.categoria))
        .toList();
    final monthOperationalExpenses = monthGastos
        .where((g) => !isPersonalExpenseCategory(g.categoria))
        .toList();

    double currentMonthIncome = 0;
    for (final s in monthIngresos) {
      currentMonthIncome += (s.precioCobrado ?? 0.0);
    }

    double subtotalOperationalExpenses = 0;
    for (final g in monthOperationalExpenses) {
      subtotalOperationalExpenses += g.monto;
    }

    double totalPersonalExpenses = 0;
    for (final g in monthPersonalExpenses) {
      totalPersonalExpenses += g.monto;
    }

    final totalExpenses = subtotalOperationalExpenses + totalPersonalExpenses;
    final balance = currentMonthIncome - totalExpenses;

    // Combined operational + income transactions for the main list
    final List<dynamic> mainTransactions = [
      ...monthIngresos,
      ...monthOperationalExpenses,
    ];
    mainTransactions.sort((a, b) {
      final dateA = a is Gasto ? a.fecha : (a as Sesion).fecha;
      final dateB = b is Gasto ? b.fecha : (b as Sesion).fecha;
      return dateB.compareTo(dateA);
    });

    final theme = Theme.of(context);

    return Column(
      children: [
        _buildMonthSelectorBar(
          monthIngresos: monthIngresos,
          monthOperationalExpenses: monthOperationalExpenses,
          monthPersonalExpenses: monthPersonalExpenses,
          totalIncome: currentMonthIncome,
          subtotalOperationalExpenses: subtotalOperationalExpenses,
          totalPersonalExpenses: totalPersonalExpenses,
          totalExpenses: totalExpenses,
          netBalance: balance,
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: SingleChildScrollView(
              key: ValueKey('${_selectedMonth.year}-${_selectedMonth.month}'),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _MetricCard(
                        title: 'Ingresos',
                        amount: currentMonthIncome,
                        color: Colors.green.shade700,
                        icon: Icons.trending_up,
                      ),
                      _MetricCard(
                        title: 'Gastos Operativos',
                        amount: subtotalOperationalExpenses,
                        color: Colors.red.shade600,
                        icon: Icons.storefront_outlined,
                      ),
                      _MetricCard(
                        title: 'Gastos Personales',
                        amount: totalPersonalExpenses,
                        color: Colors.deepOrange.shade700,
                        icon: Icons.person_outline,
                      ),
                      _MetricCard(
                        title: 'Total Gastos',
                        amount: totalExpenses,
                        color: Colors.red.shade900,
                        icon: Icons.receipt_long,
                      ),
                      _MetricCard(
                        title: 'Saldo',
                        amount: balance,
                        color: balance >= 0
                            ? Colors.blue.shade700
                            : Colors.orange.shade800,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 1. Movimientos de Ingresos y Gastos Operativos
                  Text(
                    'Movimientos Contables del Mes (Sesiones e Insumos)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              const SizedBox(height: 8),
              if (mainTransactions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'No hay sesiones cobradas ni gastos operativos en este mes.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: mainTransactions.map((item) {
                      final isExpense = item is Gasto;
                      final String title = isExpense
                          ? item.nombre
                          : _resolvePatientName(item as Sesion);
                      final String date = isExpense
                          ? item.fecha
                          : (item as Sesion).fecha;
                      final double amount = isExpense
                          ? item.monto
                          : ((item as Sesion).precioCobrado ?? 0.0);
                      final String description = isExpense
                          ? (item.descripcion ?? '')
                          : ((item as Sesion).notasSesion ??
                                item.observaciones ??
                                '');
                      final String badgeText = isExpense
                          ? (item.categoria ?? 'Operativo')
                          : ((item as Sesion).tipo == 'corporal'
                                ? 'Sesión Corporal'
                                : 'Sesión Facial');

                      String formattedDate = date;
                      try {
                        final parsed = DateTime.parse(date);
                        formattedDate = DateFormat('yyyy-MM-dd').format(parsed);
                      } catch (_) {}

                      return ListTile(
                        onTap: () => _showItemActions(item),
                        leading: CircleAvatar(
                          backgroundColor: isExpense
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            isExpense ? Icons.remove : Icons.person,
                            color: isExpense
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isExpense
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isExpense
                                      ? Colors.red.shade800
                                      : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '$formattedDate${description.isNotEmpty ? " - $description" : ""}',
                        ),
                        trailing: Text(
                          '${isExpense ? "-" : "+"}\$${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isExpense
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 20),

              // 2. Renglón de Gastos Personales (totalizados para incorporarse a la contabilidad)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Colors.deepOrange.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.deepOrange.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Renglón de Gastos Personales',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Gastos personales del período que se totalizan al final para ser incorporados a la contabilidad general.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddExpenseDialog(
                              initialCategory: 'Gastos Personales',
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      if (monthPersonalExpenses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Sin gastos personales registrados en este mes (\$0.00).',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...monthPersonalExpenses.map((gasto) {
                          String formattedDate = gasto.fecha;
                          try {
                            final parsed = DateTime.parse(gasto.fecha);
                            formattedDate = DateFormat(
                              'yyyy-MM-dd',
                            ).format(parsed);
                          } catch (_) {}
                          final desc = gasto.descripcion ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => _showItemActions(gasto),
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepOrange.shade100,
                              child: Icon(
                                Icons.person_remove_outlined,
                                color: Colors.deepOrange.shade800,
                              ),
                            ),
                            title: Text(
                              gasto.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$formattedDate${desc.isNotEmpty ? " - $desc" : ""}',
                            ),
                            trailing: Text(
                              '-\$${gasto.monto.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.deepOrange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          );
                        }),
                      const Divider(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'Total Renglón Gastos Personales (Incorporado a Contabilidad):',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              '\$${totalPersonalExpenses.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.deepOrange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. Cuadre Final de Contabilidad (Totalización)
              Card(
                color: theme.colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Totalización e Incorporación Contable del Mes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildClosingRow(
                        '(+) Total Ingresos por Sesiones:',
                        currentMonthIncome,
                        Colors.green.shade700,
                      ),
                      const SizedBox(height: 6),
                      _buildClosingRow(
                        '(-) Subtotal Gastos Operativos:',
                        subtotalOperationalExpenses,
                        Colors.red.shade600,
                      ),
                      const SizedBox(height: 6),
                      _buildClosingRow(
                        '(-) Renglón Gastos Personales (Totalizados):',
                        totalPersonalExpenses,
                        Colors.deepOrange.shade700,
                        isBold: true,
                      ),
                      const Divider(height: 18),
                      _buildClosingRow(
                        '(=) Total General de Gastos Incorporados:',
                        totalExpenses,
                        Colors.red.shade900,
                        isBold: true,
                      ),
                      const SizedBox(height: 8),
                      _buildClosingRow(
                        '(=) SALDO NETO CONTABLE DEL MES:',
                        balance,
                        balance >= 0
                            ? Colors.blue.shade700
                            : Colors.orange.shade800,
                        isBold: true,
                        fontSize: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    ),
  ],
);
}

  Widget _buildClosingRow(
    String label,
    double value,
    Color valueColor, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
        ),
        _AnimatedCurrencyText(
          value: value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildChartLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildVisualTab() {
    final Map<int, double> incomesByDay = {};
    final Map<int, double> expensesByDay = {};

    for (final s in _ingresos) {
      if (_isInSelectedMonth(s.fecha)) {
        try {
          final date = DateTime.parse(s.fecha);
          final day = date.day;
          final inc = s.precioCobrado ?? 0.0;
          incomesByDay[day] = (incomesByDay[day] ?? 0) + inc;
        } catch (_) {}
      }
    }

    for (final g in _gastos) {
      if (_isInSelectedMonth(g.fecha)) {
        try {
          final date = DateTime.parse(g.fecha);
          final day = date.day;
          expensesByDay[day] = (expensesByDay[day] ?? 0) + g.monto;
        } catch (_) {}
      }
    }

    final int daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
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

    maxY = maxY > 0 ? maxY * 1.2 : 100;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(
        right: 32.0,
        left: 16.0,
        top: 24.0,
        bottom: 16.0,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegendItem(
                color: Colors.green.shade600,
                label: 'Ingresos por Sesiones',
              ),
              const SizedBox(width: 32),
              _buildChartLegendItem(
                color: Colors.redAccent,
                label: 'Gastos Registrados',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Día ${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 64,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                minX: 1,
                maxX: daysInMonth.toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: Colors.green.shade600,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: Colors.green.shade600,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.25),
                          Colors.green.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: expenseSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    preventCurveOverShooting: true,
                    color: Colors.redAccent,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: Colors.redAccent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.redAccent.withValues(alpha: 0.2),
                          Colors.redAccent.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBorderRadius: BorderRadius.circular(12),
                    maxContentWidth: 200,
                    fitInsideHorizontally: true,
                    getTooltipColor: (touchedSpot) => isDark
                        ? Colors.blueGrey.shade800.withValues(alpha: 0.95)
                        : Colors.blueGrey.shade900.withValues(alpha: 0.92),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final isIncome = touchedSpot.barIndex == 0;
                        return LineTooltipItem(
                          '${isIncome ? 'Ingreso' : 'Gasto'}: \$${touchedSpot.y.toStringAsFixed(2)}',
                          TextStyle(
                            color: isIncome
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
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
              tooltip: 'Actualizar datos',
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
          onPressed: () => _showAddExpenseDialog(),
          tooltip: 'Agregar Gasto',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class MonthlyClosingDialog extends ConsumerStatefulWidget {
  final int year;
  final int month;
  final int ingresosCount;
  final int operationalExpensesCount;
  final int personalExpensesCount;
  final double totalIncome;
  final double subtotalOperationalExpenses;
  final double totalPersonalExpenses;
  final double totalExpenses;
  final double netBalance;

  const MonthlyClosingDialog({
    super.key,
    required this.year,
    required this.month,
    required this.ingresosCount,
    required this.operationalExpensesCount,
    required this.personalExpensesCount,
    required this.totalIncome,
    required this.subtotalOperationalExpenses,
    required this.totalPersonalExpenses,
    required this.totalExpenses,
    required this.netBalance,
  });

  @override
  ConsumerState<MonthlyClosingDialog> createState() =>
      _MonthlyClosingDialogState();
}

class _MonthlyClosingDialogState extends ConsumerState<MonthlyClosingDialog> {
  bool _isGeneratingPdf = false;

  Future<void> _exportClosingPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final api = ref.read(apiClientProvider);
      final pdfBytes = await api.generateAccountingReportBytes(
        year: widget.year,
        month: widget.month,
      );

      final defaultFileName =
          'cierre_contable_${widget.year}_${widget.month.toString().padLeft(2, '0')}.pdf';

      final outputFileUri = await FilePicker.saveFile(
        bytes: pdfBytes,
        dialogTitle: 'Guardar Cierre Contable en PDF',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFileUri != null) {
        if (!kIsWeb) {
          final outputPath = outputFileUri.toFilePath();
          final file = File(outputPath);
          if (!await file.exists() || await file.length() == 0) {
            await apiGenerateAccountingReport(
              year: widget.year,
              month: widget.month,
              outputPath: outputPath,
            );
          }
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cierre contable guardado en PDF: $outputPath'),
              ),
            );
          }
        } else if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cierre contable descargado en PDF correctamente.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar PDF de cierre: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mesNombre = spanishMonthName(widget.month);
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text('Cierre Contable - $mesNombre ${widget.year}'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de fin de mes con gastos personales totalizados e incorporados a la contabilidad:',
            ),
            const SizedBox(height: 16),
            _summaryLine(
              '(+) Ingresos (${widget.ingresosCount} sesiones):',
              '\$${widget.totalIncome.toStringAsFixed(2)}',
              Colors.green.shade700,
            ),
            const SizedBox(height: 8),
            _summaryLine(
              '(-) Gastos Operativos (${widget.operationalExpensesCount}):',
              '\$${widget.subtotalOperationalExpenses.toStringAsFixed(2)}',
              Colors.red.shade600,
            ),
            const SizedBox(height: 8),
            _summaryLine(
              '(-) Renglón Gastos Personales (${widget.personalExpensesCount}):',
              '\$${widget.totalPersonalExpenses.toStringAsFixed(2)}',
              Colors.deepOrange.shade700,
              bold: true,
            ),
            const Divider(height: 24),
            _summaryLine(
              '(=) Total Gastos Incorporados:',
              '\$${widget.totalExpenses.toStringAsFixed(2)}',
              Colors.red.shade900,
              bold: true,
            ),
            const SizedBox(height: 8),
            _summaryLine(
              '(=) SALDO NETO DEL CIERRE:',
              '\$${widget.netBalance.toStringAsFixed(2)}',
              widget.netBalance >= 0
                  ? Colors.blue.shade700
                  : Colors.orange.shade800,
              bold: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGeneratingPdf
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          key: const Key('btn_save_cierre_pdf'),
          onPressed: _isGeneratingPdf ? null : _exportClosingPdf,
          icon: _isGeneratingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(
            _isGeneratingPdf ? 'Generando PDF...' : 'Guardar Cierre en PDF',
          ),
        ),
      ],
    );
  }

  Widget _summaryLine(
    String label,
    String amount,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class AddExpenseDialog extends ConsumerStatefulWidget {
  final Gasto? gastoToEdit;
  final String? initialCategory;

  const AddExpenseDialog({
    super.key,
    this.gastoToEdit,
    this.initialCategory,
  });

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();

  String _selectedCategory = 'Compra / Insumos';
  final List<String> _categories = const [
    'Compra / Insumos',
    'Producto',
    'Máquina',
    'Mantenimiento',
    'Impuesto',
    'Gastos Personales',
    'Otro',
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
      final cat = g.categoria ?? 'Otro';
      if (isPersonalExpenseCategory(cat)) {
        _selectedCategory = 'Gastos Personales';
      } else if (_categories.contains(cat)) {
        _selectedCategory = cat;
      } else {
        _selectedCategory = 'Otro';
      }
      _selectedDate = DateTime.tryParse(g.fecha) ?? DateTime.now();
    } else if (widget.initialCategory != null &&
        _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
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
      final api = ref.read(apiClientProvider);
      final monto = double.parse(_montoController.text.replaceAll(',', '.'));
      if (widget.gastoToEdit == null) {
        final gasto = NuevoGasto(
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim().isNotEmpty
              ? _descripcionController.text.trim()
              : null,
          categoria: _selectedCategory,
          monto: monto,
          fecha: _selectedDate.toIso8601String(),
        );
        await api.createGasto(gasto: gasto);
      } else {
        final gasto = Gasto(
          id: widget.gastoToEdit!.id,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim().isNotEmpty
              ? _descripcionController.text.trim()
              : null,
          categoria: _selectedCategory,
          monto: monto,
          fecha: _selectedDate.toIso8601String(),
        );
        await api.updateGasto(gasto: gasto);
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
    final isPersonal = _selectedCategory == 'Gastos Personales';
    return AlertDialog(
      title: Text(
        widget.gastoToEdit == null
            ? (isPersonal ? 'Nuevo Gasto Personal' : 'Nuevo Gasto')
            : 'Modificar Gasto',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Concepto / Nombre'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría / Renglón',
                ),
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
                decoration: const InputDecoration(labelText: 'Monto (\$)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) {
                    return 'Monto inválido';
                  }
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
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
