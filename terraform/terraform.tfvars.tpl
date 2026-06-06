project_id  = "${PROJECT_ID}"
region      = "${REGION}"
zone        = "${ZONE}"
environment = "dev"

labels = {
  application = "comfyui-workflow"
  environment = "dev"
  managed-by  = "terraform"
  team        = "cloudwerx"
}

network_config = {
  vpc = {
    name         = "comfyui-vpc"
    routing_mode = "REGIONAL"
  }
  subnet = {
    # Use 10.1.0.0/24 — separate from collections-automation (10.0.0.0/24)
    cidr                  = "10.1.0.0/24"
    flow_logs_enabled     = true
    private_google_access = true
  }
  router = {
    asn = 64515
  }
  nat = {
    ip_allocation = "AUTO_ONLY"
    log_enabled   = true
  }
  firewall = {
    iap_ranges = ["35.235.240.0/20"]
  }
}

compute_config = {
  name         = "${VM_NAME}"
  machine_type = "a2-highgpu-1g"
  gpu = {
    type  = "nvidia-tesla-a100"
    count = 1
  }
  boot_disk = {
    image_family  = "pytorch-2-9-cu129-ubuntu-2204-nvidia-580"
    image_project = "deeplearning-platform-release"
    size_gb       = 100
    type          = "pd-balanced"
  }
  data_disk = {
    size_gb = 200
    type    = "pd-balanced"
  }
  enable_deletion_protection = false
  preemptible                = false
}

storage_config = {
  models_bucket = {
    name          = "${MODELS_BUCKET}"
    location      = "US"
    storage_class = "STANDARD"
  }
  outputs_bucket = {
    name          = "${OUTPUTS_BUCKET}"
    location      = "US"
    storage_class = "STANDARD"
  }
}

comfyui_config = {
  port           = 8188
  listen_address = "0.0.0.0"
  extra_args     = ""
}
