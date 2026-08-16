use axum::{
    extract::{Multipart, Path, Query},
    routing::{delete, get, post, put},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use tower_http::cors::{Any, CorsLayer};
use std::net::SocketAddr;

use crate::api::db_api;
use crate::api::photos_api;
use crate::db::models::*;

#[derive(Deserialize)]
pub struct PaginationQuery {
    page: Option<i32>,
    page_size: Option<i32>,
    search: Option<String>,
}

pub async fn start_server(port: u16) {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let api_routes = Router::new()
        .route("/pacientes", get(list_pacientes).post(create_paciente))
        .route("/pacientes/:id", get(get_paciente).put(update_paciente).delete(deactivate_paciente))
        .route("/tratamientos", get(list_tratamientos).post(create_tratamiento))
        .route("/tratamientos/:id", get(get_tratamiento).put(update_tratamiento).delete(delete_tratamiento))
        .route("/sesiones", post(create_sesion))
        .route("/sesiones/:id", get(get_sesion).put(update_sesion))
        .route("/pacientes/:id/sesiones", get(list_sesiones))
        .route("/sesiones/:id/fotos", get(list_fotos_sesion))
        .route("/pacientes/:id/fotos", get(list_fotos_paciente))
        .route("/fotos", post(upload_photo))
        .route("/fotos/:id", delete(delete_photo))
        .route("/stats", get(get_stats));

    let app = Router::new()
        .nest("/api", api_routes)
        .fallback_service(tower_http::services::ServeDir::new("build/web"))
        .layer(cors);

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    println!("Server running on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
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
