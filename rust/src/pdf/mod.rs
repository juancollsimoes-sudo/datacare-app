use crate::db::error::AppError;
use crate::db::models::{Gasto, Sesion};
use crate::db::repository::{GastoRepo, PacienteRepo, SesionRepo};
use crate::db::DatabaseManager;
use printpdf::*;
use rusqlite::Connection;
use std::fs::File;
use std::io::BufWriter;

#[derive(Debug, Clone)]
pub struct MonthlyClosingSummary {
    pub year: i32,
    pub month: i32,
    pub ingresos: Vec<Sesion>,
    pub total_ingresos: f64,
    pub gastos_operativos: Vec<Gasto>,
    pub subtotal_gastos_operativos: f64,
    pub gastos_personales: Vec<Gasto>,
    pub total_gastos_personales: f64,
    pub total_gastos: f64,
    pub saldo_neto: f64,
}

pub fn is_personal_expense(categoria: Option<&str>) -> bool {
    match categoria {
        Some(cat) => cat.trim().to_lowercase().contains("personal"),
        None => false,
    }
}

pub fn matches_year_month(fecha: &str, year: i32, month: i32) -> bool {
    let prefix = format!("{:04}-{:02}", year, month);
    fecha.trim().starts_with(&prefix)
}

pub fn month_name_es(month: i32) -> &'static str {
    match month {
        1 => "Enero",
        2 => "Febrero",
        3 => "Marzo",
        4 => "Abril",
        5 => "Mayo",
        6 => "Junio",
        7 => "Julio",
        8 => "Agosto",
        9 => "Septiembre",
        10 => "Octubre",
        11 => "Noviembre",
        12 => "Diciembre",
        _ => "Mes",
    }
}

pub fn calculate_monthly_closing(
    conn: &Connection,
    year: i32,
    month: i32,
) -> Result<MonthlyClosingSummary, AppError> {
    let all_ingresos = SesionRepo::list_ingresos(conn)?;
    let all_gastos = GastoRepo::listar(conn)?;

    let mut ingresos: Vec<Sesion> = all_ingresos
        .into_iter()
        .filter(|s| matches_year_month(&s.fecha, year, month))
        .collect();
    ingresos.sort_by(|a, b| a.fecha.cmp(&b.fecha));

    let total_ingresos: f64 = ingresos
        .iter()
        .map(|s| s.precio_cobrado.unwrap_or(0.0))
        .sum();

    let mut gastos_operativos: Vec<Gasto> = Vec::new();
    let mut gastos_personales: Vec<Gasto> = Vec::new();

    for g in all_gastos {
        if matches_year_month(&g.fecha, year, month) {
            if is_personal_expense(g.categoria.as_deref()) {
                gastos_personales.push(g);
            } else {
                gastos_operativos.push(g);
            }
        }
    }

    gastos_operativos.sort_by(|a, b| a.fecha.cmp(&b.fecha));
    gastos_personales.sort_by(|a, b| a.fecha.cmp(&b.fecha));

    let subtotal_gastos_operativos: f64 = gastos_operativos.iter().map(|g| g.monto).sum();
    let total_gastos_personales: f64 = gastos_personales.iter().map(|g| g.monto).sum();
    let total_gastos = subtotal_gastos_operativos + total_gastos_personales;
    let saldo_neto = total_ingresos - total_gastos;

    Ok(MonthlyClosingSummary {
        year,
        month,
        ingresos,
        total_ingresos,
        gastos_operativos,
        subtotal_gastos_operativos,
        gastos_personales,
        total_gastos_personales,
        total_gastos,
        saldo_neto,
    })
}

