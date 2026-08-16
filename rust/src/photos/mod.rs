use anyhow::{Context, Result};
use image::imageops::FilterType;
use image::ImageFormat;
use std::fs;
use std::path::{Path, PathBuf};
use log::info;

pub struct PhotoManager {
    base_dir: PathBuf,
}

impl PhotoManager {
    pub fn new(base_dir: PathBuf) -> Self {
        Self { base_dir }
    }

    pub fn process_and_save(&self, paciente_id: i64, sesion_id: i64, input_path: &Path) -> Result<(String, String)> {
        // Create directories
        let dir_path = self.base_dir.join("photos").join(paciente_id.to_string()).join(sesion_id.to_string());
        fs::create_dir_all(&dir_path).context("Failed to create photo directory")?;

        let filename = input_path.file_stem().and_then(|s| s.to_str()).unwrap_or("photo");
        let timestamp = chrono::Utc::now().timestamp_millis();
        
        let master_filename = format!("{}_{}_master.jpg", filename, timestamp);
        let thumb_filename = format!("{}_{}_thumb.jpg", filename, timestamp);
        
        let master_path = dir_path.join(&master_filename);
        let thumb_path = dir_path.join(&thumb_filename);

        info!("Reading image from {:?}", input_path);
        let img = image::open(input_path).context("Failed to open input image")?;

        // Process master (max 1920)
        let master_img = if img.width() > 1920 || img.height() > 1920 {
            img.resize(1920, 1920, FilterType::Lanczos3)
        } else {
            img.clone()
        };
        master_img.save_with_format(&master_path, ImageFormat::Jpeg).context("Failed to save master image")?;

        // Process thumb (max 300)
        let thumb_img = img.resize(300, 300, FilterType::Lanczos3);
        thumb_img.save_with_format(&thumb_path, ImageFormat::Jpeg).context("Failed to save thumb image")?;

        // Return absolute paths as strings
        Ok((
            master_path.to_string_lossy().to_string(),
            thumb_path.to_string_lossy().to_string()
        ))
    }
    
    pub fn delete_photos(&self, master_path: &str, thumb_path: Option<&str>) -> Result<()> {
        if let Err(e) = fs::remove_file(master_path) {
            log::warn!("Failed to delete master photo {}: {}", master_path, e);
        }
        if let Some(thumb) = thumb_path {
            if let Err(e) = fs::remove_file(thumb) {
                log::warn!("Failed to delete thumb photo {}: {}", thumb, e);
            }
        }
        Ok(())
    }
}
