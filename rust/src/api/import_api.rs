use crate::api::db_api::create_paciente;
use crate::db::models::{NuevoPaciente, NuevaImportacion};
use crate::db::repository::ImportacionRepo;
use crate::db::DatabaseManager;
use crate::parser::{parse_excel, ExcelRow};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportResult {
    pub total: i64,
    pub exitos: i64,
    pub errores: i64,
    pub detalle: String,
}

pub fn import_pacientes_from_excel(file_path: String) -> Result<ImportResult, String> {
    let rows = parse_excel(file_path.clone())?;
    
    let total = rows.len() as i64;
    let mut exitos = 0;
    let mut errores = 0;
    let mut detalle_errores = String::new();

    for (index, row) in rows.into_iter().enumerate() {
        let nuevo = NuevoPaciente {
            nombre: row.nombre,
            apellido: row.apellido,
            fecha_nacimiento: None,
            telefono: row.telefono,
            email: row.email,
            direccion: None,
            notas_generales: row.notas,
            alergias: None,
            condiciones_medicas: None,
        };

        match create_paciente(nuevo) {
            Ok(_) => { exitos += 1; },
            Err(e) => {
                errores += 1;
                detalle_errores.push_str(&format!("Fila {}: {}\n", index + 2, e));
            }
        }
    }

    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    let log_detalle = if detalle_errores.is_empty() { None } else { Some(detalle_errores.clone()) };
    
    let importacion = NuevaImportacion {
        archivo_origen: file_path,
        filas_ok: exitos,
        filas_warning: 0,
        filas_error: errores,
        log_detalle,
    };

    let _ = ImportacionRepo::crear(&conn, &importacion);

    Ok(ImportResult {
        total,
        exitos,
        errores,
        detalle: detalle_errores,
    })
}
