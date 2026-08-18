use calamine::{open_workbook, Reader, Xlsx, Data};

#[derive(Debug, Clone)]
pub struct ParsedSession {
    pub fecha: String,        // YYYY-MM-DD format
    pub descripcion: String,  // concatenated treatment text
}

#[derive(Debug, Clone)]
pub struct ParsedPatient {
    pub nombre: String,
    pub apellido: String,
    pub cedula: Option<String>,
    pub fecha_nacimiento: Option<String>,
    pub telefono: Option<String>,
    pub email: Option<String>,
    pub direccion: Option<String>,
    pub profesion: Option<String>,
    pub condiciones_medicas: Option<String>,
    pub notas_generales: Option<String>,
    pub sesiones: Vec<ParsedSession>,
}

/// Extract a cell value as a trimmed String, returning None for empty/blank cells.
fn cell_str(range: &calamine::Range<Data>, row: u32, col: u32) -> Option<String> {
    let cell = range.get_value((row, col))?;
    match cell {
        Data::String(s) => {
            let trimmed = s.trim();
            if trimmed.is_empty() { None } else { Some(trimmed.to_string()) }
        }
        Data::Int(i) => Some(i.to_string()),
        Data::Float(f) => {
            // If the float is a whole number, format without decimals (e.g. phone numbers)
            if *f == (*f as i64) as f64 {
                Some((*f as i64).to_string())
            } else {
                Some(f.to_string())
            }
        }
        Data::DateTime(dt) => {
            // Use to_ymd_hms_milli() which is always available (no feature gate)
            let (year, month, day, _h, _m, _s, _ms) = dt.to_ymd_hms_milli();
            Some(format!("{:04}-{:02}-{:02}", year, month, day))
        }
        Data::DateTimeIso(s) => {
            let trimmed = s.trim();
            if trimmed.is_empty() { None } else { Some(trimmed.to_string()) }
        }
        Data::Bool(b) => Some(b.to_string()),
        Data::Empty => None,
        Data::Error(_) => None,
        Data::DurationIso(s) => {
            let trimmed = s.trim();
            if trimmed.is_empty() { None } else { Some(trimmed.to_string()) }
        }
    }
}

/// Check if a cell contains "X" or "x" (marking a checkbox).
fn cell_has_x(range: &calamine::Range<Data>, row: u32, col: u32) -> bool {
    if let Some(val) = cell_str(range, row, col) {
        val.trim().eq_ignore_ascii_case("x")
    } else {
        false
    }
}

/// Try to parse a text date like "12-9-75" or "12/9/1975" into YYYY-MM-DD.
fn parse_text_date(text: &str) -> Option<String> {
    let text = text.trim();
    if text.is_empty() {
        return None;
    }

    // Try common separators: -, /, .
    let parts: Vec<&str> = text.split(|c| c == '-' || c == '/' || c == '.').collect();
    if parts.len() == 3 {
        if let (Ok(a), Ok(b), Ok(c)) = (
            parts[0].trim().parse::<u32>(),
            parts[1].trim().parse::<u32>(),
            parts[2].trim().parse::<u32>(),
        ) {
            // Determine which is day, month, year
            // Format is typically D-M-Y or D-M-YY in this spa's files
            let (day, month, year_raw) = (a, b, c);

            let year = if year_raw < 100 {
                // Two-digit year: assume 1900s for values >= 25, 2000s for < 25
                if year_raw >= 25 { 1900 + year_raw } else { 2000 + year_raw }
            } else {
                year_raw
            };

            if month >= 1 && month <= 12 && day >= 1 && day <= 31 {
                return Some(format!("{:04}-{:02}-{:02}", year, month, day));
            }
        }
    }

    // Return the original text if we can't parse it
    Some(text.to_string())
}

