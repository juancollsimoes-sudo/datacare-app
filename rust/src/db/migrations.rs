use crate::db::error::AppError;
use rusqlite::Connection;
use log::info;

pub fn apply_migrations(conn: &mut Connection) -> Result<(), AppError> {
    // Enable WAL and Foreign Keys
    conn.execute_batch(
        "PRAGMA journal_mode = WAL;
         PRAGMA foreign_keys = ON;",
    )?;

    // Create schema_version table if not exists
    conn.execute(
        "CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY,
            applied_at TEXT DEFAULT (datetime('now')),
            description TEXT
        )",
        [],
    )?;

    let migrations = vec![
        (
            1,
            "Initial schema",
            r#"
            -- Pacientes
            CREATE TABLE pacientes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL,
                apellido TEXT NOT NULL,
                fecha_nacimiento TEXT,
                telefono TEXT,
                email TEXT,
                direccion TEXT,
                notas_generales TEXT,
                alergias TEXT,
                condiciones_medicas TEXT,
                fecha_registro TEXT DEFAULT (datetime('now')),
                activo INTEGER DEFAULT 1
            );

            -- Tratamientos
            CREATE TABLE tratamientos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL UNIQUE,
                descripcion TEXT,
                duracion_min INTEGER,
                precio REAL,
                activo INTEGER DEFAULT 1
            );

            -- Sesiones
            CREATE TABLE sesiones (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                paciente_id INTEGER NOT NULL REFERENCES pacientes(id),
                tratamiento_id INTEGER REFERENCES tratamientos(id),
                fecha TEXT NOT NULL,
                notas_sesion TEXT,
                observaciones TEXT,
                productos_usados TEXT,
                precio_cobrado REAL,
                pagado INTEGER DEFAULT 0,
                created_at TEXT DEFAULT (datetime('now'))
            );

            -- Fotos
            CREATE TABLE fotos_sesion (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sesion_id INTEGER NOT NULL REFERENCES sesiones(id),
                ruta_foto TEXT NOT NULL,
                ruta_thumb TEXT,
                tipo TEXT CHECK(tipo IN ('antes', 'despues', 'durante', 'otra') OR tipo IS NULL),
                descripcion TEXT,
                created_at TEXT DEFAULT (datetime('now'))
            );

            -- Importaciones
            CREATE TABLE importaciones (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                archivo_origen TEXT NOT NULL,
                fecha_import TEXT DEFAULT (datetime('now')),
                filas_ok INTEGER DEFAULT 0,
                filas_warning INTEGER DEFAULT 0,
                filas_error INTEGER DEFAULT 0,
                log_detalle TEXT
            );

            -- Configuración
            CREATE TABLE configuracion (
                clave TEXT PRIMARY KEY,
                valor TEXT NOT NULL
            );

            -- Índices
            CREATE INDEX idx_pacientes_nombre ON pacientes(nombre, apellido);
            CREATE INDEX idx_sesiones_paciente ON sesiones(paciente_id);
            CREATE INDEX idx_sesiones_fecha ON sesiones(fecha);
            CREATE INDEX idx_fotos_sesion ON fotos_sesion(sesion_id);
            "#,
        ),
        (
            2,
            "Add gastos table",
            r#"
            CREATE TABLE gastos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT NOT NULL,
                descripcion TEXT,
                categoria TEXT,
                monto REAL NOT NULL,
                fecha TEXT NOT NULL
            );
            "#,
        ),
    ];

    let tx = conn.transaction()?;

    for (version, description, sql) in migrations {
        let applied: bool = tx.query_row(
            "SELECT EXISTS(SELECT 1 FROM schema_version WHERE version = ?)",
            [version],
            |row| row.get(0),
        )?;

        if !applied {
            info!("Applying migration V{}: {}", version, description);
            tx.execute_batch(sql)?;
            tx.execute(
                "INSERT INTO schema_version (version, description) VALUES (?, ?)",
                (version, description),
            )?;
        }
    }

    tx.commit()?;
    Ok(())
}
