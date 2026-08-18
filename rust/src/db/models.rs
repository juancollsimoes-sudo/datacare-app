use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Paciente {
    pub id: i64,
    pub nombre: String,
    pub apellido: String,
    pub fecha_nacimiento: Option<String>,
    pub telefono: Option<String>,
    pub email: Option<String>,
    pub direccion: Option<String>,
    pub notas_generales: Option<String>,
    pub alergias: Option<String>,
    pub condiciones_medicas: Option<String>,
    pub fecha_registro: String,
    pub activo: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NuevoPaciente {
    pub nombre: String,
    pub apellido: String,
    pub fecha_nacimiento: Option<String>,
    pub telefono: Option<String>,
    pub email: Option<String>,
    pub direccion: Option<String>,
    pub notas_generales: Option<String>,
    pub alergias: Option<String>,
    pub condiciones_medicas: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActualizarPaciente {
    pub id: i64,
    pub nombre: String,
    pub apellido: String,
    pub fecha_nacimiento: Option<String>,
    pub telefono: Option<String>,
    pub email: Option<String>,
    pub direccion: Option<String>,
    pub notas_generales: Option<String>,
    pub alergias: Option<String>,
    pub condiciones_medicas: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tratamiento {
    pub id: i64,
    pub nombre: String,
    pub descripcion: Option<String>,
    pub duracion_min: Option<i64>,
    pub precio: Option<f64>,
    pub activo: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NuevoTratamiento {
    pub nombre: String,
    pub descripcion: Option<String>,
    pub duracion_min: Option<i64>,
    pub precio: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActualizarTratamiento {
    pub id: i64,
    pub nombre: String,
    pub descripcion: Option<String>,
    pub duracion_min: Option<i64>,
    pub precio: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Sesion {
    pub id: i64,
    pub paciente_id: i64,
    pub tratamiento_id: Option<i64>,
    pub fecha: String,
    pub notas_sesion: Option<String>,
    pub observaciones: Option<String>,
    pub productos_usados: Option<String>,
    pub precio_cobrado: Option<f64>,
    pub pagado: bool,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NuevaSesion {
    pub paciente_id: i64,
    pub tratamiento_id: Option<i64>,
    pub fecha: String,
    pub notas_sesion: Option<String>,
    pub observaciones: Option<String>,
    pub productos_usados: Option<String>,
    pub precio_cobrado: Option<f64>,
    pub pagado: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActualizarSesion {
    pub id: i64,
    pub tratamiento_id: Option<i64>,
    pub fecha: String,
    pub notas_sesion: Option<String>,
    pub observaciones: Option<String>,
    pub productos_usados: Option<String>,
    pub precio_cobrado: Option<f64>,
    pub pagado: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FotoSesion {
    pub id: i64,
    pub sesion_id: i64,
    pub ruta_foto: String,
    pub ruta_thumb: Option<String>,
    pub tipo: Option<String>,
    pub descripcion: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Importacion {
    pub id: i64,
    pub archivo_origen: String,
    pub fecha_import: String,
    pub filas_ok: i64,
    pub filas_warning: i64,
    pub filas_error: i64,
    pub log_detalle: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginatedPacientes {
    pub items: Vec<Paciente>,
    pub total: i64,
    pub page: i32,
    pub page_size: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginatedSesiones {
    pub items: Vec<Sesion>,
    pub total: i64,
    pub page: i32,
    pub page_size: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NuevaImportacion {
    pub archivo_origen: String,
    pub filas_ok: i64,
    pub filas_warning: i64,
    pub filas_error: i64,
    pub log_detalle: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DashboardStats {
    pub total_pacientes_activos: i64,
    pub sesiones_este_mes: i64,
    pub tratamientos_registrados: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Gasto {
    pub id: i64,
    pub nombre: String,
    pub descripcion: Option<String>,
    pub categoria: Option<String>,
    pub monto: f64,
    pub fecha: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NuevoGasto {
    pub nombre: String,
    pub descripcion: Option<String>,
    pub categoria: Option<String>,
    pub monto: f64,
    pub fecha: String,
}
