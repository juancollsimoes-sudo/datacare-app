use axum::{
    extract::{Multipart, Path, Query},
    routing::{delete, get, post},
    Json, Router,
};
use serde::Deserialize;
use tower_http::cors::{Any, CorsLayer};
use std::net::SocketAddr;

use crate::api::db_api;
use crate::api::pdf_api;
use crate::api::photos_api;
use crate::db::models::*;

#[derive(Deserialize)]
pub struct PaginationQuery {
    page: Option<i32>,
    page_size: Option<i32>,
    search: Option<String>,
}

#[derive(Deserialize)]
pub struct AccountingReportQuery {
    year: i32,
    month: i32,
}

pub fn build_router() -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let api_routes = Router::new()
        .route("/pacientes", get(list_pacientes).post(create_paciente))
        .route("/pacientes/{id}", get(get_paciente).put(update_paciente).delete(deactivate_paciente))
        .route("/pacientes/{id}/deactivate", post(deactivate_paciente))
        .route("/tratamientos", get(list_tratamientos).post(create_tratamiento))
        .route("/tratamientos/{id}", get(get_tratamiento).put(update_tratamiento).delete(delete_tratamiento))
        .route("/sesiones", post(create_sesion))
        .route("/sesiones/{id}", get(get_sesion).put(update_sesion))
        .route("/pacientes/{id}/sesiones", get(list_sesiones))
        .route("/pacientes/{id}/corporal", get(get_sesiones_corporales))
        .route("/sesiones/{id}/fotos", get(list_fotos_sesion))
        .route("/pacientes/{id}/fotos", get(list_fotos_paciente))
        .route("/fotos", post(upload_photo))
        .route("/fotos/{id}", delete(delete_photo))
        .route("/gastos", get(list_gastos).post(create_gasto))
        .route("/gastos/{id}", axum::routing::put(update_gasto).delete(delete_gasto))
        .route("/ingresos", get(list_ingresos))
        .route("/reportes/contabilidad", get(download_accounting_report))
        .route("/reportes/paciente/{id}", get(download_patient_report))
        .route("/stats", get(get_stats));

    let photos_dir = crate::db::DatabaseManager::get_base_dir().join("photos");
    let web_dir = if std::path::Path::new("build/web").exists() {
        std::path::PathBuf::from("build/web")
    } else {
        std::path::PathBuf::from("../build/web")
    };
    let index_file = web_dir.join("index.html");

    Router::new()
        .nest("/api", api_routes)
        .nest_service("/photos", tower_http::services::ServeDir::new(photos_dir))
        .fallback_service(
            tower_http::services::ServeDir::new(&web_dir)
                .fallback(tower_http::services::ServeFile::new(index_file)),
        )
        .layer(cors)
}

pub async fn start_server(port: u16) {
    let app = build_router();
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    println!("Server running on http://{}", addr);

    let listener = match tokio::net::TcpListener::bind(addr).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Failed to bind server on {}: {}", addr, e);
            return;
        }
    };
    if let Err(e) = axum::serve(listener, app).await {
        eprintln!("Server error: {}", e);
    }
}

