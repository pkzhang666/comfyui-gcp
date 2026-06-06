output "models_bucket_name" {
  value = google_storage_bucket.models.name
}

output "models_bucket_url" {
  value = google_storage_bucket.models.url
}

output "outputs_bucket_name" {
  value = google_storage_bucket.outputs.name
}

output "outputs_bucket_url" {
  value = google_storage_bucket.outputs.url
}
