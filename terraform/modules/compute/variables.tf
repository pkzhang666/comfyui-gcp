variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "network" {
  type        = string
  description = "VPC network self_link"
}

variable "subnetwork" {
  type        = string
  description = "Subnet self_link"
}

variable "compute_config" {
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
}

variable "comfyui_config" {
  type = object({
    port           = number
    listen_address = string
    extra_args     = string
  })
}

variable "service_toggles" {
  description = "Enable or disable VM services"
  type = object({
    comfyui    = bool
    llama      = bool
    open_webui = bool
  })
}

variable "service_account" {
  type        = string
  description = "Service account email to attach to the VM"
}

variable "models_bucket" {
  type        = string
  description = "GCS bucket name for models (passed to startup script)"
}

variable "outputs_bucket" {
  type        = string
  description = "GCS bucket name for outputs (passed to startup script)"
}

variable "llm_config" {
  description = "llama.cpp server configuration"
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

variable "labels" {
  type = map(string)
}
