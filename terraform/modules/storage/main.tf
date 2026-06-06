resource "google_storage_bucket" "models" {
  project       = var.project_id
  name          = var.storage_config.models_bucket.name
  location      = var.storage_config.models_bucket.location
  storage_class = var.storage_config.models_bucket.storage_class
  labels        = var.labels

  force_destroy                = true
  public_access_prevention     = "enforced"
  uniform_bucket_level_access  = true

  versioning {
    enabled = false
  }

  # Move unused models to Nearline after 1 year to reduce cost
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }
}

resource "google_storage_bucket" "outputs" {
  project       = var.project_id
  name          = var.storage_config.outputs_bucket.name
  location      = var.storage_config.outputs_bucket.location
  storage_class = var.storage_config.outputs_bucket.storage_class
  labels        = var.labels

  force_destroy                = true
  public_access_prevention     = "enforced"
  uniform_bucket_level_access  = true

  # Auto-delete generated videos/images after 30 days
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "models_access" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account}"
}

resource "google_storage_bucket_iam_member" "outputs_access" {
  bucket = google_storage_bucket.outputs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.service_account}"
}
