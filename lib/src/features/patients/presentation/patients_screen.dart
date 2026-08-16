import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/patients_providers.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(patientsProvider.notifier).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientsState = ref.watch(patientsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/patients/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Paciente'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar
            SearchBar(
              controller: _searchController,
              hintText: 'Buscar paciente por nombre o apellido...',
              leading: const Icon(Icons.search),
              onChanged: _onSearchChanged,
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
              ],
            ),
            const SizedBox(height: 24),
            // Table
            Expanded(
              child: patientsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (data) {
                  if (data.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No se encontraron pacientes.', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    );
                  }

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('Nombre')),
                          DataColumn(label: Text('Teléfono')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Registro')),
                          DataColumn(label: Text('Estado')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: data.items.map((paciente) {
                          return DataRow(
                            onSelectChanged: (_) => context.go('/patients/${paciente.id}'),
                            cells: [
                              DataCell(Text('${paciente.nombre} ${paciente.apellido}')),
                              DataCell(Text(paciente.telefono ?? '-')),
                              DataCell(Text(paciente.email ?? '-')),
                              DataCell(Text(paciente.fechaRegistro.split('T').first)),
                              DataCell(
                                Chip(
                                  label: Text(paciente.activo ? 'Activo' : 'Inactivo'),
                                  backgroundColor: paciente.activo ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                  labelStyle: TextStyle(
                                    color: paciente.activo ? Colors.green : Colors.red,
                                    fontSize: 12,
                                  ),
                                  side: BorderSide.none,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => context.go('/patients/${paciente.id}/edit'),
                                      tooltip: 'Editar',
                                    ),
                                    if (paciente.activo)
                                      IconButton(
                                        icon: const Icon(Icons.person_off, size: 20),
                                        onPressed: () {
                                          _confirmDeactivate(context, paciente.id, '${paciente.nombre} ${paciente.apellido}');
                                        },
                                        tooltip: 'Desactivar',
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Pagination
            patientsState.maybeWhen(
              data: (data) => _buildPagination(data),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(PatientsListState data) {
    final totalPages = (data.total / data.pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Total: ${data.total}'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: data.page > 1
                ? () => ref.read(patientsProvider.notifier).loadPage(data.page - 1)
                : null,
          ),
          Text('Página ${data.page} de $totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: data.page < totalPages
                ? () => ref.read(patientsProvider.notifier).loadPage(data.page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, PlatformInt64 id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar Paciente'),
        content: Text('¿Estás seguro de que deseas desactivar a $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(patientsActionProvider).deactivate(id);
    }
  }
}
