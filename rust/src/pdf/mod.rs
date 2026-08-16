use crate::db::error::AppError;
use crate::db::models::{Paciente, Sesion};
use crate::db::repository::{PacienteRepo, SesionRepo};
use crate::db::DatabaseManager;
use printpdf::*;
use std::fs::File;
use std::io::BufWriter;

pub fn generate_patient_report(paciente_id: i64, output_path: String) -> Result<String, AppError> {
    let conn = DatabaseManager::get_conn()?;
    
    let paciente = PacienteRepo::obtener(&conn, paciente_id)?
        .ok_or_else(|| AppError::NotFound(format!("Paciente no encontrado con id {}", paciente_id)))?;
        
    let sesiones = SesionRepo::listar_por_paciente(&conn, paciente_id, 1, 1000)?
        .items;
        
    let (doc, mut current_page, mut current_layer_id) = PdfDocument::new("Reporte Paciente", Mm(210.0), Mm(297.0), "Layer 1");
    
    let font = doc.add_builtin_font(BuiltinFont::Helvetica).map_err(|e| AppError::IoError(e.to_string()))?;
    let font_bold = doc.add_builtin_font(BuiltinFont::HelveticaBold).map_err(|e| AppError::IoError(e.to_string()))?;
    
    let mut current_y = 280.0;
    
    let write_text = |doc: &PdfDocumentReference, page: PdfPageIndex, layer: PdfLayerIndex, text: &str, size: f32, x: f32, y: f32, font: &IndirectFontRef| {
        let current_layer = doc.get_page(page).get_layer(layer);
        current_layer.use_text(text, size as f64, Mm(x as f64), Mm(y as f64), font);
    };

    write_text(&doc, current_page, current_layer_id, "Reporte Clinico", 24.0, 20.0, current_y, &font_bold);
    current_y -= 15.0;
    
    write_text(&doc, current_page, current_layer_id, &format!("Paciente: {} {}", paciente.nombre, paciente.apellido), 14.0, 20.0, current_y, &font_bold);
    current_y -= 8.0;
    
    if let Some(tel) = &paciente.telefono {
        write_text(&doc, current_page, current_layer_id, &format!("Telefono: {}", tel), 12.0, 20.0, current_y, &font);
        current_y -= 6.0;
    }
    if let Some(email) = &paciente.email {
        write_text(&doc, current_page, current_layer_id, &format!("Email: {}", email), 12.0, 20.0, current_y, &font);
        current_y -= 6.0;
    }
    
    current_y -= 10.0;
    write_text(&doc, current_page, current_layer_id, "Historial de Sesiones:", 14.0, 20.0, current_y, &font_bold);
    current_y -= 10.0;
    
    for sesion in sesiones {
        if current_y < 30.0 {
            let (new_page, new_layer) = doc.add_page(Mm(210.0), Mm(297.0), "Layer 1");
            current_page = new_page;
            current_layer_id = new_layer;
            current_y = 280.0;
        }
        
        write_text(&doc, current_page, current_layer_id, &format!("Fecha: {}", sesion.fecha), 12.0, 20.0, current_y, &font_bold);
        current_y -= 6.0;
        
        if let Some(notas) = &sesion.notas_sesion {
            write_text(&doc, current_page, current_layer_id, &format!("Notas: {}", notas), 11.0, 25.0, current_y, &font);
            current_y -= 6.0;
        }
        if let Some(precio) = &sesion.precio_cobrado {
            write_text(&doc, current_page, current_layer_id, &format!("Precio: ${:.2}", precio), 11.0, 25.0, current_y, &font);
            current_y -= 6.0;
        }
        current_y -= 5.0;
    }
    
    let mut buf = BufWriter::new(File::create(&output_path).map_err(|e| AppError::IoError(e.to_string()))?);
    doc.save(&mut buf).map_err(|e| AppError::IoError(e.to_string()))?;
    
    Ok(output_path)
}
