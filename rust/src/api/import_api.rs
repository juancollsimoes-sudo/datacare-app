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

pub fn import_pacientes_from_excel(file_path: String) -> Result<ImportResult, String> {
    let patients = parse_excel(file_path.clone())?;

    let total = patients.len() as i64;
    let mut exitos: i64 = 0;
    let mut sesiones_creadas: i64 = 0;
    let mut duplicados: i64 = 0;
    let mut errores: i64 = 0;
    let mut detalle_errores = String::new();

    let mut conn = DatabaseManager::get_conn().map_err(|e| e.to_string_err())?;
    
    // Iniciar transacción
    let tx = conn.transaction().map_err(|e| e.to_string())?;

    for patient in patients {
        // Check for duplicate by name using the transaction connection
        let patient_id = match tx.query_row(
            "SELECT id FROM pacientes WHERE UPPER(nombre || ' ' || apellido) = UPPER(?1) AND activo = 1",
            [&format!("{} {}", patient.nombre, patient.apellido)],
            |row| row.get(0),
        ).ok() {
            Some(existing_id) => {
                duplicados += 1;
                // Update clinical and facial fields if available in Excel
                let _ = tx.execute(
                    "UPDATE pacientes SET
                        condiciones_medicas = COALESCE(?1, condiciones_medicas),
                        afecciones_cutaneas = COALESCE(?2, afecciones_cutaneas),
                        alergias = COALESCE(?3, alergias),
                        tatuajes = COALESCE(?4, tatuajes),
                        cirugia_plastica = COALESCE(?5, cirugia_plastica),
                        antecedentes_medicos = COALESCE(?6, antecedentes_medicos),
                        ubicacion_lesiones = COALESCE(?7, ubicacion_lesiones),
                        tipo_piel = COALESCE(?8, tipo_piel),
                        cicatrizacion = COALESCE(?9, cicatrizacion),
                        diagnostico_visual = COALESCE(?10, diagnostico_visual),
                        diagnostico_tactil = COALESCE(?11, diagnostico_tactil)
                     WHERE id = ?12",
                    rusqlite::params![
                        patient.condiciones_medicas,
                        patient.afecciones_cutaneas,
                        patient.alergias,
                        patient.tatuajes,
                        patient.cirugia_plastica,
                        patient.antecedentes_medicos,
                        patient.ubicacion_lesiones,
                        patient.tipo_piel,
                        patient.cicatrizacion,
                        patient.diagnostico_visual,
                        patient.diagnostico_tactil,
                        existing_id
                    ],
                );
                existing_id
            }
            None => {
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
                let notas_generales = if notas_parts.is_empty() { None } else { Some(notas_parts.join("\n")) };

                let nuevo = NuevoPaciente {
                    nombre: patient.nombre.clone(),
                    apellido: patient.apellido.clone(),
                    fecha_nacimiento: patient.fecha_nacimiento.clone(),
                    telefono: patient.telefono.clone(),
                    email: patient.email.clone(),
                    direccion: patient.direccion.clone(),
                    notas_generales,
                    alergias: patient.alergias.clone(),
                    condiciones_medicas: patient.condiciones_medicas.clone(),
                    afecciones_cutaneas: patient.afecciones_cutaneas.clone(),
                    tatuajes: patient.tatuajes.clone(),
                    cirugia_plastica: patient.cirugia_plastica.clone(),
                    antecedentes_medicos: patient.antecedentes_medicos.clone(),
                    ubicacion_lesiones: patient.ubicacion_lesiones.clone(),
                    tipo_piel: patient.tipo_piel.clone(),
                    cicatrizacion: patient.cicatrizacion.clone(),
                    diagnostico_visual: patient.diagnostico_visual.clone(),
                    diagnostico_tactil: patient.diagnostico_tactil.clone(),
                };

                match crate::db::repository::PacienteRepo::crear(&tx, &nuevo) {
                    Ok(id) => {
                        exitos += 1;
                        id
                    }
                    Err(e) => {
                        errores += 1;
                        detalle_errores.push_str(&format!("Error creando paciente '{}': {}\n", format!("{} {}", patient.nombre, patient.apellido), e));
                        continue;
                    }
                }
            }
        };

        for session in &patient.sesiones {
            let notas = if session.descripcion.trim().is_empty() {
                None
            } else {
                Some(session.descripcion.trim().to_string())
            };

            let exists: bool = tx.query_row(
                "SELECT EXISTS(SELECT 1 FROM sesiones WHERE paciente_id = ?1 AND fecha = ?2 AND tipo = ?3 AND (notas_sesion = ?4 OR (?4 IS NULL AND (notas_sesion IS NULL OR notas_sesion = ''))))",
                rusqlite::params![patient_id, session.fecha, session.tipo, notas],
                |row| row.get(0),
            ).unwrap_or(false);

            if exists {
                continue;
            }

            let nueva_sesion = NuevaSesion {
                paciente_id: patient_id,
                tratamiento_id: None,
                fecha: session.fecha.clone(),
                notas_sesion: notas,
                observaciones: None,
                productos_usados: None,
                precio_cobrado: None,
                pagado: false,
                tipo: Some(session.tipo.clone()),
                peso: session.peso.clone(),
                altura: session.altura,
                imc: session.imc,
                grasa_corporal: session.grasa_corporal,
                agua_corporal: session.agua_corporal,
                medida_cadera: session.medida_cadera.clone(),
                medida_cintura: session.medida_cintura.clone(),
                medida_brazos: session.medida_brazos.clone(),
                medida_pecho: session.medida_pecho.clone(),
                medida_piernas: session.medida_piernas.clone(),
            };

            match crate::db::repository::SesionRepo::crear(&tx, &nueva_sesion) {
                Ok(_) => { sesiones_creadas += 1; }
                Err(e) => {
                    errores += 1;
                    detalle_errores.push_str(&format!("Error creando sesión para '{}' ({}): {}\n", format!("{} {}", patient.nombre, patient.apellido), session.fecha, e));
                }
            }
        }
    }
    
    tx.commit().map_err(|e| e.to_string())?;

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
