use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use zip::{ZipArchive, ZipWriter};
use zip::write::SimpleFileOptions;

fn get_base_dir() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(home).join(".local").join("share").join("datacare")
}

pub fn create_backup(output_path: &str) -> Result<(), anyhow::Error> {
    let base_dir = get_base_dir();
    let db_path = base_dir.join("datacare.db");
    let photos_dir = base_dir.join("photos");

    let file = File::create(output_path)?;
    let mut zip = ZipWriter::new(file);
    let options = SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);

    // Add db
    if db_path.exists() {
        zip.start_file("datacare.db", options)?;
        let mut f = File::open(&db_path)?;
        let mut buffer = Vec::new();
        f.read_to_end(&mut buffer)?;
        zip.write_all(&buffer)?;
    }

    // Add photos
    if photos_dir.exists() {
        add_dir_to_zip(&mut zip, &photos_dir, &photos_dir, options)?;
    }

    zip.finish()?;
    Ok(())
}

fn add_dir_to_zip(
    zip: &mut ZipWriter<File>,
    dir: &Path,
    base_dir: &Path,
    options: SimpleFileOptions,
) -> Result<(), anyhow::Error> {
    if !dir.is_dir() {
        return Ok(());
    }

    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            add_dir_to_zip(zip, &path, base_dir, options)?;
        } else {
            let relative_path = path.strip_prefix(base_dir)?;
            let zip_path = Path::new("photos").join(relative_path);
            
            #[allow(deprecated)]
            let zip_path_str = zip_path.to_string_lossy().replace("\\", "/");
            
            zip.start_file(zip_path_str, options)?;
            let mut f = File::open(&path)?;
            let mut buffer = Vec::new();
            f.read_to_end(&mut buffer)?;
            zip.write_all(&buffer)?;
        }
    }
    Ok(())
}

pub fn restore_backup(zip_path: &str) -> Result<(), anyhow::Error> {
    let base_dir = get_base_dir();
    let file = File::open(zip_path)?;
    let mut archive = ZipArchive::new(file)?;

    // Extracción en un directorio temporal primero (opcional, pero buena práctica)
    // Para simplificar, extraemos directamente y sobrescribimos.
    
    for i in 0..archive.len() {
        let mut file = archive.by_index(i)?;
        let outpath = match file.enclosed_name() {
            Some(path) => path.to_owned(),
            None => continue,
        };

        let target_path = base_dir.join(&outpath);
        
        if (*file.name()).ends_with('/') {
            fs::create_dir_all(&target_path)?;
        } else {
            if let Some(p) = target_path.parent() {
                if !p.exists() {
                    fs::create_dir_all(&p)?;
                }
            }
            let mut outfile = File::create(&target_path)?;
            std::io::copy(&mut file, &mut outfile)?;
        }
    }

    Ok(())
}
