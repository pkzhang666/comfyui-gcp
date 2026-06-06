output "vm_name" {
  description = "ComfyUI VM instance name"
  value       = module.compute.vm_name
}

output "vm_zone" {
  description = "Zone where the ComfyUI VM is deployed"
  value       = var.zone
}

output "network_name" {
  description = "VPC network name"
  value       = module.networking.network_name
}

output "subnetwork_name" {
  description = "Subnet name"
  value       = module.networking.subnetwork_name
}

output "models_bucket" {
  description = "GCS bucket name for storing ComfyUI models"
  value       = module.storage.models_bucket_name
}

output "outputs_bucket" {
  description = "GCS bucket name for storing workflow outputs"
  value       = module.storage.outputs_bucket_name
}

output "service_account_email" {
  description = "Service account attached to the ComfyUI VM"
  value       = module.iam.comfyui_service_account_email
}

output "iap_tunnel_command" {
  description = "Run this on your local machine to access ComfyUI via IAP TCP tunnel"
  value       = "gcloud compute start-iap-tunnel ${module.compute.vm_name} 8188 --local-host-port=localhost:8188 --zone=${var.zone} --project=${var.project_id}"
}

output "ssh_command" {
  description = "SSH into the VM via IAP (no public IP required)"
  value       = "gcloud compute ssh ${module.compute.vm_name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap"
}

output "next_steps" {
  description = "Post-deployment instructions"
  value       = <<-EOF
    ============================================================
    ComfyUI VM deployed successfully!
    ============================================================

    1. SSH into the VM:
       gcloud compute ssh ${module.compute.vm_name} --zone=${var.zone} --project=${var.project_id} --tunnel-through-iap

    2. Check ComfyUI startup progress (takes ~5-10 min on first boot):
       sudo journalctl -u comfyui -f

    3. Access ComfyUI UI from your local machine:
       gcloud compute start-iap-tunnel ${module.compute.vm_name} 8188 --local-host-port=localhost:8188 --zone=${var.zone} --project=${var.project_id}
       Then open: http://localhost:8188

    4. Upload models (image-to-video checkpoints):
       gsutil -m cp -r ./models/ gs://${module.storage.models_bucket_name}/checkpoints/

    5. Stop VM to save costs when not in use:
       make stop

    ============================================================
  EOF
}
