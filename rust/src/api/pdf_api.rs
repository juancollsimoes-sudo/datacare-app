use crate::pdf::{
    generate_accounting_report, generate_accounting_report_bytes, generate_expenses_excel,
    generate_expenses_excel_bytes, generate_patient_report, generate_patient_report_bytes,
};
use crate::db::error::AppError;

pub fn api_generate_patient_report(paciente_id: i64, output_path: String) -> Result<String, AppError> {
    generate_patient_report(paciente_id, output_path)
}

pub fn api_generate_patient_report_bytes(paciente_id: i64) -> Result<Vec<u8>, AppError> {
    generate_patient_report_bytes(paciente_id)
}

pub fn api_generate_accounting_report(year: i32, month: i32, output_path: String) -> Result<String, AppError> {
    generate_accounting_report(year, month, output_path)
}

pub fn api_generate_accounting_report_bytes(year: i32, month: i32) -> Result<Vec<u8>, AppError> {
    generate_accounting_report_bytes(year, month)
}

pub fn api_generate_expenses_excel(year: i32, month: i32, output_path: String) -> Result<String, AppError> {
    generate_expenses_excel(year, month, output_path)
}

pub fn api_generate_expenses_excel_bytes(year: i32, month: i32) -> Result<Vec<u8>, AppError> {
    generate_expenses_excel_bytes(year, month)
}