pub fn generate_patient_report_bytes_from_conn(
    conn: &Connection,
    paciente_id: i64,
) -> Result<Vec<u8>, AppError> {
    let paciente = PacienteRepo::obtener(conn, paciente_id)?
        .ok_or_else(|| AppError::NotFound(format!("Paciente no encontrado con id {}", paciente_id)))?;

    let sesiones = SesionRepo::listar_por_paciente(conn, paciente_id, 1, 1000)?.items;

    let (doc, mut current_page, mut current_layer_id) =
        PdfDocument::new("Reporte Paciente", Mm(210.0), Mm(297.0), "Layer 1");

    let font = doc
        .add_builtin_font(BuiltinFont::Helvetica)
        .map_err(|e| AppError::IoError(e.to_string()))?;
    let font_bold = doc
        .add_builtin_font(BuiltinFont::HelveticaBold)
        .map_err(|e| AppError::IoError(e.to_string()))?;

    let mut current_y = 280.0;

    let write_text = |doc: &PdfDocumentReference,
                      page: PdfPageIndex,
                      layer: PdfLayerIndex,
                      text: &str,
                      size: f32,
                      x: f32,
                      y: f32,
                      font: &IndirectFontRef| {
        let current_layer = doc.get_page(page).get_layer(layer);
        current_layer.use_text(text, size as f64, Mm(x as f64), Mm(y as f64), font);
    };

    write_text(&doc, current_page, current_layer_id, "Reporte Clinico", 24.0, 20.0, current_y, &font_bold);
    current_y -= 15.0;

    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!("Paciente: {} {}", paciente.nombre, paciente.apellido),
        14.0,
        20.0,
        current_y,
        &font_bold,
    );
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

    let bytes = doc.save_to_bytes().map_err(|e| AppError::IoError(e.to_string()))?;
    Ok(bytes)
}

pub fn generate_patient_report_bytes(paciente_id: i64) -> Result<Vec<u8>, AppError> {
    let conn = DatabaseManager::get_conn()?;
    generate_patient_report_bytes_from_conn(&conn, paciente_id)
}

pub fn generate_patient_report(paciente_id: i64, output_path: String) -> Result<String, AppError> {
    let bytes = generate_patient_report_bytes(paciente_id)?;
    let mut file = BufWriter::new(File::create(&output_path).map_err(|e| AppError::IoError(e.to_string()))?);
    std::io::Write::write_all(&mut file, &bytes).map_err(|e| AppError::IoError(e.to_string()))?;
    Ok(output_path)
}

