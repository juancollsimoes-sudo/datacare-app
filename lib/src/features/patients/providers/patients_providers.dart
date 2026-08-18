import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_provider.dart';
import '../../../rust/db/models.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

// State for the patients list
class PatientsListState {
  final List<Paciente> items;
  final int total;
  final int page;
  final int pageSize;
  final String searchQuery;

  PatientsListState({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    this.searchQuery = '',
  });
}

class PatientsNotifier extends AsyncNotifier<PatientsListState> {
  @override
  Future<PatientsListState> build() async {
    return _fetchPatients('', 1, 50);
  }

  Future<PatientsListState> _fetchPatients(String search, int page, int pageSize) async {
    final apiClient = ref.read(apiClientProvider);
    final result = await apiClient.listPacientes(
      search: search.isEmpty ? null : search,
      page: page,
      pageSize: pageSize,
    );
    return PatientsListState(
      items: result.items,
      total: result.total.toInt(),
      page: result.page,
      pageSize: result.pageSize,
      searchQuery: search,
    );
  }

  Future<void> loadPage(int page) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    
    state = const AsyncValue.loading();
    try {
      final newState = await _fetchPatients(currentState.searchQuery, page, currentState.pageSize);
      state = AsyncValue.data(newState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> search(String query) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    
    state = const AsyncValue.loading();
    try {
      final newState = await _fetchPatients(query, 1, currentState.pageSize);
      state = AsyncValue.data(newState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    final currentState = state.valueOrNull;
    if (currentState == null) {
      state = const AsyncValue.loading();
      try {
        final newState = await _fetchPatients('', 1, 50);
        state = AsyncValue.data(newState);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
      return;
    }
    
    try {
      final newState = await _fetchPatients(currentState.searchQuery, currentState.page, currentState.pageSize);
      state = AsyncValue.data(newState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final patientsProvider = AsyncNotifierProvider<PatientsNotifier, PatientsListState>(
  () => PatientsNotifier(),
);

final patientDetailProvider = FutureProvider.family<Paciente?, PlatformInt64>((ref, id) async {
  final apiClient = ref.read(apiClientProvider);
  return await apiClient.getPaciente(id: id);
});

final patientsActionProvider = Provider((ref) {
  return PatientsActionService(ref);
});

class PatientsActionService {
  final Ref ref;
  PatientsActionService(this.ref);

  Future<void> addPatient(NuevoPaciente paciente) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.createPaciente(paciente: paciente);
    ref.read(patientsProvider.notifier).refresh();
  }

  Future<void> editPatient(ActualizarPaciente paciente) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.updatePaciente(paciente: paciente);
    ref.invalidate(patientDetailProvider(paciente.id));
    ref.read(patientsProvider.notifier).refresh();
  }

  Future<void> deactivate(PlatformInt64 id) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.deactivatePaciente(id: id);
    ref.invalidate(patientDetailProvider(id));
    ref.read(patientsProvider.notifier).refresh();
  }
}