/// Parse the sex field from cells J11/K11.
/// J11 contains "F" or "F X" for female, K11 contains "M" or "M X" for male.
fn parse_sexo(range: &calamine::Range<Data>) -> Option<String> {
    // Row 11 = index 10 (0-based), J = col 9, K = col 10
    let j11 = cell_str(range, 10, 9).unwrap_or_default().to_uppercase();
    let k11 = cell_str(range, 10, 10).unwrap_or_default().to_uppercase();

    // Check if either cell contains an X marking
    if j11.contains('X') || (j11.contains('F') && !k11.contains('X')) {
        // Female is marked
        if j11.contains('X') || j11.contains('F') {
            return Some("Femenino".to_string());
        }
    }
    if k11.contains('X') || (k11.contains('M') && !j11.contains('X')) {
        if k11.contains('X') || k11.contains('M') {
            return Some("Masculino".to_string());
        }
    }

    None
}

/// Build condiciones_medicas by checking rows 18-24 for labels and X marks.
fn build_condiciones_medicas(range: &calamine::Range<Data>) -> Option<String> {
    let mut conditions = Vec::new();

    // Rows 18-24 (0-based: 17-23)
    // Column A (0) has labels, and adjacent columns may have X marks
    // Column G (6) may also have labels with adjacent X marks
    for row in 17..=23 {
        // Check column A label + column B or C for X
        if let Some(label) = cell_str(range, row, 0) {
            if !label.is_empty() {
                // Check columns B(1), C(2) for X mark
                if cell_has_x(range, row, 1) || cell_has_x(range, row, 2) {
                    conditions.push(label);
                }
            }
        }

        // Check column D(3) or E(4) label + adjacent for X
        if let Some(label) = cell_str(range, row, 3) {
            if !label.is_empty() && !label.trim().eq_ignore_ascii_case("x") {
                if cell_has_x(range, row, 4) || cell_has_x(range, row, 5) {
                    conditions.push(label);
                }
            }
        }

        // Check column G(6) label + column H(7) for X
        if let Some(label) = cell_str(range, row, 6) {
            if !label.is_empty() && !label.trim().eq_ignore_ascii_case("x") {
                if cell_has_x(range, row, 7) || cell_has_x(range, row, 8) {
                    conditions.push(label);
                }
            }
        }
    }

    // Rows 16-17 (0-based: 15-16) - additional clinical data
    for row in 15..=16 {
        if let Some(label) = cell_str(range, row, 0) {
            if !label.is_empty() {
                if cell_has_x(range, row, 1) || cell_has_x(range, row, 2) {
                    conditions.push(label);
                }
            }
        }
        if let Some(label) = cell_str(range, row, 6) {
            if !label.is_empty() && !label.trim().eq_ignore_ascii_case("x") {
                if cell_has_x(range, row, 7) || cell_has_x(range, row, 8) {
                    conditions.push(label);
                }
            }
        }
    }

    if conditions.is_empty() {
        None
    } else {
        Some(conditions.join(", "))
    }
}