pub fn generate_accounting_report_bytes_from_conn(
    conn: &Connection,
    year: i32,
    month: i32,
) -> Result<Vec<u8>, AppError> {
    let summary = calculate_monthly_closing(conn, year, month)?;
    let mes_nombre = month_name_es(month);

    let title = format!("Cierre Contable - {} {}", mes_nombre, year);
    let (doc, mut current_page, mut current_layer_id) =
        PdfDocument::new(&title, Mm(210.0), Mm(297.0), "Layer 1");

    let font = doc
        .add_builtin_font(BuiltinFont::Helvetica)
        .map_err(|e| AppError::IoError(e.to_string()))?;
    let font_bold = doc
        .add_builtin_font(BuiltinFont::HelveticaBold)
        .map_err(|e| AppError::IoError(e.to_string()))?;

    let mut current_y: f32 = 280.0;

    let write_text = |doc: &PdfDocumentReference,
                      page: PdfPageIndex,
                      layer: PdfLayerIndex,
                      text: &str,
                      size: f32,
                      x: f32,
                      y: f32,
                      font_ref: &IndirectFontRef| {
        let current_layer = doc.get_page(page).get_layer(layer);
        current_layer.use_text(text, size as f64, Mm(x as f64), Mm(y as f64), font_ref);
    };

    let check_page = |doc: &PdfDocumentReference,
                      page: &mut PdfPageIndex,
                      layer: &mut PdfLayerIndex,
                      y: &mut f32,
                      min_y: f32| {
        if *y < min_y {
            let (new_page, new_layer) = doc.add_page(Mm(210.0), Mm(297.0), "Layer 1");
            *page = new_page;
            *layer = new_layer;
            *y = 280.0;
        }
    };

    // Header
    write_text(&doc, current_page, current_layer_id, "CIERRE CONTABLE MENSUAL", 20.0, 20.0, current_y, &font_bold);
    current_y -= 8.0;
    write_text(
        &doc,
        current_page,
        current_layer_id,
        "Beauty Sweet Care Spa - Susana Simoes",
        12.0,
        20.0,
        current_y,
        &font,
    );
    current_y -= 7.0;
    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!("Periodo Contable: {} {} ({:04}-{:02})", mes_nombre, year, year, month),
        12.0,
        20.0,
        current_y,
        &font_bold,
    );
    current_y -= 6.0;
    let emitted_at = chrono::Local::now().format("%Y-%m-%d %H:%M").to_string();
    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!("Fecha de emision del cierre: {}", emitted_at),
        10.0,
        20.0,
        current_y,
        &font,
    );
    current_y -= 12.0;

    // 1. Executive Summary
    write_text(
        &doc,
        current_page,
        current_layer_id,
        "1. RESUMEN GENERAL DEL CIERRE CONTABLE",
        13.0,
        20.0,
        current_y,
        &font_bold,
    );
    current_y -= 8.0;

    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!(
            "(+) Total Ingresos por Sesiones ({} sesiones): ${:.2}",
            summary.ingresos.len(),
            summary.total_ingresos
        ),
        11.0,
        25.0,
        current_y,
        &font,
    );
    current_y -= 6.0;

    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!(
            "(-) Subtotal Gastos Operativos ({} registros): ${:.2}",
            summary.gastos_operativos.len(),
            summary.subtotal_gastos_operativos
        ),
        11.0,
        25.0,
        current_y,
        &font,
    );
    current_y -= 6.0;

    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!(
            "(-) Renglon Gastos Personales Incorporados ({} registros): ${:.2}",
            summary.gastos_personales.len(),
            summary.total_gastos_personales
        ),
        11.0,
        25.0,
        current_y,
        &font_bold,
    );
    current_y -= 6.0;

    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!(
            "(=) Total Gastos Incorporados a Contabilidad: ${:.2}",
            summary.total_gastos
        ),
        11.0,
        25.0,
        current_y,
        &font_bold,
    );
    current_y -= 8.0;

    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!("(=) SALDO NETO DEL CIERRE CONTABLE: ${:.2}", summary.saldo_neto),
        13.0,
        25.0,
        current_y,
        &font_bold,
    );
    current_y -= 14.0;

    // 2. Detail of Incomes (Sessions with Patient Name)
    check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 45.0);
    write_text(
        &doc,
        current_page,
        current_layer_id,
        "2. DETALLE DE INGRESOS (SESIONES POR PACIENTE)",
        13.0,
        20.0,
        current_y,
        &font_bold,
    );
    current_y -= 8.0;

    if summary.ingresos.is_empty() {
        write_text(&doc, current_page, current_layer_id, "Sin ingresos registrados en este periodo.", 10.5, 25.0, current_y, &font);
        current_y -= 8.0;
    } else {
        for sesion in &summary.ingresos {
            check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 25.0);
            let fecha_corta = sesion.fecha.split('T').next().unwrap_or(&sesion.fecha);
            let paciente_label = sesion
                .paciente_nombre
                .as_deref()
                .filter(|s| !s.trim().is_empty())
                .map(|s| s.to_string())
                .unwrap_or_else(|| format!("Paciente #{}", sesion.paciente_id));
            let detalle = sesion
                .notas_sesion
                .as_deref()
                .or(sesion.observaciones.as_deref())
                .unwrap_or("");
            let detalle_trunc: String = detalle.chars().take(42).collect();
            let monto = sesion.precio_cobrado.unwrap_or(0.0);

            let line = if detalle_trunc.is_empty() {
                format!("{} | Paciente: {} | +${:.2}", fecha_corta, paciente_label, monto)
            } else {
                format!("{} | Paciente: {} | {} | +${:.2}", fecha_corta, paciente_label, detalle_trunc, monto)
            };
            write_text(&doc, current_page, current_layer_id, &line, 10.0, 25.0, current_y, &font);
            current_y -= 5.5;
        }
        check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 25.0);
        write_text(
            &doc,
            current_page,
            current_layer_id,
            &format!("Subtotal Ingresos del Mes: ${:.2}", summary.total_ingresos),
            11.0,
            25.0,
            current_y,
            &font_bold,
        );
        current_y -= 12.0;
    }

    // 3. Detail of Operational Expenses
    check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 45.0);
    write_text(
        &doc,
        current_page,
        current_layer_id,
        "3. DETALLE DE GASTOS OPERATIVOS",
        13.0,
        20.0,
        current_y,
        &font_bold,
    );
    current_y -= 8.0;

    if summary.gastos_operativos.is_empty() {
        write_text(&doc, current_page, current_layer_id, "Sin gastos operativos registrados en este periodo.", 10.5, 25.0, current_y, &font);
        current_y -= 8.0;
    } else {
        for gasto in &summary.gastos_operativos {
            check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 25.0);
            let fecha_corta = gasto.fecha.split('T').next().unwrap_or(&gasto.fecha);
            let cat = gasto.categoria.as_deref().unwrap_or("Otro");
            let desc = gasto.descripcion.as_deref().unwrap_or("");
            let desc_trunc: String = desc.chars().take(35).collect();
            let line = if desc_trunc.is_empty() {
                format!("{} | {} [{}] | -${:.2}", fecha_corta, gasto.nombre, cat, gasto.monto)
            } else {
                format!("{} | {} [{}] - {} | -${:.2}", fecha_corta, gasto.nombre, cat, desc_trunc, gasto.monto)
            };
            write_text(&doc, current_page, current_layer_id, &line, 10.0, 25.0, current_y, &font);
            current_y -= 5.5;
        }
        check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 25.0);
        write_text(
            &doc,
            current_page,
            current_layer_id,
            &format!("Subtotal Gastos Operativos: ${:.2}", summary.subtotal_gastos_operativos),
            11.0,
            25.0,
            current_y,
            &font_bold,
        );
        current_y -= 12.0;
    }

    // 4. Renglón de Gastos Personales (Totalizados e Incorporados a la Contabilidad)
    check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 45.0);
    write_text(
        &doc,
        current_page,
        current_layer_id,
        "4. RENGLON DE GASTOS PERSONALES (INCORPORADOS A CONTABILIDAD)",
        13.0,
        20.0,
        current_y,
        &font_bold,
    );
    current_y -= 8.0;

    if summary.gastos_personales.is_empty() {
        write_text(&doc, current_page, current_layer_id, "Sin gastos personales registrados en este periodo ($0.00).", 10.5, 25.0, current_y, &font);
        current_y -= 8.0;
    } else {
        for gasto in &summary.gastos_personales {
            check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 25.0);
            let fecha_corta = gasto.fecha.split('T').next().unwrap_or(&gasto.fecha);
            let desc = gasto.descripcion.as_deref().unwrap_or("");
            let desc_trunc: String = desc.chars().take(40).collect();
            let line = if desc_trunc.is_empty() {
                format!("{} | {} (Personal) | -${:.2}", fecha_corta, gasto.nombre, gasto.monto)
            } else {
                format!("{} | {} (Personal) - {} | -${:.2}", fecha_corta, gasto.nombre, desc_trunc, gasto.monto)
            };
            write_text(&doc, current_page, current_layer_id, &line, 10.0, 25.0, current_y, &font);
            current_y -= 5.5;
        }
    }

    check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 35.0);
    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!(
            "TOTAL RENGLON GASTOS PERSONALES (INCORPORADO): ${:.2}",
            summary.total_gastos_personales
        ),
        11.0,
        25.0,
        current_y,
        &font_bold,
    );
    current_y -= 12.0;

    // 5. Final Closing Line
    check_page(&doc, &mut current_page, &mut current_layer_id, &mut current_y, 30.0);
    write_text(
        &doc,
        current_page,
        current_layer_id,
        &format!(
            "CIERRE FINAL: Ingresos (${:.2}) - Gastos Operativos (${:.2}) - Gastos Personales (${:.2}) = SALDO ${:.2}",
            summary.total_ingresos,
            summary.subtotal_gastos_operativos,
            summary.total_gastos_personales,
            summary.saldo_neto
        ),
        10.5,
        20.0,
        current_y,
        &font_bold,
    );

    let bytes = doc.save_to_bytes().map_err(|e| AppError::IoError(e.to_string()))?;
    Ok(bytes)
}

