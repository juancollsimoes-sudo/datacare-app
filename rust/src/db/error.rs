use rusqlite;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Database error: {0}")]
    DatabaseError(#[from] rusqlite::Error),
    #[error("Not found: {0}")]
    NotFound(String),
    #[error("Validation error: {0}")]
    ValidationError(String),
    #[error("IO error: {0}")]
    IoError(String),
    #[error("Other error: {0}")]
    Other(String),
}

impl AppError {
    pub fn to_string_err(&self) -> String {
        self.to_string()
    }
}
