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

variable "labels" {
  type = map(string)
}
