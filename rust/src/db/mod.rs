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
        let mut conn = Connection::open(db_path)?;
        
        // Aplicar migraciones
        migrations::apply_migrations(&mut conn)?;
        
        // Guardar conexión en el estado global
        DB_CONN.set(Mutex::new(conn)).map_err(|_| AppError::IoError("Database already initialized".into()))?;
        
        Ok(())
    }

    pub fn get_conn() -> Result<std::sync::MutexGuard<'static, Connection>, AppError> {
        let mutex = DB_CONN.get().ok_or_else(|| AppError::IoError("Database not initialized".into()))?;
        let guard = mutex.lock().map_err(|_| AppError::IoError("Failed to lock database".into()))?;
        Ok(guard)
    }
}
