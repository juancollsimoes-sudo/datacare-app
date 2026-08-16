import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../../rust/db/models.dart';

abstract class ApiClient {
  Future<PaginatedPacientes> listPacientes({
    String? search,
    required int page,
    required int pageSize,
  });

  Future<Paciente?> getPaciente({required PlatformInt64 id});

  Future<PlatformInt64> createPaciente({required NuevoPaciente paciente});

  Future<void> updatePaciente({required ActualizarPaciente paciente});

  Future<void> deactivatePaciente({required PlatformInt64 id});

  // Tratamientos
  Future<PlatformInt64> createTratamiento({required NuevoTratamiento tratamiento});
  Future<List<Tratamiento>> listTratamientos();
  Future<void> updateTratamiento({required ActualizarTratamiento tratamiento});

  // Sesiones
  Future<PlatformInt64> createSesion({required NuevaSesion sesion});
  Future<PaginatedSesiones> listSesionesByPaciente({
    required PlatformInt64 pacienteId,
    required int page,
    required int pageSize,
  });
  Future<Sesion?> getSesion({required PlatformInt64 id});
  Future<void> updateSesion({required ActualizarSesion sesion});

  // Dashboard
  Future<DashboardStats> getDashboardStats();

  // Fotos
  Future<FotoSesion> saveSessionPhoto({
    required PlatformInt64 pacienteId,
    required PlatformInt64 sesionId,
    required String inputPath,
    String? tipo,
    String? descripcion,
  });
  Future<void> deletePhoto({required PlatformInt64 fotoId});
  Future<List<FotoSesion>> listPhotosBySession({required PlatformInt64 sesionId});
  Future<List<FotoSesion>> listPhotosByPatient({required PlatformInt64 pacienteId});
}
