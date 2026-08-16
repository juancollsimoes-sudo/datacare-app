import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_provider.dart';
import '../../../rust/db/models.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class SessionsListState {
  final List<Sesion> items;
  final int total;
  final int page;
  final int pageSize;

  SessionsListState({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

class SessionsNotifier extends AutoDisposeFamilyAsyncNotifier<SessionsListState, PlatformInt64> {
  @override
  Future<SessionsListState> build(PlatformInt64 arg) async {
    return _fetchSessions(arg, 1, 20);
  }

  Future<SessionsListState> _fetchSessions(PlatformInt64 pacienteId, int page, int pageSize) async {
    final apiClient = ref.read(apiClientProvider);
    final result = await apiClient.listSesionesByPaciente(
      pacienteId: pacienteId,
      page: page,
      pageSize: pageSize,
    );
    return SessionsListState(
      items: result.items,
      total: result.total.toInt(),
      page: result.page,
      pageSize: result.pageSize,
    );
  }

  Future<void> loadPage(int page) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    
    state = const AsyncValue.loading();
    try {
      final newState = await _fetchSessions(arg, page, currentState.pageSize);
      state = AsyncValue.data(newState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    final currentState = state.valueOrNull;
    final page = currentState?.page ?? 1;
    final pageSize = currentState?.pageSize ?? 20;

    state = const AsyncValue.loading();
    try {
      final newState = await _fetchSessions(arg, page, pageSize);
      state = AsyncValue.data(newState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final patientSessionsProvider = AsyncNotifierProvider.autoDispose.family<SessionsNotifier, SessionsListState, PlatformInt64>(
  () => SessionsNotifier(),
);

final sessionDetailProvider = FutureProvider.family<Sesion?, PlatformInt64>((ref, id) async {
  final apiClient = ref.read(apiClientProvider);
  return await apiClient.getSesion(id: id);
});

final sessionsActionProvider = Provider((ref) {
  return SessionsActionService(ref);
});

class SessionsActionService {
  final Ref ref;
  SessionsActionService(this.ref);

  Future<void> addSession(NuevaSesion sesion) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.createSesion(sesion: sesion);
    ref.invalidate(patientSessionsProvider(sesion.pacienteId));
  }

  Future<void> editSession(ActualizarSesion sesion, PlatformInt64 pacienteId) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.updateSesion(sesion: sesion);
    ref.invalidate(sessionDetailProvider(sesion.id));
    ref.invalidate(patientSessionsProvider(pacienteId));
  }
}
