output "comfyui_service_account_email" {
  value = google_service_account.comfyui_sa.email
}

output "comfyui_service_account_id" {
  value = google_service_account.comfyui_sa.id
}
