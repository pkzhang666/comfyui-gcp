locals {
  startup_script = templatefile("${path.module}/startup-script.sh.tpl", {
    comfyui_port     = var.comfyui_config.port
    comfyui_listen   = var.comfyui_config.listen_address
    comfyui_args     = var.comfyui_config.extra_args
    models_bucket    = var.models_bucket
    outputs_bucket   = var.outputs_bucket
    llama_port       = var.llm_config.port
    llm_model_quant  = var.llm_config.model_quant
    llm_context_size = var.llm_config.context_size
  })
}

# Persistent disk for model storage (separate from boot disk)
resource "google_compute_disk" "data" {
  project = var.project_id
  name    = "${var.compute_config.name}-data"
  type    = var.compute_config.data_disk.type
  zone    = var.zone
  size    = var.compute_config.data_disk.size_gb
  labels  = var.labels
}

data "google_compute_image" "vm_image" {
  family  = var.compute_config.boot_disk.image_family
  project = var.compute_config.boot_disk.image_project
}

resource "google_compute_instance" "comfyui" {
  project      = var.project_id
  name         = var.compute_config.name
  machine_type = var.compute_config.machine_type
  zone         = var.zone
  labels       = var.labels
  tags         = ["comfyui"]

  deletion_protection = var.compute_config.enable_deletion_protection

  # Required for GPU instances: must terminate on host maintenance
  # Set preemptible = true in compute_config to save ~70% on VM cost
  # (VM may be reclaimed by GCP with 30s notice — fine for testing)
  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = var.compute_config.preemptible ? false : true
    preemptible         = var.compute_config.preemptible
    provisioning_model  = var.compute_config.preemptible ? "SPOT" : "STANDARD"
  }

  guest_accelerator {
    type  = var.compute_config.gpu.type
    count = var.compute_config.gpu.count
  }

  boot_disk {
    initialize_params {
      image  = data.google_compute_image.vm_image.self_link
      size   = var.compute_config.boot_disk.size_gb
      type   = var.compute_config.boot_disk.type
      labels = var.labels
    }
  }

  attached_disk {
    source      = google_compute_disk.data.self_link
    device_name = "models-disk"
    mode        = "READ_WRITE"
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
    # No access_config block = no external IP; access via IAP only
  }

  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script        = local.startup_script
    install-nvidia-driver = "True"
    enable-oslogin        = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  allow_stopping_for_update = true

  # Ignore image family resolving to a newer image version on each plan —
  # prevents Terraform from destroying and recreating the VM just because
  # the Deep Learning base image received a patch update.
  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}
