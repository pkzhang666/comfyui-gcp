variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for VM deployment (must support GPU type)"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "labels" {
  description = "Common resource labels applied to all resources"
  type        = map(string)
  default = {
    application = "gcp-ai-studio"
    managed-by  = "terraform"
  }
}

variable "network_config" {
  description = "VPC and networking configuration"
  type = object({
    vpc = object({
      name         = string
      routing_mode = string
    })
    subnet = object({
      cidr                  = string
      flow_logs_enabled     = bool
      private_google_access = bool
    })
    router = object({
      asn = number
    })
    nat = object({
      ip_allocation = string
      log_enabled   = bool
    })
    firewall = object({
      iap_ranges = list(string)
    })
  })
  default = {
    vpc = {
      name         = "comfyui-vpc"
      routing_mode = "REGIONAL"
    }
    subnet = {
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
}

variable "compute_config" {
  description = "Compute Engine VM configuration for ComfyUI"
  type = object({
    name         = string
    machine_type = string
    gpu = object({
      type  = string
      count = number
    })
    boot_disk = object({
      image_family  = string
      image_project = string
      size_gb       = number
      type          = string
    })
    data_disk = object({
      size_gb = number
      type    = string
    })
    enable_deletion_protection = bool
    preemptible                = bool
  })
  default = {
    name         = "comfyui-vm"
    machine_type = "g2-standard-8"
    gpu = {
      type  = "nvidia-l4"
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
}

variable "storage_config" {
  description = "GCS bucket configuration for models and workflow outputs"
  type = object({
    models_bucket = object({
      name          = string
      location      = string
      storage_class = string
    })
    outputs_bucket = object({
      name          = string
      location      = string
      storage_class = string
    })
  })
  default = {
    models_bucket = {
      name          = "comfyui-models"
      location      = "US"
      storage_class = "STANDARD"
    }
    outputs_bucket = {
      name          = "comfyui-outputs"
      location      = "US"
      storage_class = "STANDARD"
    }
  }
}

variable "comfyui_config" {
  description = "ComfyUI application runtime configuration"
  type = object({
    port           = number
    listen_address = string
    extra_args     = string
  })
  default = {
    port           = 8188
    listen_address = "0.0.0.0"
    extra_args     = ""
  }
}

variable "service_toggles" {
  description = "Enable or disable ComfyUI, llama.cpp, and Open WebUI services"
  type = object({
    comfyui    = bool
    llama      = bool
    open_webui = bool
  })
  default = {
    comfyui    = true
    llama      = true
    open_webui = true
  }
  validation {
    condition     = var.service_toggles.open_webui ? var.service_toggles.llama : true
    error_message = "service_toggles.open_webui requires service_toggles.llama to be true."
  }
}

variable "llm_config" {
  description = "llama.cpp server configuration for Qwen3.6-35B-A3B"
  type = object({
    port         = number
    model_quant  = string
    context_size = number
    webui_port   = number
  })
  default = {
    port         = 8080
    model_quant  = "Q6_K_P"
    context_size = 32768
    webui_port   = 3000
  }
}
