resource "google_service_account" "comfyui_sa" {
  project      = var.project_id
  account_id   = "comfyui-vm-sa"
  display_name = "ComfyUI VM Service Account"
  description  = "Attached to the ComfyUI GPU VM — grants GCS, logging, and monitoring access"
}

resource "google_project_iam_member" "storage_object_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.comfyui_sa.email}"
}

resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.comfyui_sa.email}"
}

resource "google_project_iam_member" "monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.comfyui_sa.email}"
}
