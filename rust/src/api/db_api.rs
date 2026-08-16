use crate::db::models::*;
use crate::db::repository::{PacienteRepo, SesionRepo, TratamientoRepo};
use crate::db::DatabaseManager;

pub fn init_database(db_path: String) -> Result<(), String> {
    DatabaseManager::init(&db_path).map_err(|e| e.to_string_err())
}

// --- PACIENTES API ---
pub fn create_paciente(paciente: NuevoPaciente) -> Result<i64, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    PacienteRepo::crear(&conn, &paciente).map_err(|e| e.to_string_err())
}

pub fn list_pacientes(search: Option<String>, page: i32, page_size: i32) -> Result<PaginatedPacientes, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    PacienteRepo::listar(&conn, search, page, page_size).map_err(|e| e.to_string_err())
}

pub fn get_paciente(id: i64) -> Result<Option<Paciente>, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    PacienteRepo::obtener(&conn, id).map_err(|e| e.to_string_err())
}

pub fn update_paciente(paciente: ActualizarPaciente) -> Result<(), String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    PacienteRepo::actualizar(&conn, &paciente).map_err(|e| e.to_string_err())
}

pub fn deactivate_paciente(id: i64) -> Result<(), String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    PacienteRepo::desactivar(&conn, id).map_err(|e| e.to_string_err())
}

// --- TRATAMIENTOS API ---
pub fn create_tratamiento(tratamiento: NuevoTratamiento) -> Result<i64, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    TratamientoRepo::crear(&conn, &tratamiento).map_err(|e| e.to_string_err())
}

pub fn list_tratamientos() -> Result<Vec<Tratamiento>, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    TratamientoRepo::listar(&conn).map_err(|e| e.to_string_err())
}

pub fn update_tratamiento(tratamiento: ActualizarTratamiento) -> Result<(), String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    TratamientoRepo::actualizar(&conn, &tratamiento).map_err(|e| e.to_string_err())
}

// --- SESIONES API ---
pub fn create_sesion(sesion: NuevaSesion) -> Result<i64, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    SesionRepo::crear(&conn, &sesion).map_err(|e| e.to_string_err())
}

pub fn list_sesiones_by_paciente(paciente_id: i64, page: i32, page_size: i32) -> Result<PaginatedSesiones, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    SesionRepo::listar_por_paciente(&conn, paciente_id, page, page_size).map_err(|e| e.to_string_err())
}

pub fn get_sesion(id: i64) -> Result<Option<Sesion>, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    SesionRepo::obtener(&conn, id).map_err(|e| e.to_string_err())
}

pub fn update_sesion(sesion: ActualizarSesion) -> Result<(), String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    SesionRepo::actualizar(&conn, &sesion).map_err(|e| e.to_string_err())
}
