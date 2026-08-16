use crate::backup::{create_backup as create_backup_impl, restore_backup as restore_backup_impl};

pub fn create_backup(output_path: String) -> Result<(), String> {
    create_backup_impl(&output_path).map_err(|e| e.to_string())
}

pub fn restore_backup(zip_path: String) -> Result<(), String> {
    restore_backup_impl(&zip_path).map_err(|e| e.to_string())
}
