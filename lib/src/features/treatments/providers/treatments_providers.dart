import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../rust/api/db_api.dart';
import '../../../rust/db/models.dart';
// import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class TreatmentsNotifier extends AsyncNotifier<List<Tratamiento>> {
  @override
  Future<List<Tratamiento>> build() async {
    return _fetchTreatments();
  }

  Future<List<Tratamiento>> _fetchTreatments() async {
    return await listTratamientos();
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
    await createTratamiento(tratamiento: tratamiento);
    ref.read(treatmentsProvider.notifier).refresh();
  }

  Future<void> editTreatment(ActualizarTratamiento tratamiento) async {
    await updateTratamiento(tratamiento: tratamiento);
    ref.read(treatmentsProvider.notifier).refresh();
  }
}
