use crate::pdf::generate_patient_report;
use crate::db::error::AppError;

pub fn api_generate_patient_report(paciente_id: i64, output_path: String) -> Result<String, AppError> {
    generate_patient_report(paciente_id, output_path)
}
