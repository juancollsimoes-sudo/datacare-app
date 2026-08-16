use crate::db::models::FotoSesion;
use crate::db::repository::FotoRepo;
use crate::db::DatabaseManager;
use crate::photos::PhotoManager;
use std::path::Path;

// Initialize PhotoManager with a base path (e.g. in the app data directory)
fn get_photo_manager() -> Result<PhotoManager, String> {
    // Determine a safe base dir. For a desktop app, ~/.local/share/datacare is good.
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let base_dir = std::path::PathBuf::from(home).join(".local").join("share").join("datacare");
    Ok(PhotoManager::new(base_dir))
}

pub fn save_session_photo(
    paciente_id: i64,
    sesion_id: i64,
    input_path: String,
    tipo: Option<String>,
    descripcion: Option<String>,
) -> Result<FotoSesion, String> {
    let pm = get_photo_manager()?;
    let path = Path::new(&input_path);
    if !path.exists() {
        return Err("File does not exist".to_string());
    }

    let (master_path, thumb_path) = pm.process_and_save(paciente_id, sesion_id, path)
        .map_err(|e| e.to_string())?;

    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string())?;
    
    FotoRepo::insert_foto(
        &conn, 
        sesion_id, 
        &master_path, 
        Some(&thumb_path), 
        tipo.as_deref(), 
        descripcion.as_deref()
    ).map_err(|e| e.to_string())
}

pub fn delete_photo(foto_id: i64) -> Result<(), String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string())?;
    let foto = FotoRepo::get_foto(&conn, foto_id).map_err(|e| e.to_string())?;
    
    let pm = get_photo_manager()?;
    pm.delete_photos(&foto.ruta_foto, foto.ruta_thumb.as_deref()).map_err(|e| e.to_string())?;
    
    FotoRepo::delete_foto(&conn, foto_id).map_err(|e| e.to_string())?;
    Ok(())
}

pub fn list_photos_by_session(sesion_id: i64) -> Result<Vec<FotoSesion>, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string())?;
    FotoRepo::list_fotos_by_sesion(&conn, sesion_id).map_err(|e| e.to_string())
}

pub fn list_photos_by_patient(paciente_id: i64) -> Result<Vec<FotoSesion>, String> {
    let conn = DatabaseManager::get_conn().map_err(|e| e.to_string())?;
    FotoRepo::list_fotos_by_paciente(&conn, paciente_id).map_err(|e| e.to_string())
}
