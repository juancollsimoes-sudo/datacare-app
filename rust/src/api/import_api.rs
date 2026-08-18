use crate::api::db_api::{create_paciente, create_sesion};
use crate::db::models::{NuevoPaciente, NuevaSesion, NuevaImportacion};
use crate::db::repository::ImportacionRepo;
use crate::db::DatabaseManager;
use crate::parser::parse_excel;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportResult {
    pub total: i64,            // total sheets/patients processed
    pub exitos: i64,           // patients created
    pub sesiones_creadas: i64, // sessions created
    pub duplicados: i64,       // patients skipped (already existed)
    pub errores: i64,          // errors
    pub detalle: String,       // error details
}

/// Check if a patient with the given full name already exists in the DB.
/// Returns the patient ID if found.
fn find_patient_by_name(conn: &rusqlite::Connection, nombre: &str, apellido: &str) -> Option<i64> {
    conn.query_row(
        "SELECT id FROM pacientes WHERE UPPER(nombre || ' ' || apellido) = UPPER(?1) AND activo = 1",
        [&format!("{} {}", nombre, apellido)],
        |row| row.get(0),
    )
    .ok()
}

pub fn import_pacientes_from_excel(file_path: String) -> Result<ImportResult, String> {
    let patients = parse_excel(file_path.clone())?;

    let total = patients.len() as i64;
    let mut exitos: i64 = 0;
    let mut sesiones_creadas: i64 = 0;
    let mut duplicados: i64 = 0;
    let mut errores: i64 = 0;
    let mut detalle_errores = String::new();

    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;

    for patient in patients {
        // Check for duplicate by name
        let patient_id = match find_patient_by_name(&conn, &patient.nombre, &patient.apellido) {
            Some(existing_id) => {
                duplicados += 1;
                existing_id
            }
            None => {
                // Build notas_generales: combine parsed notas with profesión and cédula info
                let mut notas_parts = Vec::new();
                if let Some(ref cedula) = patient.cedula {
                    notas_parts.push(format!("Cédula: {}", cedula));
                }
                if let Some(ref profesion) = patient.profesion {
                    notas_parts.push(format!("Profesión: {}", profesion));
                }
                if let Some(ref notas) = patient.notas_generales {
                    notas_parts.push(notas.clone());
                }
                let notas_generales = if notas_parts.is_empty() {
                    None
                } else {
                    Some(notas_parts.join("\n"))
                };

                let nuevo = NuevoPaciente {
                    nombre: patient.nombre.clone(),
                    apellido: patient.apellido.clone(),
                    fecha_nacimiento: patient.fecha_nacimiento.clone(),
                    telefono: patient.telefono.clone(),
                    email: patient.email.clone(),
                    direccion: patient.direccion.clone(),
                    notas_generales,
                    alergias: None,
                    condiciones_medicas: patient.condiciones_medicas.clone(),
                };

                match create_paciente(nuevo) {
                    Ok(id) => {
                        exitos += 1;
                        id
                    }
                    Err(e) => {
                        errores += 1;
                        detalle_errores.push_str(&format!(
                            "Error creando paciente '{}': {}\n",
                            format!("{} {}", patient.nombre, patient.apellido),
                            e
                        ));
                        continue;
                    }
                }
            }
        };

        // Create sessions for this patient
        for session in &patient.sesiones {
            let nueva_sesion = NuevaSesion {
                paciente_id: patient_id,
                tratamiento_id: None,
                fecha: session.fecha.clone(),
                notas_sesion: Some(session.descripcion.clone()),
                observaciones: None,
                productos_usados: None,
                precio_cobrado: None,
                pagado: false,
            };

            match create_sesion(nueva_sesion) {
                Ok(_) => {
                    sesiones_creadas += 1;
                }
                Err(e) => {
                    errores += 1;
                    detalle_errores.push_str(&format!(
                        "Error creando sesión para '{}' ({}): {}\n",
                        format!("{} {}", patient.nombre, patient.apellido),
                        session.fecha,
                        e
                    ));
                }
            }
        }
    }

    // Log the import
    let log_detalle = if detalle_errores.is_empty() {
        None
    } else {
        Some(detalle_errores.clone())
    };

    let importacion = NuevaImportacion {
        archivo_origen: file_path,
        filas_ok: exitos,
        filas_warning: duplicados,
        filas_error: errores,
        log_detalle,
    };

    let _ = ImportacionRepo::crear(&conn, &importacion);

    Ok(ImportResult {
        total,
        exitos,
        sesiones_creadas,
        duplicados,
        errores,
        detalle: detalle_errores,
    })
}
