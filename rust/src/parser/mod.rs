use calamine::{open_workbook, Reader, Xlsx, Data};

#[derive(Debug, Clone)]
pub struct ParsedSession {
    pub fecha: String,        // YYYY-MM-DD format
    pub descripcion: String,  // concatenated treatment text
    pub tipo: String,         // "facial" or "corporal"
    pub peso: Option<String>,
    pub altura: Option<f64>,
    pub imc: Option<f64>,
    pub grasa_corporal: Option<f64>,
    pub agua_corporal: Option<f64>,
    pub medida_cadera: Option<String>,
    pub medida_cintura: Option<String>,
    pub medida_brazos: Option<String>,
    pub medida_pecho: Option<String>,
    pub medida_piernas: Option<String>,
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
    pub afecciones_cutaneas: Option<String>,
    pub alergias: Option<String>,
    pub tatuajes: Option<String>,
    pub cirugia_plastica: Option<String>,
    pub antecedentes_medicos: Option<String>,
    pub ubicacion_lesiones: Option<String>,
    pub tipo_piel: Option<String>,
    pub cicatrizacion: Option<String>,
    pub diagnostico_visual: Option<String>,
    pub diagnostico_tactil: Option<String>,
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

fn cell_num(range: &calamine::Range<Data>, row: u32, col: u32) -> Option<f64> {
    let cell = range.get_value((row, col))?;
    match cell {
        Data::Float(f) => Some(*f),
        Data::Int(i) => Some(*i as f64),
        Data::String(s) => {
            let cleaned = s.replace(',', ".");
            let mut num_str = String::new();
            let mut seen_dot = false;
            let mut started = false;
            for c in cleaned.trim().chars() {
                if c.is_ascii_digit() {
                    num_str.push(c);
                    started = true;
                } else if c == '.' && !seen_dot && started {
                    num_str.push(c);
                    seen_dot = true;
                } else if started {
                    break;
                }
            }
            num_str.parse::<f64>().ok()
        }
        _ => None,
    }
}

fn cell_percentage(range: &calamine::Range<Data>, row: u32, col: u32) -> Option<f64> {
    let num = cell_num(range, row, col)?;
    if num > 0.0 && num <= 1.0 {
        Some((num * 1000.0).round() / 10.0)
    } else {
        Some((num * 10.0).round() / 10.0)
    }
}

fn clean_cell_str(range: &calamine::Range<Data>, row: u32, col: u32) -> Option<String> {
    let s = cell_str(range, row, col)?;
    let upper = s.trim().to_uppercase();
    if upper == "NO" || upper == "NONE" || upper.starts_with("NO SE PESO") || upper.starts_with("HOY NO SE PESO") {
        None
    } else {
        Some(s)
    }
}

/// Check if a cell contains "X" or "x" (marking a checkbox).
fn cell_has_x(range: &calamine::Range<Data>, row: u32, col: u32) -> bool {
    if let Some(val) = cell_str(range, row, col) {
        let upper = val.trim().to_uppercase();
        if upper == "X" || upper == "(X)" || upper == "[X]" || upper.starts_with("X ") || upper.starts_with("X-") || upper.ends_with(" X") {
            true
        } else {
            upper.split_whitespace().any(|word| word == "X" || word == "(X)" || word == "[X]")
        }
    } else {
        false
    }
}

/// Check if a cell has X and returns optional additional note (e.g. "X GRAVE" -> "GRAVE").
fn cell_check_x_note(range: &calamine::Range<Data>, row: u32, col: u32) -> Option<String> {
    if let Some(val) = cell_str(range, row, col) {
        let upper = val.trim().to_uppercase();
        if upper == "X" || upper == "(X)" || upper == "[X]" {
            Some(String::new())
        } else if upper.starts_with("X ") || upper.starts_with("X-") {
            Some(upper[2..].trim().to_string())
        } else if upper.split_whitespace().any(|w| w == "X") {
            let words: Vec<&str> = upper.split_whitespace().filter(|w| *w != "X").collect();
            Some(words.join(" "))
        } else {
            None
        }
    } else {
        None
    }
}

/// Try to parse a text date like "12-9-75", "12/9/1975" or "2022-05-09 00:00:00" into YYYY-MM-DD.
fn parse_text_date(text: &str) -> Option<String> {
    let text = text.trim();
    if text.is_empty() {
        return None;
    }

    let date_part = text.split_whitespace().next().unwrap_or(text);

    // Try common separators: -, /, .
    let parts: Vec<&str> = date_part.split(|c| c == '-' || c == '/' || c == '.').collect();
    if parts.len() == 3 {
        if let (Ok(a), Ok(b), Ok(c)) = (
            parts[0].trim().parse::<u32>(),
            parts[1].trim().parse::<u32>(),
            parts[2].trim().parse::<u32>(),
        ) {
            let (year, month, day) = if a > 1000 {
                // Format YYYY-MM-DD
                (a, b, c)
            } else {
                // Format D-M-Y or D-M-YY
                let (day, month, year_raw) = (a, b, c);
                let year = if year_raw < 100 {
                    if year_raw >= 25 { 1900 + year_raw } else { 2000 + year_raw }
                } else {
                    year_raw
                };
                (year, month, day)
            };

            if month >= 1 && month <= 12 && day >= 1 && day <= 31 {
                return Some(format!("{:04}-{:02}-{:02}", year, month, day));
            }
        }
    }

    // Return the original date part if we can't parse it
    Some(date_part.to_string())
}

fn parse_sexo(range: &calamine::Range<Data>, base_row: u32) -> Option<String> {
    // Row 11 (index 10) -> base_row + 1
    let row_idx = base_row + 1;
    let j11 = cell_str(range, row_idx, 9).unwrap_or_default().to_uppercase();
    let k11 = cell_str(range, row_idx, 10).unwrap_or_default().to_uppercase();

    if j11.contains('X') || (j11.contains('F') && !k11.contains('X')) {
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

fn extract_ubicacion_lesiones(range: &calamine::Range<Data>) -> Option<String> {
    let mut parts = Vec::new();
    // Rows 2 to 6 (0-indexed, 1-based rows 3 to 7)
    for r in 2..=6 {
        for c in 12..=24 {
            if let Some(val) = cell_str(range, r, c) {
                let upper = val.to_uppercase();
                if !upper.contains("UBICACI") && !upper.is_empty() {
                    parts.push(val);
                }
            }
        }
    }
    if parts.is_empty() { None } else { Some(parts.join("\n")) }
}

fn extract_diagnostico_facial(
    range: &calamine::Range<Data>,
) -> (
    Option<String>, // visual
    Option<String>, // tactil
    Option<String>, // tipo_piel
    Option<String>, // cicatrizacion
) {
    let mut visual = Vec::new();
    let mut tactil = Vec::new();
    let mut tipo_piel = Vec::new();
    let mut cicatrizacion = Vec::new();

    // Diagnóstico visual and táctil: rows 9 to 15 (0-indexed, 1-based rows 10 to 16)
    for r in 9..=15 {
        // Visual Col 12 (1-based 13): check col 13, 14
        if let Some(lbl) = cell_str(range, r, 12) {
            let upper = lbl.to_uppercase();
            if !upper.contains("DIAGNÓSTICO") && !upper.contains("DIAGNOSTICO") && !upper.is_empty() {
                if cell_has_x(range, r, 13) || cell_has_x(range, r, 14) {
                    visual.push(lbl);
                }
            }
        }
        // Visual Col 15 (1-based 16): check col 16, 17
        if let Some(lbl) = cell_str(range, r, 15) {
            let upper = lbl.to_uppercase();
            if !upper.contains("DIAGNÓSTICO") && !upper.contains("DIAGNOSTICO") && !upper.is_empty() {
                if cell_has_x(range, r, 16) || cell_has_x(range, r, 17) {
                    visual.push(lbl);
                }
            }
        }
        // Tactil Col 18 (1-based 19): check col 19, 20, 21
        if let Some(lbl) = cell_str(range, r, 18) {
            let upper = lbl.to_uppercase();
            if !upper.contains("DIAGNÓSTICO") && !upper.contains("DIAGNOSTICO") && !upper.is_empty() {
                if cell_has_x(range, r, 19) || cell_has_x(range, r, 20) || cell_has_x(range, r, 21) {
                    tactil.push(lbl);
                }
            }
        }
    }

    // Tipo de piel and Cicatrización: rows 16 to 20 (0-indexed, 1-based rows 17 to 21)
    for r in 16..=20 {
        // Tipo de piel Col 12 (1-based 13): check col 13, 14, 15
        if let Some(lbl) = cell_str(range, r, 12) {
            let upper = lbl.to_uppercase();
            if !upper.contains("DIAGNÓSTICO") && !upper.contains("DIAGNOSTICO") && !upper.contains("TIPO DE PIEL") && !upper.is_empty() {
                if cell_has_x(range, r, 13) || cell_has_x(range, r, 14) || cell_has_x(range, r, 15) {
                    tipo_piel.push(lbl);
                }
            }
        }
        // Tipo de piel Col 15 (1-based 16): check col 16, 17
        if let Some(lbl) = cell_str(range, r, 15) {
            let upper = lbl.to_uppercase();
            if !upper.contains("DIAGNÓSTICO") && !upper.contains("DIAGNOSTICO") && !upper.contains("TIPO DE PIEL") && !upper.is_empty() {
                if cell_has_x(range, r, 16) || cell_has_x(range, r, 17) {
                    tipo_piel.push(lbl);
                }
            }
        }
        // Cicatrización Col 18 (1-based 19): check col 19, 20, 21
        if let Some(lbl) = cell_str(range, r, 18) {
            let upper = lbl.to_uppercase();
            if !upper.contains("CICATRIZ") && !upper.is_empty() {
                if cell_has_x(range, r, 19) || cell_has_x(range, r, 20) || cell_has_x(range, r, 21) {
                    cicatrizacion.push(lbl);
                }
            }
        }
    }

    (
        if visual.is_empty() { None } else { Some(visual.join(", ")) },
        if tactil.is_empty() { None } else { Some(tactil.join(", ")) },
        if tipo_piel.is_empty() { None } else { Some(tipo_piel.join(", ")) },
        if cicatrizacion.is_empty() { None } else { Some(cicatrizacion.join(", ")) },
    )
}

fn extract_datos_clinicos(
    range: &calamine::Range<Data>,
) -> (
    Option<String>, // condiciones_medicas
    Option<String>, // afecciones_cutaneas
    Option<String>, // alergias
    Option<String>, // tatuajes
    Option<String>, // cirugia_plastica
    Option<String>, // antecedentes_medicos
) {
    let mut enfermedades = Vec::new();
    let mut afecciones = Vec::new();
    let mut alergias_list = Vec::new();

    // Rows 17 to 24 (0-indexed, 1-based rows 18 to 25)
    for r in 17..=24 {
        // Col A (0): Enfermedades generales
        if let Some(lbl) = cell_str(range, r, 0) {
            let upper = lbl.to_uppercase();
            if !upper.contains("ENFERMEDAD") && !upper.is_empty() {
                if cell_has_x(range, r, 1) || cell_has_x(range, r, 2) || cell_has_x(range, r, 3) {
                    enfermedades.push(lbl);
                }
            }
        }

        // Col G (6): Afecciones dérmicas y/o ojos / Alergias
        if let Some(lbl) = cell_str(range, r, 6) {
            let upper = lbl.to_uppercase();
            if upper.contains("CUALES") || upper.contains("CUÁLES") {
                let mut c_text = Vec::new();
                for c in 7..=12 {
                    if let Some(val) = cell_str(range, r, c) {
                        let trimmed = val.trim();
                        if !trimmed.is_empty() && !trimmed.starts_with('_') {
                            c_text.push(trimmed.to_string());
                        }
                    }
                }
                if !c_text.is_empty() {
                    alergias_list.push(c_text.join(" "));
                }
            } else if !upper.contains("AFECCIONES") && !upper.is_empty() {
                let mut marked = false;
                let mut note = String::new();
                for c in 7..=11 {
                    if let Some(n) = cell_check_x_note(range, r, c) {
                        marked = true;
                        if !n.is_empty() {
                            note = n;
                        }
                    }
                }
                if marked {
                    if !note.is_empty() {
                        afecciones.push(format!("{} ({})", lbl, note));
                    } else {
                        afecciones.push(lbl);
                    }
                }
            }
        }
    }

    // Tatuajes & Cirugías: rows 25 to 28 (0-indexed, 1-based 26 to 29)
    let mut tatuajes = None;
    let mut cirugias = None;
    for r in 25..=28 {
        for c in 0..=4 {
            if let Some(val) = cell_str(range, r, c) {
                let upper = val.to_uppercase();
                if upper == "SI" || upper == "SÍ" {
                    if cell_has_x(range, r, c + 1) || cell_has_x(range, r, c + 2) {
                        tatuajes = Some("Sí".to_string());
                    }
                } else if upper == "NO" {
                    if cell_has_x(range, r, c + 1) || cell_has_x(range, r, c + 2) {
                        if tatuajes.is_none() {
                            tatuajes = Some("No".to_string());
                        }
                    }
                }
            }
        }

        for c in 6..=11 {
            if let Some(val) = cell_str(range, r, c) {
                let upper = val.to_uppercase();
                if upper == "SI" || upper == "SÍ" {
                    if cell_has_x(range, r, c + 1) || cell_has_x(range, r, c + 2) {
                        cirugias = Some("Sí".to_string());
                    }
                } else if upper == "NO" {
                    if cell_has_x(range, r, c + 1) || cell_has_x(range, r, c + 2) {
                        if cirugias.is_none() {
                            cirugias = Some("No".to_string());
                        }
                    }
                }
            }
        }
    }

    // Antecedentes médicos: rows 29 to 33 (0-indexed, 1-based 30 to 34)
    let mut antecedentes = Vec::new();
    for r in 29..=33 {
        for c in 0..=12 {
            if let Some(val) = cell_str(range, r, c) {
                let upper = val.to_uppercase();
                if !upper.contains("ANTECEDENTES") && !upper.is_empty() && !upper.starts_with('_') {
                    antecedentes.push(val);
                }
            }
        }
    }

    (
        if enfermedades.is_empty() { None } else { Some(enfermedades.join(", ")) },
        if afecciones.is_empty() { None } else { Some(afecciones.join(", ")) },
        if alergias_list.is_empty() { None } else { Some(alergias_list.join(", ")) },
        tatuajes,
        cirugias,
        if antecedentes.is_empty() { None } else { Some(antecedentes.join(" ")) },
    )
}

fn build_notas_generales(range: &calamine::Range<Data>, base_row: u32) -> Option<String> {
    let mut notas_parts = Vec::new();

    // Plan terapéutico: base_row + 14 and base_row + 15
    let mut plan = Vec::new();
    if let Some(p1) = cell_str(range, base_row + 14, 13) { plan.push(p1); }
    if let Some(p2) = cell_str(range, base_row + 15, 13) { plan.push(p2); }
    if !plan.is_empty() {
        notas_parts.push(format!("Plan terapéutico: {}", plan.join(" ")));
    }

    // Cosmetic habits: base_row + 24 to base_row + 26
    let mut habits = Vec::new();
    for row in (base_row + 24)..=(base_row + 26) {
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

    if let Some(sexo) = parse_sexo(range, base_row) {
        notas_parts.push(format!("Sexo: {}", sexo));
    }

    if notas_parts.is_empty() { None } else { Some(notas_parts.join("\n")) }
}

fn parse_sessions(range: &calamine::Range<Data>, base_row: u32) -> Vec<ParsedSession> {
    let mut sessions = Vec::new();
    let (max_row, _max_col) = range.end().unwrap_or((0, 0));

    let mut current_date: Option<String> = None;
    let mut current_desc = Vec::new();

    let start_row = base_row + 28; // Usually row 38 (index 37) if base_row is 9
    for row in start_row..=max_row as u32 {
        let col_a = cell_str(range, row, 0);

        let is_date_row = if let Some(ref val) = col_a {
            let trimmed = val.trim();
            !trimmed.is_empty() && (
                trimmed.contains('-') ||
                trimmed.contains('/') ||
                trimmed.contains('.') ||
                (trimmed.len() >= 6 && trimmed.chars().any(|c| c.is_ascii_digit()))
            )
        } else {
            if let Some(cell) = range.get_value((row, 0)) {
                matches!(cell, Data::DateTime(_) | Data::DateTimeIso(_))
            } else { false }
        };

        if is_date_row {
            if let Some(date) = current_date.take() {
                let desc = current_desc.join("\n").trim().to_string();
                if !desc.is_empty() {
                    sessions.push(ParsedSession {
                        fecha: date,
                        descripcion: desc,
                        tipo: "facial".to_string(),
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
                    });
                }
                current_desc.clear();
            }

            let date_str = col_a.unwrap_or_default();
            let formatted_date = if date_str.contains('-') && date_str.len() == 10 && date_str.starts_with(|c: char| c.is_ascii_digit()) {
                date_str
            } else {
                parse_text_date(&date_str).unwrap_or(date_str)
            };

            current_date = Some(formatted_date);

            if let Some(desc) = cell_str(range, row, 1) {
                current_desc.push(desc);
            }
        } else if current_date.is_some() {
            if let Some(desc) = cell_str(range, row, 1) {
                current_desc.push(desc);
            }
        }
    }

    if let Some(date) = current_date {
        let desc = current_desc.join("\n").trim().to_string();
        if !desc.is_empty() {
            sessions.push(ParsedSession {
                fecha: date,
                descripcion: desc,
                tipo: "facial".to_string(),
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
            });
        }
    }

    sessions
}

fn parse_corporal_sessions(range: &calamine::Range<Data>) -> Vec<ParsedSession> {
    let mut sessions = Vec::new();
    let (max_row, max_col) = range.end().unwrap_or((0, 0));

    // 1. Check for "EVALUACIÓN INICIAL" or "EVALUACION INICIAL"
    let mut eval_row: Option<u32> = None;
    for r in 0..std::cmp::min(max_row as u32, 60) {
        for c in 11..std::cmp::min(max_col as u32, 26) {
            if let Some(s) = cell_str(range, r, c) {
                let su = s.to_uppercase();
                if su.contains("EVALUACIÓN INICIAL") || su.contains("EVALUACION INICIAL") {
                    eval_row = Some(r);
                    break;
                }
            }
        }
        if eval_row.is_some() { break; }
    }

    if let Some(er) = eval_row {
        let mut eval_date = None;
        for c in 0..26 {
            if let Some(d_str) = cell_str(range, er, c) {
                if let Some(d) = parse_text_date(&d_str) {
                    if d.contains('-') && d.len() == 10 && d.starts_with(|ch: char| ch.is_ascii_digit()) {
                        eval_date = Some(d);
                        break;
                    }
                }
            }
        }
        if eval_date.is_none() {
            if let Some(d_str) = cell_str(range, 2, 3) {
                eval_date = parse_text_date(&d_str);
            }
        }

        let mut peso = None;
        let mut altura = None;
        let mut imc = None;
        let mut grasa = None;
        let mut agua = None;

        for r in (er + 1)..=std::cmp::min(er + 3, max_row as u32) {
            for c in 11..std::cmp::min(max_col as u32, 26) {
                if let Some(label) = cell_str(range, r, c) {
                    let lu = label.trim().to_uppercase();
                    if lu == "PESO" {
                        peso = clean_cell_str(range, r + 1, c);
                    } else if lu.contains("ALTURA") {
                        altura = cell_num(range, r + 1, c);
                    } else if lu == "IMC" {
                        imc = cell_num(range, r + 1, c).or_else(|| cell_num(range, r + 1, c + 1));
                    } else if lu.contains("GRASA") {
                        grasa = cell_percentage(range, r + 1, c)
                            .or_else(|| cell_percentage(range, r + 1, c + 1))
                            .or_else(|| cell_percentage(range, r + 1, c + 2));
                    } else if lu.contains("AGUA") {
                        agua = cell_percentage(range, r + 1, c)
                            .or_else(|| cell_percentage(range, r + 1, c + 1))
                            .or_else(|| cell_percentage(range, r + 1, c + 2));
                    }
                }
            }
        }

        let mut cadera = None;
        let mut pecho = None;
        let mut brazos = None;
        let mut cintura = None;
        let mut piernas = None;

        for r in (er + 3)..=std::cmp::min(er + 7, max_row as u32) {
            for c in 11..std::cmp::min(max_col as u32, 26) {
                if let Some(label) = cell_str(range, r, c) {
                    let lu = label.trim().to_uppercase();
                    if lu == "CADERA" || lu == "CADERAS" {
                        cadera = clean_cell_str(range, r + 1, c);
                    } else if lu == "BUSTO" || lu == "PECHO" {
                        pecho = clean_cell_str(range, r + 1, c);
                    } else if lu.contains("BRAZO") {
                        brazos = clean_cell_str(range, r + 1, c);
                    } else if lu.contains("CINTURA") {
                        cintura = clean_cell_str(range, r + 1, c);
                    } else if lu.contains("PIERNA") {
                        piernas = clean_cell_str(range, r + 1, c);
                    }
                }
            }
        }

        if let Some(ed) = eval_date {
            if peso.is_some() || grasa.is_some() || cadera.is_some() || cintura.is_some() || imc.is_some() {
                sessions.push(ParsedSession {
                    fecha: ed,
                    descripcion: "Evaluación Inicial Corporal".to_string(),
                    tipo: "corporal".to_string(),
                    peso,
                    altura,
                    imc,
                    grasa_corporal: grasa,
                    agua_corporal: agua,
                    medida_cadera: cadera,
                    medida_cintura: cintura,
                    medida_brazos: brazos,
                    medida_pecho: pecho,
                    medida_piernas: piernas,
                });
            }
        }
    }

    // 2. Scan for session rows (where column in 11..23 contains "FECHA")
    let mut last_valid_date: Option<String> = None;
    for r in 0..=max_row as u32 {
        let mut fecha_col = None;
        for c in 11..std::cmp::min(max_col as u32, 23) {
            if let Some(val) = cell_str(range, r, c) {
                if val.trim().eq_ignore_ascii_case("FECHA") {
                    fecha_col = Some(c);
                    break;
                }
            }
        }

        let fc = match fecha_col {
            Some(c) => c,
            None => continue,
        };

        let raw_date = match cell_str(range, r, fc + 1) {
            Some(d) => d,
            None => continue,
        };

        let mut date_str = match parse_text_date(&raw_date) {
            Some(d) => {
                if d.contains('-') && d.len() == 10 && d.starts_with(|ch: char| ch.is_ascii_digit()) {
                    d
                } else {
                    continue;
                }
            }
            None => continue,
        };

        // Prevent dates with year < 2010 (e.g. corrupted Excel 1900-02-04 dates)
        if let Some(y) = date_str.split('-').next().and_then(|ys| ys.parse::<i32>().ok()) {
            if y < 2010 {
                if let Some(ref prev) = last_valid_date {
                    date_str = prev.clone();
                } else {
                    continue;
                }
            } else {
                last_valid_date = Some(date_str.clone());
            }
        }

        let sesion_label = if fc > 0 {
            clean_cell_str(range, r, fc - 1)
                .or_else(|| clean_cell_str(range, r + 1, fc - 1))
                .unwrap_or_default()
        } else {
            String::new()
        };

        let mut peso = None;
        let mut imc = None;
        let mut grasa = None;
        let mut agua = None;

        for c in fc..std::cmp::min(max_col as u32, 26) {
            if let Some(val) = cell_str(range, r, c) {
                let vu = val.trim().to_uppercase();
                if vu == "PESO" {
                    peso = clean_cell_str(range, r, c + 1);
                } else if vu == "IMC" {
                    imc = cell_num(range, r, c + 1);
                } else if vu.contains("GRASA") {
                    grasa = cell_percentage(range, r, c + 1)
                        .or_else(|| cell_percentage(range, r, c + 2));
                } else if vu.contains("AGUA") {
                    agua = cell_percentage(range, r, c + 1)
                        .or_else(|| cell_percentage(range, r, c + 2));
                }
            }
        }

        // Next row measurements
        let mut cadera = None;
        let mut brazos = None;
        let mut cintura = None;
        let mut cintura_alta = None;
        let mut cintura_baja = None;
        let mut pecho = None;
        let mut piernas = None;

        if r + 1 <= max_row as u32 {
            for c in 11..std::cmp::min(max_col as u32, 26) {
                if let Some(val) = cell_str(range, r + 1, c) {
                    let vu = val.trim().to_uppercase();
                    if vu.contains("CADERA") {
                        cadera = clean_cell_str(range, r + 1, c + 1);
                    } else if vu.contains("BRAZO") {
                        brazos = clean_cell_str(range, r + 1, c + 1);
                    } else if vu.contains("CINTURA ALTA") {
                        cintura_alta = clean_cell_str(range, r + 1, c + 1)
                            .or_else(|| clean_cell_str(range, r + 1, c + 2));
                    } else if vu.contains("CINTURA BAJA") {
                        cintura_baja = clean_cell_str(range, r + 1, c + 1)
                            .or_else(|| clean_cell_str(range, r + 1, c + 2));
                    } else if vu.contains("CINTURA") {
                        cintura = clean_cell_str(range, r + 1, c + 1);
                    } else if vu.contains("PECHO") || vu.contains("BUSTO") {
                        pecho = clean_cell_str(range, r + 1, c + 1);
                    } else if vu.contains("PIERNA") {
                        piernas = clean_cell_str(range, r + 1, c + 1);
                    }
                }
            }
        }

        if cintura_alta.is_some() || cintura_baja.is_some() {
            let mut parts = Vec::new();
            if let Some(ca) = cintura_alta { parts.push(format!("Alta: {}", ca)); }
            if let Some(cb) = cintura_baja { parts.push(format!("Baja: {}", cb)); }
            cintura = Some(parts.join(", "));
        }

        // Search for notes in next rows
        let mut notes = Vec::new();
        for roff in 1..=2 {
            if r + roff <= max_row as u32 {
                for cc in 11..16 {
                    if let Some(cv) = cell_str(range, r + roff, cc) {
                        let cu = cv.to_uppercase();
                        if cu.contains("DRENAJE") || cu.contains("HIFU") || cu.contains("MASAJES")
                            || cu.contains("EXPEDIENTE") || cu.contains("SESIONES") || cu.contains("AQUÍ")
                            || cu.contains("MESOTERAPIA") || cu.contains("NUEVA TANDA") {
                            notes.push(cv);
                            break;
                        }
                    }
                }
            }
        }

        let mut desc = if sesion_label.is_empty() {
            "Sesión Corporal".to_string()
        } else {
            format!("Sesión Corporal {}", sesion_label)
        };
        if !notes.is_empty() {
            desc.push_str(" - ");
            desc.push_str(&notes.join(" "));
        }

        sessions.push(ParsedSession {
            fecha: date_str,
            descripcion: desc,
            tipo: "corporal".to_string(),
            peso,
            altura: None,
            imc,
            grasa_corporal: grasa,
            agua_corporal: agua,
            medida_cadera: cadera,
            medida_cintura: cintura,
            medida_brazos: brazos,
            medida_pecho: pecho,
            medida_piernas: piernas,
        });
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
        // Buscamos dinámicamente la fila base buscando "NOMBRE Y APELLIDO:" en la columna A
        let mut base_row = 9; // Por defecto fila 10 (índice 9)
        for r in 6..12 {
            if let Some(val) = cell_str(&range, r, 0) {
                if val.to_uppercase().contains("NOMBRE Y APELLIDO") {
                    base_row = r;
                    break;
                }
            }
        }

        // Nombre: Columna D
        let full_name = cell_str(&range, base_row, 3)
            .or_else(|| Some(sheet_name.clone()))
            .unwrap_or_default();

        let (nombre, apellido) = split_name(&full_name);

        // Cédula: Columna C de la siguiente fila
        let cedula = cell_str(&range, base_row + 1, 2);

        // Fecha de nacimiento: Columna H de la siguiente fila
        let fecha_nacimiento = cell_str(&range, base_row + 1, 7).and_then(|val| {
            if val.len() == 10 && val.chars().nth(4) == Some('-') {
                Some(val)
            } else {
                parse_text_date(&val)
            }
        });

        // Teléfono: Columna F, +2 filas
        let telefono = cell_str(&range, base_row + 2, 5);

        // Profesión: Columna C, +2 filas
        let profesion = cell_str(&range, base_row + 2, 2);

        // Dirección: Columna C o D, +3 filas
        let direccion = cell_str(&range, base_row + 3, 2)
            .or_else(|| cell_str(&range, base_row + 3, 3));

        // Email: Columna D, +4 filas
        let email = cell_str(&range, base_row + 4, 3)
            .or_else(|| cell_str(&range, base_row + 3, 3)); // A veces email está en C13 o D13

        // --- Clinical & Facial Data ---
        let ubicacion_lesiones = extract_ubicacion_lesiones(&range);
        let (diagnostico_visual, diagnostico_tactil, tipo_piel, cicatrizacion) =
            extract_diagnostico_facial(&range);
        let (condiciones_medicas, afecciones_cutaneas, alergias, tatuajes, cirugia_plastica, antecedentes_medicos) =
            extract_datos_clinicos(&range);
        let notas_generales = build_notas_generales(&range, base_row);

        // --- Sessions ---
        let mut sesiones = parse_sessions(&range, base_row);
        let mut corporal_sesiones = parse_corporal_sessions(&range);
        sesiones.append(&mut corporal_sesiones);

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
            afecciones_cutaneas,
            alergias,
            tatuajes,
            cirugia_plastica,
            antecedentes_medicos,
            ubicacion_lesiones,
            tipo_piel,
            cicatrizacion,
            diagnostico_visual,
            diagnostico_tactil,
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_excel_with_corporal_sessions() {
        let files = [
            "/home/juanchito/Descargas/PACIENTES A-B-C-D.xlsx",
            "/home/juanchito/Descargas/PACIENTES E-F-G-H.xlsx",
            "/home/juanchito/Descargas/PACIENTES O-P-Q .xlsx",
            "/home/juanchito/Descargas/PACIENTES U-V-W-Y-Z.xlsx",
        ];

        let mut total_patients = 0;
        let mut total_facial = 0;
        let mut total_corporal = 0;

        for path in files {
            if !std::path::Path::new(path).exists() {
                println!("File not found: {}", path);
                continue;
            }

            let patients = parse_excel(path.to_string()).expect("Should parse excel");
            println!("\nFile: {}", path);
            println!("  Parsed {} patients", patients.len());

            for p in &patients {
                let facial = p.sesiones.iter().filter(|s| s.tipo == "facial").count();
                let corp = p.sesiones.iter().filter(|s| s.tipo == "corporal").count();
                total_facial += facial;
                total_corporal += corp;
                if corp > 0 {
                    println!("  Patient {} {}: {} facial, {} corporal", p.nombre, p.apellido, facial, corp);
                }
            }
            total_patients += patients.len();
        }

        println!("\nTOTAL: {} patients, {} facial sessions, {} corporal sessions", total_patients, total_facial, total_corporal);
        assert!(total_corporal > 0, "Should have parsed corporal sessions");
    }

    #[test]
    fn test_parse_clinical_data() {
        let path = "/home/juanchito/Descargas/PACIENTES A-B-C-D.xlsx";
        if !std::path::Path::new(path).exists() {
            return;
        }

        let patients = parse_excel(path.to_string()).expect("Should parse excel");
        let susana = patients.iter().find(|p| p.nombre.to_uppercase().contains("SUSANA")).expect("Susana should exist");

        println!("Susana clinical data:");
        println!("  condiciones_medicas: {:?}", susana.condiciones_medicas);
        println!("  afecciones_cutaneas: {:?}", susana.afecciones_cutaneas);
        println!("  ubicacion_lesiones: {:?}", susana.ubicacion_lesiones);
        println!("  tipo_piel: {:?}", susana.tipo_piel);
        println!("  cicatrizacion: {:?}", susana.cicatrizacion);
        println!("  diagnostico_visual: {:?}", susana.diagnostico_visual);
        println!("  diagnostico_tactil: {:?}", susana.diagnostico_tactil);
        println!("  tatuajes: {:?}", susana.tatuajes);
        println!("  cirugia_plastica: {:?}", susana.cirugia_plastica);
        println!("  antecedentes_medicos: {:?}", susana.antecedentes_medicos);

        assert!(susana.condiciones_medicas.as_ref().unwrap().contains("HIPERTENSION"));
        assert!(susana.afecciones_cutaneas.as_ref().unwrap().contains("ACNÉ") || susana.afecciones_cutaneas.as_ref().unwrap().contains("ACNE"));
        assert!(susana.tipo_piel.as_ref().unwrap().contains("GRASA"));
        assert_eq!(susana.cicatrizacion.as_deref(), Some("NORMAL"));
        assert_eq!(susana.tatuajes.as_deref(), Some("No"));
        assert_eq!(susana.cirugia_plastica.as_deref(), Some("No"));
        assert!(susana.antecedentes_medicos.as_ref().unwrap().contains("HISTERECTOMIA"));
    }
}
