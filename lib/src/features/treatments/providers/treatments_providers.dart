import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_provider.dart';
import '../../../rust/db/models.dart';
// import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class TreatmentsNotifier extends AsyncNotifier<List<Tratamiento>> {
  @override
  Future<List<Tratamiento>> build() async {
    return _fetchTreatments();
  }

  Future<List<Tratamiento>> _fetchTreatments() async {
    final apiClient = ref.read(apiClientProvider);
    return await apiClient.listTratamientos();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final newState = await _fetchTreatments();
      state = AsyncValue.data(newState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final treatmentsProvider = AsyncNotifierProvider<TreatmentsNotifier, List<Tratamiento>>(
  () => TreatmentsNotifier(),
);

final treatmentsActionProvider = Provider((ref) {
  return TreatmentsActionService(ref);
});

class TreatmentsActionService {
  final Ref ref;
  TreatmentsActionService(this.ref);

  Future<void> addTreatment(NuevoTratamiento tratamiento) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.createTratamiento(tratamiento: tratamiento);
    ref.read(treatmentsProvider.notifier).refresh();
  }

  Future<void> editTreatment(ActualizarTratamiento tratamiento) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.updateTratamiento(tratamiento: tratamiento);
    ref.read(treatmentsProvider.notifier).refresh();
  }
}