/// Build notas_generales from diagnostic info, plan terapéutico, tattoos, and cosmetic habits.
fn build_notas_generales(range: &calamine::Range<Data>) -> Option<String> {
    let mut notas_parts = Vec::new();

    // Diagnostic info: columns M-U (12-20), rows 11-14 (0-based: 10-13)
    let mut diagnostics = Vec::new();
    for row in 10..=13 {
        for col in 12..=20 {
            if let Some(label) = cell_str(range, row, col) {
                let label_trimmed = label.trim();
                if !label_trimmed.is_empty() && !label_trimmed.eq_ignore_ascii_case("x") {
                    // Check if the next column has an X mark
                    if col + 1 <= 20 && cell_has_x(range, row, col + 1) {
                        diagnostics.push(label_trimmed.to_string());
                    }
                }
            }
        }
    }
    if !diagnostics.is_empty() {
        notas_parts.push(format!("Diagnósticos: {}", diagnostics.join(", ")));
    }

    // Plan terapéutico: N24-N25 (0-based: rows 23-24, col 13)
    let mut plan = Vec::new();
    if let Some(p1) = cell_str(range, 23, 13) {
        plan.push(p1);
    }
    if let Some(p2) = cell_str(range, 24, 13) {
        plan.push(p2);
    }
    if !plan.is_empty() {
        notas_parts.push(format!("Plan terapéutico: {}", plan.join(" ")));
    }

    // Tattoos and plastic surgery: rows 27-28 (0-based: 26-27)
    let mut body_mods = Vec::new();
    for row in 26..=27 {
        if let Some(label) = cell_str(range, row, 0) {
            let label_trimmed = label.trim();
            if !label_trimmed.is_empty() {
                // Check for SI/NO marks in adjacent cells
                let has_si = cell_has_x(range, row, 1) || cell_has_x(range, row, 2);
                if has_si {
                    body_mods.push(format!("{}: Sí", label_trimmed));
                }
            }
        }
    }
    if !body_mods.is_empty() {
        notas_parts.push(body_mods.join(", "));
    }

    // Cosmetic habits: rows 34-36 (0-based: 33-35)
    let mut habits = Vec::new();
    for row in 33..=35 {
        // Collect any non-empty text across columns A-H
        let mut row_text = Vec::new();
        for col in 0..=8 {
            if let Some(val) = cell_str(range, row, col) {
                let trimmed = val.trim();
                if !trimmed.is_empty() {
                    row_text.push(trimmed.to_string());
                }
            }
        }
        if !row_text.is_empty() {
            habits.push(row_text.join(" "));
        }
    }
    if !habits.is_empty() {
        notas_parts.push(format!("Hábitos cosméticos: {}", habits.join("; ")));
    }

    // Sexo
    if let Some(sexo) = parse_sexo(range) {
        notas_parts.push(format!("Sexo: {}", sexo));
    }

    if notas_parts.is_empty() {
        None
    } else {
        Some(notas_parts.join("\n"))
    }
}

/// Parse sessions starting from row 38 (0-based: 37).
/// When column A has a date, start a new session.
/// Concatenate all column B text until the next date row.
fn parse_sessions(range: &calamine::Range<Data>) -> Vec<ParsedSession> {
    let mut sessions = Vec::new();
    let (max_row, _max_col) = range.end().unwrap_or((0, 0));

    let mut current_date: Option<String> = None;
    let mut current_desc = Vec::new();

    for row in 37..=max_row as u32 {
        let col_a = cell_str(range, row, 0);

        // Check if column A has a date value
        let is_date_row = if let Some(ref val) = col_a {
            // Check if it looks like a date: contains separators or is a formatted date
            let trimmed = val.trim();
            !trimmed.is_empty() && (
                trimmed.contains('-') ||
                trimmed.contains('/') ||
                trimmed.contains('.') ||
                // Also matches YYYY-MM-DD format already formatted by cell_str
                (trimmed.len() >= 6 && trimmed.chars().any(|c| c.is_ascii_digit()))
            )
        } else {
            // Also check if the raw cell is a DateTime type
            if let Some(cell) = range.get_value((row, 0)) {
                matches!(cell, Data::DateTime(_) | Data::DateTimeIso(_))
            } else {
                false
            }
        };

        if is_date_row {
            // Save previous session if exists
            if let Some(date) = current_date.take() {
                let desc = current_desc.join("\n").trim().to_string();
                if !desc.is_empty() {
                    sessions.push(ParsedSession {
                        fecha: date,
                        descripcion: desc,
                    });
                }
                current_desc.clear();
            }

            // Start new session
            let date_str = col_a.unwrap_or_default();
            // Try to format as YYYY-MM-DD
            let formatted_date = if date_str.contains('-') && date_str.len() == 10 && date_str.starts_with(|c: char| c.is_ascii_digit()) {
                // Already YYYY-MM-DD
                date_str
            } else {
                parse_text_date(&date_str).unwrap_or(date_str)
            };

            current_date = Some(formatted_date);

            // Also grab column B text from this row
            if let Some(desc) = cell_str(range, row, 1) {
                current_desc.push(desc);
            }
        } else if current_date.is_some() {
            // No date in column A — append column B text to current session
            if let Some(desc) = cell_str(range, row, 1) {
                current_desc.push(desc);
            }
        }
    }

    // Don't forget the last session
    if let Some(date) = current_date {
        let desc = current_desc.join("\n").trim().to_string();
        if !desc.is_empty() {
            sessions.push(ParsedSession {
                fecha: date,
                descripcion: desc,
            });
        }
    }

    sessions
}

