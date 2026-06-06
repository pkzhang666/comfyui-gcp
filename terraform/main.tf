resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "oslogin.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

locals {
  common_labels = merge(var.labels, {
    environment = var.environment
  })
}

module "networking" {
  source = "./modules/networking"

  project_id     = var.project_id
  region         = var.region
  network_config = var.network_config
  service_toggles = var.service_toggles
  labels         = local.common_labels

  depends_on = [google_project_service.apis]
}

module "iam" {
  source = "./modules/iam"

  project_id = var.project_id
  labels     = local.common_labels

  depends_on = [google_project_service.apis]
}

module "storage" {
  source = "./modules/storage"

  project_id      = var.project_id
  storage_config  = var.storage_config
  service_account = module.iam.comfyui_service_account_email
  labels          = local.common_labels

  depends_on = [module.iam]
}

module "compute" {
  source = "./modules/compute"

  project_id      = var.project_id
  region          = var.region
  zone            = var.zone
  network         = module.networking.network_self_link
  subnetwork      = module.networking.subnetwork_self_link
  compute_config  = var.compute_config
  comfyui_config  = var.comfyui_config
  llm_config      = var.llm_config
  service_toggles = var.service_toggles
  service_account = module.iam.comfyui_service_account_email
  models_bucket   = module.storage.models_bucket_name
  outputs_bucket  = module.storage.outputs_bucket_name
  labels          = local.common_labels

  depends_on = [module.networking, module.iam, module.storage]
}
