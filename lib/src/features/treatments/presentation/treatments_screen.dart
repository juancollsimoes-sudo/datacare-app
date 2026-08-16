import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/treatments_providers.dart';


class TreatmentsScreen extends ConsumerWidget {
  const TreatmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treatmentsState = ref.watch(treatmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tratamientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(treatmentsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: treatmentsState.when(
        data: (treatments) {
          if (treatments.isEmpty) {
            return const Center(
              child: Text('No hay tratamientos registrados.'),
            );
          }
          return ListView.builder(
            itemCount: treatments.length,
            itemBuilder: (context, index) {
              final treatment = treatments[index];
              return ListTile(
                leading: const Icon(Icons.spa),
                title: Text(treatment.nombre),
                subtitle: Text(
                  '${treatment.descripcion ?? ''}\n'
                  'Duración: ${treatment.duracionMin ?? 'N/A'} min | '
                  'Precio: \$${treatment.precio?.toStringAsFixed(2) ?? 'N/A'}',
                ),
                isThreeLine: true,
                onTap: () {
                  context.push('/treatments/edit', extra: treatment);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/treatments/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
