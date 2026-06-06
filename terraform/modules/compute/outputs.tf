output "vm_name" {
  value = google_compute_instance.comfyui.name
}

output "vm_self_link" {
  value = google_compute_instance.comfyui.self_link
}

output "vm_instance_id" {
  value = google_compute_instance.comfyui.instance_id
}

output "data_disk_name" {
  value = google_compute_disk.data.name
}
