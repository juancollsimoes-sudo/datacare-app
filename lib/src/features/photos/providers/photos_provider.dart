import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../../../core/api/api_provider.dart';
import '../../../rust/db/models.dart';

class PhotosNotifier extends StateNotifier<AsyncValue<List<FotoSesion>>> {
  final PlatformInt64 sessionId;
  final Ref ref;

  PhotosNotifier(this.sessionId, this.ref) : super(const AsyncValue.loading()) {
    loadPhotos();
  }

  Future<void> loadPhotos() async {
    try {
      state = const AsyncValue.loading();
      final apiClient = ref.read(apiClientProvider);
      final photos = await apiClient.listPhotosBySession(sesionId: sessionId);
      state = AsyncValue.data(photos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addPhoto(PlatformInt64 pacienteId, String inputPath, String? tipo, String? descripcion) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.saveSessionPhoto(
        pacienteId: pacienteId,
        sesionId: sessionId,
        inputPath: inputPath,
        tipo: tipo,
        descripcion: descripcion,
      );
      await loadPhotos();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removePhoto(PlatformInt64 fotoId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.deletePhoto(fotoId: fotoId);
      await loadPhotos();
    } catch (e) {
      rethrow;
    }
  }
}

final sessionPhotosProvider = StateNotifierProvider.family<PhotosNotifier, AsyncValue<List<FotoSesion>>, PlatformInt64>((ref, sessionId) {
  return PhotosNotifier(sessionId, ref);
});

final patientPhotosProvider = FutureProvider.family<List<FotoSesion>, PlatformInt64>((ref, pacienteId) async {
  final apiClient = ref.read(apiClientProvider);
  return await apiClient.listPhotosByPatient(pacienteId: pacienteId);
});