pub fn generate_accounting_report_bytes(year: i32, month: i32) -> Result<Vec<u8>, AppError> {
    let conn = DatabaseManager::get_conn()?;
    generate_accounting_report_bytes_from_conn(&conn, year, month)
}

pub fn generate_accounting_report(year: i32, month: i32, output_path: String) -> Result<String, AppError> {
    let bytes = generate_accounting_report_bytes(year, month)?;
    let mut file = BufWriter::new(File::create(&output_path).map_err(|e| AppError::IoError(e.to_string()))?);
    std::io::Write::write_all(&mut file, &bytes).map_err(|e| AppError::IoError(e.to_string()))?;
    Ok(output_path)
}

fn xml_escape(input: &str) -> String {
    input
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

fn write_inline_str_cell(xml: &mut String, col: &str, row: u32, style: u32, text: &str) {
    xml.push_str(&format!(
        r#"<c r="{}{}" s="{}" t="inlineStr"><is><t>{}</t></is></c>"#,
        col,
        row,
        style,
        xml_escape(text)
    ));
}

fn write_number_cell(xml: &mut String, col: &str, row: u32, style: u32, val: f64) {
    xml.push_str(&format!(
        r#"<c r="{}{}" s="{}"><v>{:.2}</v></c>"#,
        col, row, style, val
    ));
}

pub fn generate_expenses_excel_bytes_from_conn(
    conn: &Connection,
    year: i32,
    month: i32,
) -> Result<Vec<u8>, AppError> {
    use std::io::{Cursor, Write};
    use zip::write::SimpleFileOptions;
    use zip::ZipWriter;

    let summary = calculate_monthly_closing(conn, year, month)?;
    let mes_nombre = month_name_es(month);

    let mut sheet_xml = String::from(
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<cols>
  <col min="1" max="1" width="16" customWidth="1"/>
  <col min="2" max="2" width="32" customWidth="1"/>
  <col min="3" max="3" width="24" customWidth="1"/>
  <col min="4" max="4" width="38" customWidth="1"/>
  <col min="5" max="5" width="18" customWidth="1"/>
</cols>
<sheetData>"#,
    );

    let mut row_idx: u32 = 1;

    // Row 1: Title
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        1,
        &format!("REPORTE DE GASTOS Y COMPRAS - {} {}", mes_nombre.to_uppercase(), year),
    );
    sheet_xml.push_str("</row>");
    row_idx += 1;

    // Row 2: Subtitle
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        0,
        "Beauty Sweet Care Spa - Contaduría",
    );
    sheet_xml.push_str("</row>");
    row_idx += 2;

    // Section 1: Gastos Operativos y Compras
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        4,
        "1. GASTOS OPERATIVOS Y COMPRAS DE CLÍNICA",
    );
    sheet_xml.push_str("</row>");
    row_idx += 1;

    // Table 1 Headers
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(&mut sheet_xml, "A", row_idx, 2, "Fecha");
    write_inline_str_cell(&mut sheet_xml, "B", row_idx, 2, "Concepto / Compra");
    write_inline_str_cell(&mut sheet_xml, "C", row_idx, 2, "Categoría");
    write_inline_str_cell(&mut sheet_xml, "D", row_idx, 2, "Descripción");
    write_inline_str_cell(&mut sheet_xml, "E", row_idx, 2, "Monto ($)");
    sheet_xml.push_str("</row>");
    row_idx += 1;

    if summary.gastos_operativos.is_empty() {
        sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
        write_inline_str_cell(
            &mut sheet_xml,
            "A",
            row_idx,
            0,
            "Sin gastos operativos ni compras registrados en este mes",
        );
        write_number_cell(&mut sheet_xml, "E", row_idx, 3, 0.0);
        sheet_xml.push_str("</row>");
        row_idx += 1;
    } else {
        for g in &summary.gastos_operativos {
            let fecha_corta = g.fecha.split('T').next().unwrap_or(&g.fecha);
            let cat = g.categoria.as_deref().unwrap_or("Compra / Operativo");
            let desc = g.descripcion.as_deref().unwrap_or("");
            sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
            write_inline_str_cell(&mut sheet_xml, "A", row_idx, 0, fecha_corta);
            write_inline_str_cell(&mut sheet_xml, "B", row_idx, 0, &g.nombre);
            write_inline_str_cell(&mut sheet_xml, "C", row_idx, 0, cat);
            write_inline_str_cell(&mut sheet_xml, "D", row_idx, 0, desc);
            write_number_cell(&mut sheet_xml, "E", row_idx, 3, g.monto);
            sheet_xml.push_str("</row>");
            row_idx += 1;
        }
    }

    // Subtotal Operational / Compras
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        4,
        "SUBTOTAL GASTOS OPERATIVOS Y COMPRAS",
    );
    write_inline_str_cell(&mut sheet_xml, "B", row_idx, 4, "");
    write_inline_str_cell(&mut sheet_xml, "C", row_idx, 4, "");
    write_inline_str_cell(&mut sheet_xml, "D", row_idx, 4, "");
    write_number_cell(
        &mut sheet_xml,
        "E",
        row_idx,
        5,
        summary.subtotal_gastos_operativos,
    );
    sheet_xml.push_str("</row>");
    row_idx += 2;

    // Section 2: Renglón de Gastos Personales
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        4,
        "2. RENGLÓN DE GASTOS PERSONALES (INCORPORADOS A CONTABILIDAD)",
    );
    sheet_xml.push_str("</row>");
    row_idx += 1;

    // Table 2 Headers
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(&mut sheet_xml, "A", row_idx, 2, "Fecha");
    write_inline_str_cell(&mut sheet_xml, "B", row_idx, 2, "Concepto Personal");
    write_inline_str_cell(&mut sheet_xml, "C", row_idx, 2, "Categoría");
    write_inline_str_cell(&mut sheet_xml, "D", row_idx, 2, "Descripción");
    write_inline_str_cell(&mut sheet_xml, "E", row_idx, 2, "Monto ($)");
    sheet_xml.push_str("</row>");
    row_idx += 1;

    if summary.gastos_personales.is_empty() {
        sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
        write_inline_str_cell(
            &mut sheet_xml,
            "A",
            row_idx,
            0,
            "Sin gastos personales registrados en este mes",
        );
        write_number_cell(&mut sheet_xml, "E", row_idx, 3, 0.0);
        sheet_xml.push_str("</row>");
        row_idx += 1;
    } else {
        for g in &summary.gastos_personales {
            let fecha_corta = g.fecha.split('T').next().unwrap_or(&g.fecha);
            let cat = g.categoria.as_deref().unwrap_or("Gastos Personales");
            let desc = g.descripcion.as_deref().unwrap_or("");
            sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
            write_inline_str_cell(&mut sheet_xml, "A", row_idx, 0, fecha_corta);
            write_inline_str_cell(&mut sheet_xml, "B", row_idx, 0, &g.nombre);
            write_inline_str_cell(&mut sheet_xml, "C", row_idx, 0, cat);
            write_inline_str_cell(&mut sheet_xml, "D", row_idx, 0, desc);
            write_number_cell(&mut sheet_xml, "E", row_idx, 3, g.monto);
            sheet_xml.push_str("</row>");
            row_idx += 1;
        }
    }

    // Subtotal Personal Expenses
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        4,
        "TOTAL RENGLÓN GASTOS PERSONALES",
    );
    write_inline_str_cell(&mut sheet_xml, "B", row_idx, 4, "");
    write_inline_str_cell(&mut sheet_xml, "C", row_idx, 4, "");
    write_inline_str_cell(&mut sheet_xml, "D", row_idx, 4, "");
    write_number_cell(
        &mut sheet_xml,
        "E",
        row_idx,
        5,
        summary.total_gastos_personales,
    );
    sheet_xml.push_str("</row>");
    row_idx += 2;

    // Section 3: Total General de Gastos y Compras
    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        2,
        "3. RESUMEN Y TOTAL GENERAL DE GASTOS Y COMPRAS",
    );
    write_inline_str_cell(&mut sheet_xml, "B", row_idx, 2, "");
    write_inline_str_cell(&mut sheet_xml, "C", row_idx, 2, "");
    write_inline_str_cell(&mut sheet_xml, "D", row_idx, 2, "");
    write_inline_str_cell(&mut sheet_xml, "E", row_idx, 2, "Total ($)");
    sheet_xml.push_str("</row>");
    row_idx += 1;

    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        0,
        "Subtotal Gastos Operativos y Compras",
    );
    write_number_cell(
        &mut sheet_xml,
        "E",
        row_idx,
        3,
        summary.subtotal_gastos_operativos,
    );
    sheet_xml.push_str("</row>");
    row_idx += 1;

    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        0,
        "Total Renglón Gastos Personales (Incorporado)",
    );
    write_number_cell(
        &mut sheet_xml,
        "E",
        row_idx,
        3,
        summary.total_gastos_personales,
    );
    sheet_xml.push_str("</row>");
    row_idx += 1;

    sheet_xml.push_str(&format!(r#"<row r="{}">"#, row_idx));
    write_inline_str_cell(
        &mut sheet_xml,
        "A",
        row_idx,
        4,
        "TOTAL GENERAL DE GASTOS Y COMPRAS DEL MES",
    );
    write_inline_str_cell(&mut sheet_xml, "B", row_idx, 4, "");
    write_inline_str_cell(&mut sheet_xml, "C", row_idx, 4, "");
    write_inline_str_cell(&mut sheet_xml, "D", row_idx, 4, "");
    write_number_cell(&mut sheet_xml, "E", row_idx, 5, summary.total_gastos);
    sheet_xml.push_str("</row>");

    sheet_xml.push_str("</sheetData></worksheet>");

    let content_types_xml = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>"#;

    let root_rels_xml = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>"#;

    let workbook_xml = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Gastos y Compras" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>"#;

    let workbook_rels_xml = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>"#;

    let styles_xml = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <numFmts count="1">
    <numFmt numFmtId="164" formatCode="$#,##0.00"/>
  </numFmts>
  <fonts count="4">
    <font><sz val="11"/><name val="Calibri"/></font>
    <font><b/><sz val="14"/><name val="Calibri"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>
    <font><b/><sz val="11"/><name val="Calibri"/></font>
  </fonts>
  <fills count="4">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFC77D9C"/><bgColor indexed="64"/></patternFill></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FFF3E5EC"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="1">
    <border><left/><right/><top/><bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="6">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
    <xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
    <xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
    <xf numFmtId="0" fontId="3" fillId="3" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
    <xf numFmtId="164" fontId="3" fillId="3" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1"/>
  </cellXfs>
</styleSheet>"#;

    let buf = Cursor::new(Vec::new());
    let mut zip = ZipWriter::new(buf);
    let options = SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated);

    let add_xml_file = |zip: &mut ZipWriter<Cursor<Vec<u8>>>, path: &str, content: &str| -> Result<(), AppError> {
        zip.start_file(path, options)
            .map_err(|e| AppError::IoError(e.to_string()))?;
        zip.write_all(content.as_bytes())
            .map_err(|e| AppError::IoError(e.to_string()))?;
        Ok(())
    };

    add_xml_file(&mut zip, "[Content_Types].xml", content_types_xml)?;
    add_xml_file(&mut zip, "_rels/.rels", root_rels_xml)?;
    add_xml_file(&mut zip, "xl/workbook.xml", workbook_xml)?;
    add_xml_file(&mut zip, "xl/_rels/workbook.xml.rels", workbook_rels_xml)?;
    add_xml_file(&mut zip, "xl/styles.xml", styles_xml)?;
    add_xml_file(&mut zip, "xl/worksheets/sheet1.xml", &sheet_xml)?;

    let cursor = zip.finish().map_err(|e| AppError::IoError(e.to_string()))?;
    Ok(cursor.into_inner())
}

