variable "project_id" {
  type = string
}

variable "storage_config" {
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
}

variable "service_account" {
  type        = string
  description = "Service account email granted access to the buckets"
}

variable "labels" {
  type = map(string)
}
