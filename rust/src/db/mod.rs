pub mod error;
pub mod migrations;
pub mod models;
pub mod repository;

use crate::db::error::AppError;
use rusqlite::Connection;
use std::sync::{Mutex, OnceLock};

pub static DB_CONN: OnceLock<Mutex<Connection>> = OnceLock::new();

pub struct DatabaseManager;

impl DatabaseManager {
    pub fn init(db_path: &str) -> Result<(), AppError> {
        if let Some(mutex) = DB_CONN.get() {
            let mut conn = mutex.lock().map_err(|_| AppError::IoError("Failed to lock database".into()))?;
            migrations::apply_migrations(&mut conn)?;
            return Ok(());
        }

        let mut conn = Connection::open(db_path)?;
        
        // Aplicar migraciones
        migrations::apply_migrations(&mut conn)?;
        
        // Guardar conexión en el estado global
        let _ = DB_CONN.set(Mutex::new(conn));
        
        Ok(())
    }

    pub fn get_conn() -> Result<std::sync::MutexGuard<'static, Connection>, AppError> {
        let mutex = DB_CONN.get().ok_or_else(|| AppError::IoError("Database not initialized".into()))?;
        let guard = mutex.lock().map_err(|_| AppError::IoError("Failed to lock database".into()))?;
        Ok(guard)
    }
}
