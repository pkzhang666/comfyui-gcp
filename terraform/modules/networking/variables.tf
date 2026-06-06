variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network_config" {
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
}

variable "service_toggles" {
  description = "Enable or disable firewall access for VM services"
  type = object({
    comfyui    = bool
    llama      = bool
    open_webui = bool
  })
}

variable "labels" {
  type = map(string)
}
