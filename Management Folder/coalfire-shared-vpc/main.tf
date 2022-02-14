provider "google" {
  credentials = file("~/coalfire-terrafom-key2.json")
  project = var.project
  region  = var.region
  zone    = var.zone
}


# Main VPC
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "demo-vpc" {
  name                    = "coalfire-demo-vpc"
  auto_create_subnetworks = false
}

# Public Subnet
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "public1" {
  name          = "coalfire-public-subnet1"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.demo-vpc.name
}

resource "google_compute_subnetwork" "public2" {
  name          = "coalfire-public-subnet2"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.demo-vpc.name
}

# Private Subnet
# # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "private1" {
  name          = "coalfire-private-subnet1"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  private_ip_google_access = "true"
  network       = google_compute_network.demo-vpc.name
}

resource "google_compute_subnetwork" "private2" {
  name          = "coalfire-private-subnet2"
  ip_cidr_range = "10.0.3.0/24"
  region        = var.region
  private_ip_google_access = "true"
  network       = google_compute_network.demo-vpc.name
}

# Cloud Router for Private Subnet
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router" "router" {
  name    = "router"
  network = google_compute_network.demo-vpc.name
  bgp {
    asn            = 64514
    advertise_mode = "CUSTOM"
  }
}

# NAT Gateway for Private Network
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "nat" {
  name                               = "private-subnets-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private1.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  subnetwork {
    name                    = google_compute_subnetwork.private2.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Firewall Rule for LB HealthCheck
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall
resource "google_compute_firewall" "backend-healthcheck" {
  name    = "lb-backend-health-check"
  network = google_compute_network.demo-vpc.name

  
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = ["health-check"]
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

# Shared VPC
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_host_project
# A host project provides network resources to associated service projects.
resource "google_compute_shared_vpc_host_project" "host-project" {
  project = var.project
}

resource "google_compute_shared_vpc_service_project" "app-service" {
  host_project    = google_compute_shared_vpc_host_project.host-project.project
  service_project = "vernal-parser-324817"

}
