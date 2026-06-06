resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.network_config.vpc.name
  auto_create_subnetworks = false
  routing_mode            = var.network_config.vpc.routing_mode
}

resource "google_compute_subnetwork" "subnet" {
  project                  = var.project_id
  name                     = "${var.network_config.vpc.name}-subnet"
  network                  = google_compute_network.vpc.self_link
  region                   = var.region
  ip_cidr_range            = var.network_config.subnet.cidr
  private_ip_google_access = var.network_config.subnet.private_google_access

  dynamic "log_config" {
    for_each = var.network_config.subnet.flow_logs_enabled ? [1] : []
    content {
      aggregation_interval = "INTERVAL_10_MIN"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.network_config.vpc.name}-router"
  region  = var.region
  network = google_compute_network.vpc.self_link

  bgp {
    asn = var.network_config.router.asn
  }
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "${var.network_config.vpc.name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = var.network_config.nat.ip_allocation
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = var.network_config.nat.log_enabled
    filter = "ERRORS_ONLY"
  }
}

# Allow SSH via IAP TCP forwarding (no public IP needed)
resource "google_compute_firewall" "allow_iap_ssh" {
  project  = var.project_id
  name     = "${var.network_config.vpc.name}-allow-iap-ssh"
  network  = google_compute_network.vpc.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.network_config.firewall.iap_ranges
  target_tags   = ["comfyui"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow ComfyUI (8188), llama-server (8080) and Open WebUI (3000) via IAP TCP tunnel
resource "google_compute_firewall" "allow_iap_comfyui" {
  project  = var.project_id
  name     = "${var.network_config.vpc.name}-allow-iap-comfyui"
  network  = google_compute_network.vpc.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["3000", "8080", "8188"]
  }

  source_ranges = var.network_config.firewall.iap_ranges
  target_tags   = ["comfyui"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow internal subnet traffic
resource "google_compute_firewall" "allow_internal" {
  project  = var.project_id
  name     = "${var.network_config.vpc.name}-allow-internal"
  network  = google_compute_network.vpc.name
  priority = 1000

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.network_config.subnet.cidr]
}
