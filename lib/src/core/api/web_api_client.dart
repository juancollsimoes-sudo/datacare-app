import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../../rust/db/models.dart';
import 'api_client.dart';
import 'package:flutter/foundation.dart';

PlatformInt64 _toPlatformInt64(dynamic value) {
  if (value == null) return (kIsWeb ? BigInt.zero : 0) as PlatformInt64;
  if (kIsWeb) {
    return BigInt.parse(value.toString()) as PlatformInt64;
  } else {
    return int.parse(value.toString()) as PlatformInt64;
  }
}

class WebApiClient implements ApiClient {
  final String baseUrl;

  WebApiClient({this.baseUrl = 'http://localhost:8080/api'});

  @override
  Future<PaginatedPacientes> listPacientes({
    String? search,
    required int page,
    required int pageSize,
  }) async {
    final uri = Uri.parse('$baseUrl/pacientes').replace(queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final items = (json['items'] as List).map((item) => _parsePaciente(item)).toList();
      return PaginatedPacientes(
        items: items,
        total: _toPlatformInt64(json['total'] ?? 0),
        page: json['page'] ?? page,
        pageSize: json['pageSize'] ?? pageSize,
      );
    } else {
      throw Exception('Failed to load pacientes');
    }
  }

  @override
  Future<Paciente?> getPaciente({required PlatformInt64 id}) async {
    final uri = Uri.parse('$baseUrl/pacientes/${id.toInt()}');
    final response = await http.get(uri);
    
    if (response.statusCode == 200) {
      return _parsePaciente(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to get paciente');
    }
  }

  @override
  Future<PlatformInt64> createPaciente({required NuevoPaciente paciente}) async {
    final uri = Uri.parse('$baseUrl/pacientes');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': paciente.nombre,
        'apellido': paciente.apellido,
        'fechaNacimiento': paciente.fechaNacimiento,
        'telefono': paciente.telefono,
        'email': paciente.email,
        'direccion': paciente.direccion,
        'notasGenerales': paciente.notasGenerales,
        'alergias': paciente.alergias,
        'condicionesMedicas': paciente.condicionesMedicas,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return _toPlatformInt64(json['id'] ?? 0);
    } else {
      throw Exception('Failed to create paciente');
    }
  }

