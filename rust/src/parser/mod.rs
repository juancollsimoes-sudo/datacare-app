use calamine::{open_workbook, Reader, Xlsx, Data};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExcelRow {
    pub nombre: String,
    pub apellido: String,
    pub telefono: Option<String>,
    pub email: Option<String>,
    pub notas: Option<String>,
}

pub fn parse_excel(file_path: String) -> Result<Vec<ExcelRow>, String> {
    let mut workbook: Xlsx<_> = open_workbook(&file_path).map_err(|e| format!("Error al abrir excel: {}", e))?;
    
    let sheets = workbook.sheet_names().to_owned();
    if sheets.is_empty() {
        return Err("El archivo Excel no tiene hojas".to_string());
    }

    let mut rows = Vec::new();
    
    if let Ok(range) = workbook.worksheet_range(&sheets[0]) {
        let mut row_iter = range.rows();
        
        // Skip header
        let _header = row_iter.next();

        for row in row_iter {
            if row.is_empty() { continue; }
            
            // Suponemos: A=Nombre, B=Apellido, C=Telefono, D=Email, E=Notas
            let get_string = |val: &Data| -> Option<String> {
                match val {
                    Data::String(s) => if s.trim().is_empty() { None } else { Some(s.trim().to_string()) },
                    Data::Int(i) => Some(i.to_string()),
                    Data::Float(f) => Some(f.to_string()),
                    _ => None,
                }
            };

            let nombre = match get_string(row.get(0).unwrap_or(&Data::Empty)) {
                Some(n) => n,
                None => continue, // Nombre es obligatorio, saltamos fila si no hay
            };
            
            let apellido = match get_string(row.get(1).unwrap_or(&Data::Empty)) {
                Some(a) => a,
                None => continue, // Apellido es obligatorio
            };

            let telefono = get_string(row.get(2).unwrap_or(&Data::Empty));
            let email = get_string(row.get(3).unwrap_or(&Data::Empty));
            let notas = get_string(row.get(4).unwrap_or(&Data::Empty));

            rows.push(ExcelRow {
                nombre,
                apellido,
                telefono,
                email,
                notas,
            });
        }
    } else {
        return Err("No se pudo leer el rango de la primera hoja".to_string());
    }

    Ok(rows)
}