/// Parse an Excel workbook where each sheet represents one patient.
/// Returns a Vec of parsed patients with their sessions.
pub fn parse_excel(file_path: String) -> Result<Vec<ParsedPatient>, String> {
    let mut workbook: Xlsx<_> = open_workbook(&file_path)
        .map_err(|e| format!("Error al abrir excel: {}", e))?;

    let sheet_names = workbook.sheet_names().to_owned();
    if sheet_names.is_empty() {
        return Err("El archivo Excel no tiene hojas".to_string());
    }

    let mut patients = Vec::new();

    for sheet_name in &sheet_names {
        let range = match workbook.worksheet_range(sheet_name) {
            Ok(r) => r,
            Err(e) => {
                log::warn!("No se pudo leer la hoja '{}': {}", sheet_name, e);
                continue;
            }
        };

        // Check if this sheet has enough rows to be a patient sheet
        let (max_row, _) = range.end().unwrap_or((0, 0));
        if max_row < 10 {
            continue; // Skip sheets that are too small to contain patient data
        }

        // --- Patient Info ---
        // D10 (0-based: row 9, col 3): Full name
        let full_name = cell_str(&range, 9, 3)
            .or_else(|| Some(sheet_name.clone()))
            .unwrap_or_default();

        let (nombre, apellido) = split_name(&full_name);

        // C11 (row 10, col 2): Cédula
        let cedula = cell_str(&range, 10, 2);

        // E11 (row 10, col 4): Edad — stored but not mapped to DB field directly

        // H11 (row 10, col 7): Fecha de nacimiento
        let fecha_nacimiento = cell_str(&range, 10, 7).and_then(|val| {
            // If already in YYYY-MM-DD format, keep it
            if val.len() == 10 && val.chars().nth(4) == Some('-') {
                Some(val)
            } else {
                parse_text_date(&val)
            }
        });

        // F12 (row 11, col 5): Teléfono
        let telefono = cell_str(&range, 11, 5);

        // C12 (row 11, col 2): Profesión
        let profesion = cell_str(&range, 11, 2);

        // C13 (row 12, col 2): Dirección
        let direccion = cell_str(&range, 12, 2);

        // D14 (row 13, col 3): Email
        let email = cell_str(&range, 13, 3);

        // --- Clinical Data ---
        let condiciones_medicas = build_condiciones_medicas(&range);
        let notas_generales = build_notas_generales(&range);

        // --- Sessions ---
        let sesiones = parse_sessions(&range);

        patients.push(ParsedPatient {
            nombre,
            apellido,
            cedula,
            fecha_nacimiento,
            telefono,
            email,
            direccion,
            profesion,
            condiciones_medicas,
            notas_generales,
            sesiones,
        });
    }

    Ok(patients)
}

/// Split a full name into (nombre, apellido).
/// First word = nombre, rest = apellido.
fn split_name(full_name: &str) -> (String, String) {
    let trimmed = full_name.trim();
    if trimmed.is_empty() {
        return ("Sin nombre".to_string(), String::new());
    }

    let parts: Vec<&str> = trimmed.splitn(2, ' ').collect();
    let nombre = parts[0].to_string();
    let apellido = if parts.len() > 1 {
        parts[1].trim().to_string()
    } else {
        String::new()
    };

    (nombre, apellido)
}
