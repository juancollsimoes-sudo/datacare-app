import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../../rust/db/models.dart';
import '../../rust/api/db_api.dart' as db_api;
import '../../rust/api/photos_api.dart' as photos_api;
import 'api_client.dart';

class DesktopApiClient implements ApiClient {
  @override
  Future<PaginatedPacientes> listPacientes({
    String? search,
    required int page,
    required int pageSize,
  }) {
    return db_api.listPacientes(search: search, page: page, pageSize: pageSize);
  }

  @override
  Future<Paciente?> getPaciente({required PlatformInt64 id}) {
    return db_api.getPaciente(id: id);
  }

  @override
  Future<PlatformInt64> createPaciente({required NuevoPaciente paciente}) {
    return db_api.createPaciente(paciente: paciente);
  }

  @override
  Future<void> updatePaciente({required ActualizarPaciente paciente}) {
    return db_api.updatePaciente(paciente: paciente);
  }

  @override
  Future<void> deactivatePaciente({required PlatformInt64 id}) {
    return db_api.deactivatePaciente(id: id);
  }

  // Tratamientos
  @override
  Future<PlatformInt64> createTratamiento({required NuevoTratamiento tratamiento}) {
    return db_api.createTratamiento(tratamiento: tratamiento);
  }

  @override
  Future<List<Tratamiento>> listTratamientos() {
    return db_api.listTratamientos();
  }

  @override
  Future<void> updateTratamiento({required ActualizarTratamiento tratamiento}) {
    return db_api.updateTratamiento(tratamiento: tratamiento);
  }

  // Sesiones
  @override
  Future<PlatformInt64> createSesion({required NuevaSesion sesion}) {
    return db_api.createSesion(sesion: sesion);
  }

  @override
  Future<PaginatedSesiones> listSesionesByPaciente({
    required PlatformInt64 pacienteId,
    required int page,
    required int pageSize,
  }) {
    return db_api.listSesionesByPaciente(pacienteId: pacienteId, page: page, pageSize: pageSize);
  }

  @override
  Future<Sesion?> getSesion({required PlatformInt64 id}) {
    return db_api.getSesion(id: id);
  }

  @override
  Future<void> updateSesion({required ActualizarSesion sesion}) {
    return db_api.updateSesion(sesion: sesion);
  }

  // Dashboard
  @override
  Future<DashboardStats> getDashboardStats() {
    return db_api.getDashboardStats();
  }

  // Fotos
  @override
  Future<FotoSesion> saveSessionPhoto({
    required PlatformInt64 pacienteId,
    required PlatformInt64 sesionId,
    required String inputPath,
    String? tipo,
    String? descripcion,
  }) {
    return photos_api.saveSessionPhoto(
      pacienteId: pacienteId,
      sesionId: sesionId,
      inputPath: inputPath,
      tipo: tipo,
      descripcion: descripcion,
    );
  }

  @override
  Future<void> deletePhoto({required PlatformInt64 fotoId}) {
    return photos_api.deletePhoto(fotoId: fotoId);
  }

  @override
  Future<List<FotoSesion>> listPhotosBySession({required PlatformInt64 sesionId}) {
    return photos_api.listPhotosBySession(sesionId: sesionId);
  }

  @override
  Future<List<FotoSesion>> listPhotosByPatient({required PlatformInt64 pacienteId}) {
    return photos_api.listPhotosByPatient(pacienteId: pacienteId);
  }
}
