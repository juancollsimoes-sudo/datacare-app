import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_provider.dart';
import '../../../rust/db/models.dart';

class PhotosNotifier extends StateNotifier<AsyncValue<List<FotoSesion>>> {
  final int sessionId;
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

  Future<void> addPhoto(int pacienteId, String inputPath, String? tipo, String? descripcion) async {
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

  Future<void> removePhoto(int fotoId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.deletePhoto(fotoId: fotoId);
      await loadPhotos();
    } catch (e) {
      rethrow;
    }
  }
}

final sessionPhotosProvider = StateNotifierProvider.family<PhotosNotifier, AsyncValue<List<FotoSesion>>, int>((ref, sessionId) {
  return PhotosNotifier(sessionId, ref);
});

final patientPhotosProvider = FutureProvider.family<List<FotoSesion>, int>((ref, pacienteId) async {
  final apiClient = ref.read(apiClientProvider);
  return await apiClient.listPhotosByPatient(pacienteId: pacienteId);
});