  @override
  Future<void> updatePaciente({required ActualizarPaciente paciente}) async {
    final uri = Uri.parse('$baseUrl/pacientes/${paciente.id.toInt()}');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': paciente.id.toInt(),
        'nombre': paciente.nombre,
        'apellido': paciente.apellido,
        'fechaNacimiento': paciente.fechaNacimiento,
        'telefono': paciente.telefono,
        'email': paciente.email,
        'direccion': paciente.direccion,
        'notasGenerales': paciente.notasGenerales,
        'alergias': paciente.alergias,
        'condicionesMedicas': paciente.condicionesMedicas,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update paciente');
    }
  }

  @override
  Future<void> deactivatePaciente({required PlatformInt64 id}) async {
    final uri = Uri.parse('$baseUrl/pacientes/${id.toInt()}/deactivate');
    final response = await http.post(uri);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to deactivate paciente');
    }
  }

  // Tratamientos
  @override
  Future<PlatformInt64> createTratamiento({required NuevoTratamiento tratamiento}) async {
    final uri = Uri.parse('$baseUrl/tratamientos');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': tratamiento.nombre,
        'descripcion': tratamiento.descripcion,
        'duracionMin': tratamiento.duracionMin?.toInt(),
        'precio': tratamiento.precio,
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return _toPlatformInt64(json['id'] ?? 0);
    }
    throw Exception('Failed to create tratamiento');
  }

  @override
  Future<List<Tratamiento>> listTratamientos() async {
    final uri = Uri.parse('$baseUrl/tratamientos');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return (json as List).map((item) => _parseTratamiento(item)).toList();
    }
    throw Exception('Failed to list tratamientos');
  }

  @override
  Future<void> updateTratamiento({required ActualizarTratamiento tratamiento}) async {
    final uri = Uri.parse('$baseUrl/tratamientos/${tratamiento.id.toInt()}');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': tratamiento.id.toInt(),
        'nombre': tratamiento.nombre,
        'descripcion': tratamiento.descripcion,
        'duracionMin': tratamiento.duracionMin?.toInt(),
        'precio': tratamiento.precio,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update tratamiento');
    }
  }

  // Sesiones
  @override
  Future<PlatformInt64> createSesion({required NuevaSesion sesion}) async {
    final uri = Uri.parse('$baseUrl/sesiones');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pacienteId': sesion.pacienteId.toInt(),
        'tratamientoId': sesion.tratamientoId?.toInt(),
        'fecha': sesion.fecha,
        'notasSesion': sesion.notasSesion,
        'observaciones': sesion.observaciones,
        'productosUsados': sesion.productosUsados,
        'precioCobrado': sesion.precioCobrado,
        'pagado': sesion.pagado,
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return _toPlatformInt64(json['id'] ?? 0);
    }
    throw Exception('Failed to create sesion');
  }

  @override
  Future<PaginatedSesiones> listSesionesByPaciente({
    required PlatformInt64 pacienteId,
    required int page,
    required int pageSize,
  }) async {
    final uri = Uri.parse('$baseUrl/pacientes/${pacienteId.toInt()}/sesiones').replace(queryParameters: {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final items = (json['items'] as List).map((item) => _parseSesion(item)).toList();
      return PaginatedSesiones(
        items: items,
        total: _toPlatformInt64(json['total'] ?? 0),
        page: json['page'] ?? page,
        pageSize: json['pageSize'] ?? pageSize,
      );
    }
    throw Exception('Failed to load sesiones');
  }

  @override
  Future<Sesion?> getSesion({required PlatformInt64 id}) async {
    final uri = Uri.parse('$baseUrl/sesiones/${id.toInt()}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return _parseSesion(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Failed to get sesion');
  }

  @override
  Future<void> updateSesion({required ActualizarSesion sesion}) async {
    final uri = Uri.parse('$baseUrl/sesiones/${sesion.id.toInt()}');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': sesion.id.toInt(),
        'tratamientoId': sesion.tratamientoId?.toInt(),
        'fecha': sesion.fecha,
        'notasSesion': sesion.notasSesion,
        'observaciones': sesion.observaciones,
        'productosUsados': sesion.productosUsados,
        'precioCobrado': sesion.precioCobrado,
        'pagado': sesion.pagado,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update sesion');
    }
  }

  // Dashboard
  @override
  Future<DashboardStats> getDashboardStats() async {
    final uri = Uri.parse('$baseUrl/stats');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return _parseDashboardStats(jsonDecode(response.body));
    }
    throw Exception('Failed to get dashboard stats');
  }

  // Fotos
  @override
  Future<FotoSesion> saveSessionPhoto({
    required PlatformInt64 pacienteId,
    required PlatformInt64 sesionId,
    required String inputPath,
    String? tipo,
    String? descripcion,
  }) async {
    // Note: To truly support file upload in Web, we should use http.MultipartRequest. 
    // This is a basic implementation assuming standard API semantics.
    final uri = Uri.parse('$baseUrl/fotos');
    final request = http.MultipartRequest('POST', uri);
    request.fields['pacienteId'] = pacienteId.toString();
    request.fields['sesionId'] = sesionId.toString();
    if (tipo != null) request.fields['tipo'] = tipo;
    if (descripcion != null) request.fields['descripcion'] = descripcion;
    // Assuming inputPath is either a web URL or we might need byte data (which is missing here without web specific adaptations)
    // In a real web app, `inputPath` is likely useless unless it's a blob URL, we should send bytes instead.
    
    final response = await request.send();
    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      return _parseFotoSesion(jsonDecode(body));
    }
    throw Exception('Failed to save photo');
  }

  @override
  Future<void> deletePhoto({required PlatformInt64 fotoId}) async {
    final uri = Uri.parse('$baseUrl/fotos/${fotoId.toInt()}');
    final response = await http.delete(uri);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete photo');
    }
  }

  @override
  Future<List<FotoSesion>> listPhotosBySession({required PlatformInt64 sesionId}) async {
    final uri = Uri.parse('$baseUrl/sesiones/${sesionId.toInt()}/fotos');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).map((i) => _parseFotoSesion(i)).toList();
    }
    throw Exception('Failed to list photos by session');
  }

  @override
  Future<List<FotoSesion>> listPhotosByPatient({required PlatformInt64 pacienteId}) async {
    final uri = Uri.parse('$baseUrl/pacientes/${pacienteId.toInt()}/fotos');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).map((i) => _parseFotoSesion(i)).toList();
    }
    throw Exception('Failed to list photos by patient');
  }

  Paciente _parsePaciente(Map<String, dynamic> json) {
    return Paciente(
      id: _toPlatformInt64(json['id']),
      nombre: json['nombre'],
      apellido: json['apellido'],
      fechaNacimiento: json['fechaNacimiento'],
      telefono: json['telefono'],
      email: json['email'],
      direccion: json['direccion'],
      notasGenerales: json['notasGenerales'],
      alergias: json['alergias'],
      condicionesMedicas: json['condicionesMedicas'],
      fechaRegistro: json['fechaRegistro'] ?? '',
      activo: json['activo'] ?? true,
    );
  }

  Tratamiento _parseTratamiento(Map<String, dynamic> json) {
    return Tratamiento(
      id: _toPlatformInt64(json['id']),
      nombre: json['nombre'],
      descripcion: json['descripcion'],
      duracionMin: json['duracionMin'] != null ? _toPlatformInt64(json['duracionMin']) : null,
      precio: (json['precio'] as num?)?.toDouble(),
      activo: json['activo'] ?? true,
    );
  }

  Sesion _parseSesion(Map<String, dynamic> json) {
    return Sesion(
      id: _toPlatformInt64(json['id']),
      pacienteId: _toPlatformInt64(json['pacienteId']),
      tratamientoId: json['tratamientoId'] != null ? _toPlatformInt64(json['tratamientoId']) : null,
      fecha: json['fecha'],
      notasSesion: json['notasSesion'],
      observaciones: json['observaciones'],
      productosUsados: json['productosUsados'],
      precioCobrado: (json['precioCobrado'] as num?)?.toDouble(),
      pagado: json['pagado'] ?? false,
      createdAt: json['createdAt'] ?? '',
    );
  }

  DashboardStats _parseDashboardStats(Map<String, dynamic> json) {
    return DashboardStats(
      totalPacientesActivos: _toPlatformInt64(json['totalPacientesActivos'] ?? 0),
      sesionesEsteMes: _toPlatformInt64(json['sesionesEsteMes'] ?? 0),
      tratamientosRegistrados: _toPlatformInt64(json['tratamientosRegistrados'] ?? 0),
    );
  }

  FotoSesion _parseFotoSesion(Map<String, dynamic> json) {
    return FotoSesion(
      id: _toPlatformInt64(json['id']),
      sesionId: _toPlatformInt64(json['sesionId']),
      rutaFoto: json['rutaFoto'],
      rutaThumb: json['rutaThumb'],
      tipo: json['tipo'],
      descripcion: json['descripcion'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}