async fn list_pacientes(Query(q): Query<PaginationQuery>) -> Result<Json<PaginatedPacientes>, (axum::http::StatusCode, String)> {
    let page = q.page.unwrap_or(1);
    let page_size = q.page_size.unwrap_or(20);
    match db_api::list_pacientes(q.search, page, page_size) {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn create_paciente(Json(payload): Json<NuevoPaciente>) -> Result<Json<i64>, (axum::http::StatusCode, String)> {
    match db_api::create_paciente(payload) {
        Ok(id) => Ok(Json(id)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn get_paciente(Path(id): Path<i64>) -> Result<Json<Paciente>, (axum::http::StatusCode, String)> {
    match db_api::get_paciente(id) {
        Ok(Some(p)) => Ok(Json(p)),
        Ok(None) => Err((axum::http::StatusCode::NOT_FOUND, "Not found".to_string())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn update_paciente(Path(id): Path<i64>, Json(mut payload): Json<ActualizarPaciente>) -> Result<Json<()>, (axum::http::StatusCode, String)> {
    payload.id = id;
    match db_api::update_paciente(payload) {
        Ok(_) => Ok(Json(())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn deactivate_paciente(Path(id): Path<i64>) -> Result<Json<()>, (axum::http::StatusCode, String)> {
    match db_api::deactivate_paciente(id) {
        Ok(_) => Ok(Json(())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn list_tratamientos() -> Result<Json<Vec<Tratamiento>>, (axum::http::StatusCode, String)> {
    match db_api::list_tratamientos() {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn create_tratamiento(Json(payload): Json<NuevoTratamiento>) -> Result<Json<i64>, (axum::http::StatusCode, String)> {
    match db_api::create_tratamiento(payload) {
        Ok(id) => Ok(Json(id)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn get_tratamiento(Path(id): Path<i64>) -> Result<Json<Tratamiento>, (axum::http::StatusCode, String)> {
    match db_api::get_tratamiento(id) {
        Ok(Some(t)) => Ok(Json(t)),
        Ok(None) => Err((axum::http::StatusCode::NOT_FOUND, "Not found".to_string())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn update_tratamiento(Path(id): Path<i64>, Json(mut payload): Json<ActualizarTratamiento>) -> Result<Json<()>, (axum::http::StatusCode, String)> {
    payload.id = id;
    match db_api::update_tratamiento(payload) {
        Ok(_) => Ok(Json(())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn delete_tratamiento(Path(id): Path<i64>) -> Result<Json<()>, (axum::http::StatusCode, String)> {
    match db_api::delete_tratamiento(id) {
        Ok(_) => Ok(Json(())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn create_sesion(Json(payload): Json<NuevaSesion>) -> Result<Json<i64>, (axum::http::StatusCode, String)> {
    match db_api::create_sesion(payload) {
        Ok(id) => Ok(Json(id)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn list_sesiones(Path(paciente_id): Path<i64>, Query(q): Query<PaginationQuery>) -> Result<Json<PaginatedSesiones>, (axum::http::StatusCode, String)> {
    let page = q.page.unwrap_or(1);
    let page_size = q.page_size.unwrap_or(20);
    match db_api::list_sesiones_by_paciente(paciente_id, page, page_size) {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn get_sesiones_corporales(Path(paciente_id): Path<i64>) -> Result<Json<Vec<Sesion>>, (axum::http::StatusCode, String)> {
    match db_api::get_sesiones_corporales(paciente_id) {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn get_sesion(Path(id): Path<i64>) -> Result<Json<Sesion>, (axum::http::StatusCode, String)> {
    match db_api::get_sesion(id) {
        Ok(Some(s)) => Ok(Json(s)),
        Ok(None) => Err((axum::http::StatusCode::NOT_FOUND, "Not found".to_string())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn update_sesion(Path(id): Path<i64>, Json(mut payload): Json<ActualizarSesion>) -> Result<Json<()>, (axum::http::StatusCode, String)> {
    payload.id = id;
    match db_api::update_sesion(payload) {
        Ok(_) => Ok(Json(())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn get_stats() -> Result<Json<DashboardStats>, (axum::http::StatusCode, String)> {
    match db_api::get_dashboard_stats() {
        Ok(stats) => Ok(Json(stats)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn list_fotos_sesion(Path(sesion_id): Path<i64>) -> Result<Json<Vec<FotoSesion>>, (axum::http::StatusCode, String)> {
    match photos_api::list_photos_by_session(sesion_id) {
        Ok(fotos) => Ok(Json(fotos)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn list_fotos_paciente(Path(paciente_id): Path<i64>) -> Result<Json<Vec<FotoSesion>>, (axum::http::StatusCode, String)> {
    match photos_api::list_photos_by_patient(paciente_id) {
        Ok(fotos) => Ok(Json(fotos)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn delete_photo(Path(id): Path<i64>) -> Result<Json<()>, (axum::http::StatusCode, String)> {
    match photos_api::delete_photo(id) {
        Ok(_) => Ok(Json(())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn upload_photo(mut multipart: Multipart) -> Result<Json<FotoSesion>, (axum::http::StatusCode, String)> {
    let mut paciente_id: Option<i64> = None;
    let mut sesion_id: Option<i64> = None;
    let mut tipo: Option<String> = None;
    let mut descripcion: Option<String> = None;
    let mut temp_file_path: Option<String> = None;
    
    while let Some(field) = multipart.next_field().await.map_err(|e| (axum::http::StatusCode::BAD_REQUEST, e.to_string()))? {
        let name = field.name().unwrap_or("").to_string();
        if name == "paciente_id" {
            let text = field.text().await.unwrap_or_default();
            paciente_id = text.parse().ok();
        } else if name == "sesion_id" {
            let text = field.text().await.unwrap_or_default();
            sesion_id = text.parse().ok();
        } else if name == "tipo" {
            tipo = Some(field.text().await.unwrap_or_default());
        } else if name == "descripcion" {
            descripcion = Some(field.text().await.unwrap_or_default());
        } else if name == "file" || name == "photo" || name == "image" {
            let data = field.bytes().await.map_err(|e| (axum::http::StatusCode::BAD_REQUEST, e.to_string()))?;
            let temp_dir = std::env::temp_dir();
            let file_path = temp_dir.join(format!("upload_{}.jpg", uuid::Uuid::new_v4()));
            std::fs::write(&file_path, &data).map_err(|e| (axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
            temp_file_path = Some(file_path.to_str().unwrap().to_string());
        }
    }
    
    if let (Some(pid), Some(sid), Some(path)) = (paciente_id, sesion_id, temp_file_path.clone()) {
        match photos_api::save_session_photo(pid, sid, path.clone(), tipo, descripcion) {
            Ok(foto) => {
                let _ = std::fs::remove_file(path);
                Ok(Json(foto))
            },
            Err(e) => {
                let _ = std::fs::remove_file(path);
                Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e))
            }
        }
    } else {
        if let Some(path) = temp_file_path {
            let _ = std::fs::remove_file(path);
        }
        Err((axum::http::StatusCode::BAD_REQUEST, "Missing required fields".to_string()))
    }
}

async fn list_gastos() -> Result<Json<Vec<Gasto>>, (axum::http::StatusCode, String)> {
    match db_api::list_gastos() {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn create_gasto(Json(payload): Json<NuevoGasto>) -> Result<Json<i64>, (axum::http::StatusCode, String)> {
    match db_api::create_gasto(payload) {
        Ok(id) => Ok(Json(id)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn update_gasto(Path(id): Path<i64>, Json(mut payload): Json<Gasto>) -> Result<Json<()>, (axum::http::StatusCode, String)> {
    payload.id = id;
    match db_api::update_gasto(payload) {
        Ok(_) => Ok(Json(())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn delete_gasto(Path(id): Path<i64>) -> Result<Json<()>, (axum::http::StatusCode, String)> {
    match db_api::delete_gasto(id) {
        Ok(_) => Ok(Json(())),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn list_ingresos() -> Result<Json<Vec<Sesion>>, (axum::http::StatusCode, String)> {
    match db_api::list_ingresos() {
        Ok(res) => Ok(Json(res)),
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn download_accounting_report(
    Query(q): Query<AccountingReportQuery>,
) -> Result<
    (
        [(axum::http::header::HeaderName, String); 2],
        Vec<u8>,
    ),
    (axum::http::StatusCode, String),
> {
    match pdf_api::api_generate_accounting_report_bytes(q.year, q.month) {
        Ok(bytes) => {
            let filename = format!("cierre_contable_{:04}_{:02}.pdf", q.year, q.month);
            Ok((
                [
                    (axum::http::header::CONTENT_TYPE, "application/pdf".to_string()),
                    (
                        axum::http::header::CONTENT_DISPOSITION,
                        format!("attachment; filename=\"{}\"", filename),
                    ),
                ],
                bytes,
            ))
        }
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string_err())),
    }
}

async fn download_patient_report(
    Path(id): Path<i64>,
) -> Result<
    (
        [(axum::http::header::HeaderName, String); 2],
        Vec<u8>,
    ),
    (axum::http::StatusCode, String),
> {
    match pdf_api::api_generate_patient_report_bytes(id) {
        Ok(bytes) => {
            let filename = format!("reporte_paciente_{}.pdf", id);
            Ok((
                [
                    (axum::http::header::CONTENT_TYPE, "application/pdf".to_string()),
                    (
                        axum::http::header::CONTENT_DISPOSITION,
                        format!("attachment; filename=\"{}\"", filename),
                    ),
                ],
                bytes,
            ))
        }
        Err(e) => Err((axum::http::StatusCode::INTERNAL_SERVER_ERROR, e.to_string_err())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Datelike;

    #[tokio::test]
    async fn test_axum_accounting_and_pdf_endpoints() {
        let tmp_db = std::env::temp_dir().join(format!("datacare_test_{}.db", uuid::Uuid::new_v4()));
        db_api::init_database(tmp_db.to_string_lossy().to_string()).expect("init test db");

        let now = chrono::Local::now();
        let current_ym = format!("{:04}-{:02}", now.year(), now.month());

        let p1 = db_api::create_paciente(NuevoPaciente {
            nombre: "María".to_string(),
            apellido: "González".to_string(),
            fecha_nacimiento: None,
            telefono: Some("0414-1234567".to_string()),
            email: Some("maria@example.com".to_string()),
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
        })
        .expect("create patient 1");

        let p2 = db_api::create_paciente(NuevoPaciente {
            nombre: "Carlos".to_string(),
            apellido: "Rodríguez".to_string(),
            fecha_nacimiento: None,
            telefono: Some("0412-9876543".to_string()),
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
        })
        .expect("create patient 2");

        db_api::create_sesion(NuevaSesion {
            paciente_id: p1,
            tratamiento_id: None,
            fecha: format!("{}-05", current_ym),
            notas_sesion: Some("Limpieza Facial Profunda".to_string()),
            observaciones: None,
            productos_usados: None,
            precio_cobrado: Some(180.0),
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
        })
        .expect("create session 1");

        db_api::create_sesion(NuevaSesion {
            paciente_id: p2,
            tratamiento_id: None,
            fecha: format!("{}-10", current_ym),
            notas_sesion: Some("Masaje Reductor".to_string()),
            observaciones: None,
            productos_usados: None,
            precio_cobrado: Some(120.0),
            pagado: true,
            tipo: Some("corporal".to_string()),
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
        })
        .expect("create session 2");

        db_api::create_gasto(NuevoGasto {
            nombre: "Insumos estéticos".to_string(),
            descripcion: Some("Cremas y sueros".to_string()),
            categoria: Some("operativo".to_string()),
            monto: 50.0,
            fecha: format!("{}-06", current_ym),
        })
        .expect("create operativo gasto");

        db_api::create_gasto(NuevoGasto {
            nombre: "Almuerzo personal".to_string(),
            descripcion: Some("Gasto personal".to_string()),
            categoria: Some("personal".to_string()),
            monto: 25.0,
            fecha: format!("{}-08", current_ym),
        })
        .expect("create personal gasto 1");

        db_api::create_gasto(NuevoGasto {
            nombre: "Transporte personal".to_string(),
            descripcion: Some("Taxi personal".to_string()),
            categoria: Some("personal".to_string()),
            monto: 15.0,
            fecha: format!("{}-12", current_ym),
        })
        .expect("create personal gasto 2");

        let ingresos = db_api::list_ingresos().expect("list ingresos");
        assert_eq!(ingresos.len(), 2);
        assert!(ingresos
            .iter()
            .any(|s| s.paciente_nombre.as_deref() == Some("María González")));
        assert!(ingresos
            .iter()
            .any(|s| s.paciente_nombre.as_deref() == Some("Carlos Rodríguez")));

        let gastos = db_api::list_gastos().expect("list gastos");
        assert_eq!(gastos.len(), 3);

        let pdf_bytes = pdf_api::api_generate_accounting_report_bytes(now.year(), now.month() as i32)
            .expect("generate pdf bytes");
        assert!(pdf_bytes.starts_with(b"%PDF-"));

        if std::env::var("DATACARE_RUN_TEST_SERVER").is_ok() {
            let port: u16 = std::env::var("DATACARE_TEST_PORT")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(8080);
            start_server(port).await;
        }

        let _ = std::fs::remove_file(&tmp_db);
    }
}