pub fn generate_expenses_excel_bytes(year: i32, month: i32) -> Result<Vec<u8>, AppError> {
    let conn = DatabaseManager::get_conn()?;
    generate_expenses_excel_bytes_from_conn(&conn, year, month)
}

pub fn generate_expenses_excel(year: i32, month: i32, output_path: String) -> Result<String, AppError> {
    let bytes = generate_expenses_excel_bytes(year, month)?;
    let mut file = BufWriter::new(File::create(&output_path).map_err(|e| AppError::IoError(e.to_string()))?);
    std::io::Write::write_all(&mut file, &bytes).map_err(|e| AppError::IoError(e.to_string()))?;
    Ok(output_path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::migrations::apply_migrations;
    use crate::db::models::{NuevoGasto, NuevoPaciente, NuevaSesion};
    use crate::db::repository::{GastoRepo, PacienteRepo};
    use rusqlite::Connection;

    #[test]
    fn test_monthly_accounting_closing_and_pdf_generation() {
        let mut conn = Connection::open_in_memory().unwrap();
        apply_migrations(&mut conn).unwrap();

        let pid = PacienteRepo::crear(&conn, &NuevoPaciente {
            nombre: "Ana".to_string(),
            apellido: "Martínez".to_string(),
            fecha_nacimiento: None,
            telefono: None,
            email: None,
            direccion: None,
            notas_generales: None,
            alergias: None,
            condiciones_medicas: None,
            afecciones_cutaneas: None,
            tatuajes: None,
            cirugia_plastica: None,
            antecedentes_medicos: None,
            ubicacion_lesiones: None,
            tipo_piel: None,
            cicatrizacion: None,
            diagnostico_visual: None,
            diagnostico_tactil: None,
        }).unwrap();

        // Paid session in Oct 2026 ($120)
        SesionRepo::crear(&conn, &NuevaSesion {
            paciente_id: pid,
            tratamiento_id: None,
            fecha: "2026-10-05".to_string(),
            notas_sesion: Some("Hidratación facial".to_string()),
            observaciones: None,
            productos_usados: None,
            precio_cobrado: Some(120.0),
            pagado: true,
            tipo: Some("facial".to_string()),
            peso: None,
            altura: None,
            imc: None,
            grasa_corporal: None,
            agua_corporal: None,
            medida_cadera: None,
            medida_cintura: None,
            medida_brazos: None,
            medida_pecho: None,
            medida_piernas: None,
        }).unwrap();

        // Operational expense in Oct 2026 ($30)
        GastoRepo::crear(&conn, &NuevoGasto {
            nombre: "Ácido Hialurónico".to_string(),
            descripcion: Some("Insumos".to_string()),
            categoria: Some("Producto".to_string()),
            monto: 30.0,
            fecha: "2026-10-10T12:00:00".to_string(),
        }).unwrap();

        // Two Personal expenses in Oct 2026 ($15 + $25 = $40)
        GastoRepo::crear(&conn, &NuevoGasto {
            nombre: "Almuerzo".to_string(),
            descripcion: Some("Gasto personal".to_string()),
            categoria: Some("Gastos Personales".to_string()),
            monto: 15.0,
            fecha: "2026-10-12".to_string(),
        }).unwrap();

        GastoRepo::crear(&conn, &NuevoGasto {
            nombre: "Transporte personal".to_string(),
            descripcion: None,
            categoria: Some("Personal".to_string()),
            monto: 25.0,
            fecha: "2026-10-18".to_string(),
        }).unwrap();

        // Expense in another month (Sep 2026) - should not be included in Oct 2026 closing
        GastoRepo::crear(&conn, &NuevoGasto {
            nombre: "Gasto Septiembre".to_string(),
            descripcion: None,
            categoria: Some("Otro".to_string()),
            monto: 999.0,
            fecha: "2026-09-15".to_string(),
        }).unwrap();

        let summary = calculate_monthly_closing(&conn, 2026, 10).unwrap();
        assert_eq!(summary.ingresos.len(), 1);
        assert_eq!(summary.ingresos[0].paciente_nombre.as_deref(), Some("Ana Martínez"));
        assert!((summary.total_ingresos - 120.0).abs() < 1e-6);
        assert_eq!(summary.gastos_operativos.len(), 1);
        assert!((summary.subtotal_gastos_operativos - 30.0).abs() < 1e-6);
        assert_eq!(summary.gastos_personales.len(), 2);
        assert!((summary.total_gastos_personales - 40.0).abs() < 1e-6);
        assert!((summary.total_gastos - 70.0).abs() < 1e-6);
        assert!((summary.saldo_neto - 50.0).abs() < 1e-6);

        let pdf_bytes = generate_accounting_report_bytes_from_conn(&conn, 2026, 10).unwrap();
        assert!(pdf_bytes.len() > 500);
        assert_eq!(&pdf_bytes[0..5], b"%PDF-");

        // Verify Excel (.xlsx) generation and parse it back with calamine!
        let xlsx_bytes = generate_expenses_excel_bytes_from_conn(&conn, 2026, 10).unwrap();
        assert_eq!(&xlsx_bytes[0..2], b"PK");
        use calamine::{Reader, Xlsx};
        let cursor = std::io::Cursor::new(xlsx_bytes);
        let mut workbook: Xlsx<_> = Xlsx::new(cursor).expect("valid xlsx workbook");
        let range = workbook.worksheet_range("Gastos y Compras").expect("sheet exists");
        assert!(range.height() >= 10);
    }

    #[test]
    fn test_empty_month_closing_pdf() {
        let mut conn = Connection::open_in_memory().unwrap();
        apply_migrations(&mut conn).unwrap();

        let summary = calculate_monthly_closing(&conn, 2026, 1).unwrap();
        assert_eq!(summary.ingresos.len(), 0);
        assert_eq!(summary.gastos_operativos.len(), 0);
        assert_eq!(summary.gastos_personales.len(), 0);
        assert_eq!(summary.total_ingresos, 0.0);
        assert_eq!(summary.total_gastos_personales, 0.0);
        assert_eq!(summary.total_gastos, 0.0);
        assert_eq!(summary.saldo_neto, 0.0);

        let pdf_bytes = generate_accounting_report_bytes_from_conn(&conn, 2026, 1).unwrap();
        assert!(pdf_bytes.len() > 500);
        assert_eq!(&pdf_bytes[0..5], b"%PDF-");
    }

    #[test]
    fn test_multipage_closing_pdf_with_many_records() {
        let mut conn = Connection::open_in_memory().unwrap();
        apply_migrations(&mut conn).unwrap();

        for i in 1..=65 {
            GastoRepo::crear(&conn, &NuevoGasto {
                nombre: format!("Gasto Personal #{}", i),
                descripcion: Some("Detalle de gasto personal para prueba multipagina".to_string()),
                categoria: Some("Gastos Personales".to_string()),
                monto: 10.0,
                fecha: format!("2026-10-{:02}", (i % 28) + 1),
            }).unwrap();
        }

        let summary = calculate_monthly_closing(&conn, 2026, 10).unwrap();
        assert_eq!(summary.gastos_personales.len(), 65);
        assert!((summary.total_gastos_personales - 650.0).abs() < 1e-6);
        assert!((summary.total_gastos - 650.0).abs() < 1e-6);
        assert!((summary.saldo_neto - (-650.0)).abs() < 1e-6);

        let pdf_bytes = generate_accounting_report_bytes_from_conn(&conn, 2026, 10).unwrap();
        assert!(pdf_bytes.len() > 1500);
        assert_eq!(&pdf_bytes[0..5], b"%PDF-");
    }
}



