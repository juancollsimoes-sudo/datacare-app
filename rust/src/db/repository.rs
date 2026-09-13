use crate::db::error::AppError;
use crate::db::models::*;
use rusqlite::{params, Connection, OptionalExtension};

// --- PACIENTES ---
pub struct PacienteRepo;

impl PacienteRepo {
    pub fn crear(conn: &Connection, p: &NuevoPaciente) -> Result<i64, AppError> {
        conn.execute(
            "INSERT INTO pacientes (
                nombre, apellido, fecha_nacimiento, telefono, email, direccion, 
                notas_generales, alergias, condiciones_medicas,
                afecciones_cutaneas, tatuajes, cirugia_plastica, antecedentes_medicos,
                ubicacion_lesiones, tipo_piel, cicatrizacion, diagnostico_visual, diagnostico_tactil
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18)",
            params![
                p.nombre, p.apellido, p.fecha_nacimiento, p.telefono, p.email,
                p.direccion, p.notas_generales, p.alergias, p.condiciones_medicas,
                p.afecciones_cutaneas, p.tatuajes, p.cirugia_plastica, p.antecedentes_medicos,
                p.ubicacion_lesiones, p.tipo_piel, p.cicatrizacion, p.diagnostico_visual, p.diagnostico_tactil
            ],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn listar(
        conn: &Connection,
        search: Option<String>,
        page: i32,
        page_size: i32,
    ) -> Result<PaginatedPacientes, AppError> {
        let offset = (page.max(1) - 1) * page_size;
        
        let search_pattern = match search {
            Some(s) if !s.trim().is_empty() => format!("%{}%", s.trim()),
            _ => "%".to_string(),
        };

        let total: i64 = conn.query_row(
            "SELECT COUNT(*) FROM pacientes WHERE activo = 1 AND (nombre LIKE ?1 OR apellido LIKE ?1)",
            params![search_pattern],
            |row| row.get(0),
        )?;

        let mut stmt = conn.prepare(
            "SELECT id, nombre, apellido, fecha_nacimiento, telefono, email, direccion,
                    notas_generales, alergias, condiciones_medicas, fecha_registro, activo,
                    afecciones_cutaneas, tatuajes, cirugia_plastica, antecedentes_medicos,
                    ubicacion_lesiones, tipo_piel, cicatrizacion, diagnostico_visual, diagnostico_tactil
             FROM pacientes
             WHERE activo = 1 AND (nombre LIKE ?1 OR apellido LIKE ?1)
             ORDER BY apellido, nombre
             LIMIT ?2 OFFSET ?3"
        )?;

        let iter = stmt.query_map(params![search_pattern, page_size, offset], |row| {
            let activo_int: i32 = row.get(11)?;
            Ok(Paciente {
                id: row.get(0)?,
                nombre: row.get(1)?,
                apellido: row.get(2)?,
                fecha_nacimiento: row.get(3)?,
                telefono: row.get(4)?,
                email: row.get(5)?,
                direccion: row.get(6)?,
                notas_generales: row.get(7)?,
                alergias: row.get(8)?,
                condiciones_medicas: row.get(9)?,
                fecha_registro: row.get(10)?,
                activo: activo_int > 0,
                afecciones_cutaneas: row.get(12)?,
                tatuajes: row.get(13)?,
                cirugia_plastica: row.get(14)?,
                antecedentes_medicos: row.get(15)?,
                ubicacion_lesiones: row.get(16)?,
                tipo_piel: row.get(17)?,
                cicatrizacion: row.get(18)?,
                diagnostico_visual: row.get(19)?,
                diagnostico_tactil: row.get(20)?,
            })
        })?;

        let mut items = Vec::new();
        for item in iter {
            items.push(item?);
        }

        Ok(PaginatedPacientes {
            items,
            total,
            page,
            page_size,
        })
    }

    pub fn obtener(conn: &Connection, id: i64) -> Result<Option<Paciente>, AppError> {
        let mut stmt = conn.prepare(
            "SELECT id, nombre, apellido, fecha_nacimiento, telefono, email, direccion,
                    notas_generales, alergias, condiciones_medicas, fecha_registro, activo,
                    afecciones_cutaneas, tatuajes, cirugia_plastica, antecedentes_medicos,
                    ubicacion_lesiones, tipo_piel, cicatrizacion, diagnostico_visual, diagnostico_tactil
             FROM pacientes WHERE id = ?1"
        )?;
        
        let paciente = stmt.query_row(params![id], |row| {
            let activo_int: i32 = row.get(11)?;
            Ok(Paciente {
                id: row.get(0)?,
                nombre: row.get(1)?,
                apellido: row.get(2)?,
                fecha_nacimiento: row.get(3)?,
                telefono: row.get(4)?,
                email: row.get(5)?,
                direccion: row.get(6)?,
                notas_generales: row.get(7)?,
                alergias: row.get(8)?,
                condiciones_medicas: row.get(9)?,
                fecha_registro: row.get(10)?,
                activo: activo_int > 0,
                afecciones_cutaneas: row.get(12)?,
                tatuajes: row.get(13)?,
                cirugia_plastica: row.get(14)?,
                antecedentes_medicos: row.get(15)?,
                ubicacion_lesiones: row.get(16)?,
                tipo_piel: row.get(17)?,
                cicatrizacion: row.get(18)?,
                diagnostico_visual: row.get(19)?,
                diagnostico_tactil: row.get(20)?,
            })
        }).optional()?;

        Ok(paciente)
    }

    pub fn actualizar(conn: &Connection, p: &ActualizarPaciente) -> Result<(), AppError> {
        conn.execute(
            "UPDATE pacientes SET
                nombre = ?1, apellido = ?2, fecha_nacimiento = ?3, telefono = ?4,
                email = ?5, direccion = ?6, notas_generales = ?7, alergias = ?8,
                condiciones_medicas = ?9, afecciones_cutaneas = ?10, tatuajes = ?11,
                cirugia_plastica = ?12, antecedentes_medicos = ?13, ubicacion_lesiones = ?14,
                tipo_piel = ?15, cicatrizacion = ?16, diagnostico_visual = ?17, diagnostico_tactil = ?18
             WHERE id = ?19",
            params![
                p.nombre, p.apellido, p.fecha_nacimiento, p.telefono, p.email,
                p.direccion, p.notas_generales, p.alergias, p.condiciones_medicas,
                p.afecciones_cutaneas, p.tatuajes, p.cirugia_plastica, p.antecedentes_medicos,
                p.ubicacion_lesiones, p.tipo_piel, p.cicatrizacion, p.diagnostico_visual, p.diagnostico_tactil,
                p.id
            ],
        )?;
        Ok(())
    }

    pub fn desactivar(conn: &Connection, id: i64) -> Result<(), AppError> {
        conn.execute("UPDATE pacientes SET activo = 0 WHERE id = ?1", params![id])?;
        Ok(())
    }
}

// --- TRATAMIENTOS ---
pub struct TratamientoRepo;

impl TratamientoRepo {
    pub fn crear(conn: &Connection, t: &NuevoTratamiento) -> Result<i64, AppError> {
        conn.execute(
            "INSERT INTO tratamientos (nombre, descripcion, duracion_min, precio)
             VALUES (?1, ?2, ?3, ?4)",
            params![t.nombre, t.descripcion, t.duracion_min, t.precio],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn listar(conn: &Connection) -> Result<Vec<Tratamiento>, AppError> {
        let mut stmt = conn.prepare(
            "SELECT id, nombre, descripcion, duracion_min, precio, activo
             FROM tratamientos WHERE activo = 1 ORDER BY nombre"
        )?;

        let iter = stmt.query_map([], |row| {
            let activo_int: i32 = row.get(5)?;
            Ok(Tratamiento {
                id: row.get(0)?,
                nombre: row.get(1)?,
                descripcion: row.get(2)?,
                duracion_min: row.get(3)?,
                precio: row.get(4)?,
                activo: activo_int > 0,
            })
        })?;

        let mut items = Vec::new();
        for item in iter {
            items.push(item?);
        }
        Ok(items)
    }
    
    pub fn obtener(conn: &Connection, id: i64) -> Result<Option<Tratamiento>, AppError> {
        let mut stmt = conn.prepare(
            "SELECT id, nombre, descripcion, duracion_min, precio, activo
             FROM tratamientos WHERE id = ?1"
        )?;
        let t = stmt.query_row(params![id], |row| {
            let activo_int: i32 = row.get(5)?;
            Ok(Tratamiento {
                id: row.get(0)?,
                nombre: row.get(1)?,
                descripcion: row.get(2)?,
                duracion_min: row.get(3)?,
                precio: row.get(4)?,
                activo: activo_int > 0,
            })
        }).optional()?;
        Ok(t)
    }

    pub fn actualizar(conn: &Connection, t: &ActualizarTratamiento) -> Result<(), AppError> {
        conn.execute(
            "UPDATE tratamientos SET
                nombre = ?1, descripcion = ?2, duracion_min = ?3, precio = ?4
             WHERE id = ?5",
            params![t.nombre, t.descripcion, t.duracion_min, t.precio, t.id],
        )?;
        Ok(())
    }

    pub fn desactivar(conn: &Connection, id: i64) -> Result<(), AppError> {
        conn.execute(
            "UPDATE tratamientos SET activo = 0 WHERE id = ?1",
            params![id],
        )?;
        Ok(())
    }
}

// --- SESIONES ---
pub struct SesionRepo;

fn row_to_sesion(row: &rusqlite::Row) -> Result<Sesion, rusqlite::Error> {
    let pagado_int: i32 = row.get(8)?;
    Ok(Sesion {
        id: row.get(0)?,
        paciente_id: row.get(1)?,
        tratamiento_id: row.get(2)?,
        fecha: row.get(3)?,
        notas_sesion: row.get(4)?,
        observaciones: row.get(5)?,
        productos_usados: row.get(6)?,
        precio_cobrado: row.get(7)?,
        pagado: pagado_int > 0,
        created_at: row.get(9)?,
        tipo: row.get(10)?,
        peso: row.get(11)?,
        altura: row.get(12)?,
        imc: row.get(13)?,
        grasa_corporal: row.get(14)?,
        agua_corporal: row.get(15)?,
        medida_cadera: row.get(16)?,
        medida_cintura: row.get(17)?,
        medida_brazos: row.get(18)?,
        medida_pecho: row.get(19)?,
        medida_piernas: row.get(20)?,
    })
}

const SESION_COLUMNS: &str = "id, paciente_id, tratamiento_id, fecha, notas_sesion, observaciones,
        productos_usados, precio_cobrado, pagado, created_at,
        tipo, peso, altura, imc, grasa_corporal, agua_corporal,
        medida_cadera, medida_cintura, medida_brazos, medida_pecho, medida_piernas";

impl SesionRepo {
    pub fn crear(conn: &Connection, s: &NuevaSesion) -> Result<i64, AppError> {
        let pagado_int = if s.pagado { 1 } else { 0 };
        let tipo = s.tipo.as_deref().unwrap_or("facial");
        conn.execute(
            "INSERT INTO sesiones (
                paciente_id, tratamiento_id, fecha, notas_sesion, observaciones,
                productos_usados, precio_cobrado, pagado, tipo, peso, altura,
                imc, grasa_corporal, agua_corporal, medida_cadera, medida_cintura,
                medida_brazos, medida_pecho, medida_piernas
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19)",
            params![
                s.paciente_id, s.tratamiento_id, s.fecha, s.notas_sesion,
                s.observaciones, s.productos_usados, s.precio_cobrado, pagado_int,
                tipo, s.peso, s.altura, s.imc, s.grasa_corporal, s.agua_corporal,
                s.medida_cadera, s.medida_cintura, s.medida_brazos, s.medida_pecho, s.medida_piernas
            ],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn listar_por_paciente(
        conn: &Connection,
        paciente_id: i64,
        page: i32,
        page_size: i32,
    ) -> Result<PaginatedSesiones, AppError> {
        let offset = (page.max(1) - 1) * page_size;

        let total: i64 = conn.query_row(
            "SELECT COUNT(*) FROM sesiones WHERE paciente_id = ?1",
            params![paciente_id],
            |row| row.get(0),
        )?;

        let query = format!(
            "SELECT {} FROM sesiones WHERE paciente_id = ?1 ORDER BY fecha DESC, id DESC LIMIT ?2 OFFSET ?3",
            SESION_COLUMNS
        );
        let mut stmt = conn.prepare(&query)?;

        let iter = stmt.query_map(params![paciente_id, page_size, offset], |row| {
            row_to_sesion(row)
        })?;

        let mut items = Vec::new();
        for item in iter {
            items.push(item?);
        }

        Ok(PaginatedSesiones {
            items,
            total,
            page,
            page_size,
        })
    }

    pub fn listar_corporales_por_paciente(
        conn: &Connection,
        paciente_id: i64,
    ) -> Result<Vec<Sesion>, AppError> {
        let query = format!(
            "SELECT {} FROM sesiones 
             WHERE paciente_id = ?1 AND (tipo = 'corporal' OR grasa_corporal IS NOT NULL OR peso IS NOT NULL OR imc IS NOT NULL) 
             ORDER BY fecha ASC, id ASC",
            SESION_COLUMNS
        );
        let mut stmt = conn.prepare(&query)?;

        let iter = stmt.query_map(params![paciente_id], |row| {
            row_to_sesion(row)
        })?;

        let mut items = Vec::new();
        for item in iter {
            items.push(item?);
        }
        Ok(items)
    }

    pub fn list_ingresos(conn: &Connection) -> Result<Vec<Sesion>, AppError> {
        let query = format!(
            "SELECT {} FROM sesiones WHERE precio_cobrado > 0 AND pagado = 1 ORDER BY fecha DESC",
            SESION_COLUMNS
        );
        let mut stmt = conn.prepare(&query)?;

        let iter = stmt.query_map([], |row| {
            row_to_sesion(row)
        })?;

        let mut items = Vec::new();
        for item in iter {
            items.push(item?);
        }
        Ok(items)
    }

    pub fn obtener(conn: &Connection, id: i64) -> Result<Option<Sesion>, AppError> {
        let query = format!("SELECT {} FROM sesiones WHERE id = ?1", SESION_COLUMNS);
        let mut stmt = conn.prepare(&query)?;
        let s = stmt.query_row(params![id], |row| {
            row_to_sesion(row)
        }).optional()?;
        Ok(s)
    }

    pub fn actualizar(conn: &Connection, s: &ActualizarSesion) -> Result<(), AppError> {
        let pagado_int = if s.pagado { 1 } else { 0 };
        let tipo = s.tipo.as_deref().unwrap_or("facial");
        conn.execute(
            "UPDATE sesiones SET
                tratamiento_id = ?1, fecha = ?2, notas_sesion = ?3, observaciones = ?4,
                productos_usados = ?5, precio_cobrado = ?6, pagado = ?7,
                tipo = ?8, peso = ?9, altura = ?10, imc = ?11, grasa_corporal = ?12,
                agua_corporal = ?13, medida_cadera = ?14, medida_cintura = ?15,
                medida_brazos = ?16, medida_pecho = ?17, medida_piernas = ?18
             WHERE id = ?19",
            params![
                s.tratamiento_id, s.fecha, s.notas_sesion, s.observaciones,
                s.productos_usados, s.precio_cobrado, pagado_int,
                tipo, s.peso, s.altura, s.imc, s.grasa_corporal, s.agua_corporal,
                s.medida_cadera, s.medida_cintura, s.medida_brazos, s.medida_pecho,
                s.medida_piernas, s.id
            ],
        )?;
        Ok(())
    }
}

pub struct FotoRepo;

impl FotoRepo {
    pub fn list_fotos_by_sesion(conn: &rusqlite::Connection, sesion_id: i64) -> Result<Vec<crate::db::models::FotoSesion>, AppError> {
        let mut stmt = conn.prepare(
            "SELECT id, sesion_id, ruta_foto, ruta_thumb, tipo, descripcion, created_at
             FROM fotos_sesion
             WHERE sesion_id = ?
             ORDER BY created_at DESC"
        )?;

        let fotos = stmt.query_map([sesion_id], |row| {
            Ok(crate::db::models::FotoSesion {
                id: row.get(0)?,
                sesion_id: row.get(1)?,
                ruta_foto: row.get(2)?,
                ruta_thumb: row.get(3)?,
                tipo: row.get(4)?,
                descripcion: row.get(5)?,
                created_at: row.get(6)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;

        Ok(fotos)
    }

    pub fn list_fotos_by_paciente(conn: &rusqlite::Connection, paciente_id: i64) -> Result<Vec<crate::db::models::FotoSesion>, AppError> {
        let mut stmt = conn.prepare(
            "SELECT f.id, f.sesion_id, f.ruta_foto, f.ruta_thumb, f.tipo, f.descripcion, f.created_at
             FROM fotos_sesion f
             INNER JOIN sesiones s ON f.sesion_id = s.id
             WHERE s.paciente_id = ?
             ORDER BY f.created_at DESC"
        )?;

        let fotos = stmt.query_map([paciente_id], |row| {
            Ok(crate::db::models::FotoSesion {
                id: row.get(0)?,
                sesion_id: row.get(1)?,
                ruta_foto: row.get(2)?,
                ruta_thumb: row.get(3)?,
                tipo: row.get(4)?,
                descripcion: row.get(5)?,
                created_at: row.get(6)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;

        Ok(fotos)
    }

    pub fn insert_foto(conn: &rusqlite::Connection, sesion_id: i64, ruta_foto: &str, ruta_thumb: Option<&str>, tipo: Option<&str>, descripcion: Option<&str>) -> Result<crate::db::models::FotoSesion, AppError> {
        conn.execute(
            "INSERT INTO fotos_sesion (sesion_id, ruta_foto, ruta_thumb, tipo, descripcion)
             VALUES (?, ?, ?, ?, ?)",
            rusqlite::params![sesion_id, ruta_foto, ruta_thumb, tipo, descripcion],
        )?;

        let id = conn.last_insert_rowid();
        Self::get_foto(conn, id)
    }

    pub fn get_foto(conn: &rusqlite::Connection, id: i64) -> Result<crate::db::models::FotoSesion, AppError> {
        conn.query_row(
            "SELECT id, sesion_id, ruta_foto, ruta_thumb, tipo, descripcion, created_at
             FROM fotos_sesion WHERE id = ?",
            [id],
            |row| {
                Ok(crate::db::models::FotoSesion {
                    id: row.get(0)?,
                    sesion_id: row.get(1)?,
                    ruta_foto: row.get(2)?,
                    ruta_thumb: row.get(3)?,
                    tipo: row.get(4)?,
                    descripcion: row.get(5)?,
                    created_at: row.get(6)?,
                })
            },
        ).map_err(Into::into)
    }

    pub fn delete_foto(conn: &rusqlite::Connection, id: i64) -> Result<(), AppError> {
        conn.execute("DELETE FROM fotos_sesion WHERE id = ?", [id])?;
        Ok(())
    }
}

// --- IMPORTACIONES ---
pub struct ImportacionRepo;

impl ImportacionRepo {
    pub fn crear(conn: &Connection, i: &NuevaImportacion) -> Result<i64, AppError> {
        conn.execute(
            "INSERT INTO importaciones (
                archivo_origen, filas_ok, filas_warning, filas_error, log_detalle
            ) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                i.archivo_origen, i.filas_ok, i.filas_warning, i.filas_error, i.log_detalle
            ],
        )?;
        Ok(conn.last_insert_rowid())
    }
}

pub struct StatsRepo;

impl StatsRepo {
    pub fn get_dashboard_stats(conn: &Connection) -> Result<DashboardStats, AppError> {
        let total_pacientes_activos: i64 = conn.query_row(
            "SELECT COUNT(*) FROM pacientes WHERE activo = 1",
            [],
            |row| row.get(0),
        ).unwrap_or(0);

        let sesiones_este_mes: i64 = conn.query_row(
            "SELECT COUNT(*) FROM sesiones WHERE strftime('%Y-%m', fecha) = strftime('%Y-%m', 'now')",
            [],
            |row| row.get(0),
        ).unwrap_or(0);

        let tratamientos_registrados: i64 = conn.query_row(
            "SELECT COUNT(*) FROM tratamientos WHERE activo = 1",
            [],
            |row| row.get(0),
        ).unwrap_or(0);

        Ok(DashboardStats {
            total_pacientes_activos,
            sesiones_este_mes,
            tratamientos_registrados,
        })
    }
}

// --- GASTOS ---
pub struct GastoRepo;

impl GastoRepo {
    pub fn crear(conn: &Connection, g: &NuevoGasto) -> Result<i64, AppError> {
        conn.execute(
            "INSERT INTO gastos (nombre, descripcion, categoria, monto, fecha)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![g.nombre, g.descripcion, g.categoria, g.monto, g.fecha],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn listar(conn: &Connection) -> Result<Vec<Gasto>, AppError> {
        let mut stmt = conn.prepare(
            "SELECT id, nombre, descripcion, categoria, monto, fecha
             FROM gastos ORDER BY fecha DESC"
        )?;

        let iter = stmt.query_map([], |row| {
            Ok(Gasto {
                id: row.get(0)?,
                nombre: row.get(1)?,
                descripcion: row.get(2)?,
                categoria: row.get(3)?,
                monto: row.get(4)?,
                fecha: row.get(5)?,
            })
        })?;

        let mut items = Vec::new();
        for item in iter {
            items.push(item?);
        }
        Ok(items)
    }

    pub fn eliminar(conn: &Connection, id: i64) -> Result<(), AppError> {
        conn.execute("DELETE FROM gastos WHERE id = ?1", params![id])?;
        Ok(())
    }

    pub fn actualizar(conn: &Connection, g: &Gasto) -> Result<(), AppError> {
        conn.execute(
            "UPDATE gastos SET nombre = ?1, descripcion = ?2, categoria = ?3, monto = ?4, fecha = ?5 WHERE id = ?6",
            params![g.nombre, g.descripcion, g.categoria, g.monto, g.fecha, g.id],
        )?;
        Ok(())
    }
}

