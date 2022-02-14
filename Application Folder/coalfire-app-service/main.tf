provider "google" {
  credentials = file("~/coalfire-terrafom-key2.json")
  project = var.project
  region  = var.region
  zone    = var.zone
}
# Compute Engine in Private Subnet
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#nat_ip
resource "google_compute_instance" "instance-private" {
  name = "apache-instance-private"
  machine_type = "e2-standard-2"
  tags = ["health-check"]
  metadata_startup_script = file("startup.sh")
  zone = var.zone
  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-8"
      size = "20"
    }
  }
  network_interface {
    network = var.shared-network
    subnetwork =  var.subnet-private1  
  }
}

# Compute Engine in Public Subnet
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#nat_ip
resource "google_compute_instance" "instance-public" {
  name = "vm-instance-public"
  machine_type = "e2-standard-2"
  zone = var.zone
  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-8"
      size = "20"
    }
  }
  network_interface {
    network = var.shared-network
    subnetwork =  var.subnet-public1  

    access_config {
      // Ephemeral public IP
    }
  }
}

# Health  Check for LoadBalancer (LB) Backend
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check

resource "google_compute_health_check" "lb-health-check" {
  name = "lb-health-check"

  timeout_sec        = 1
  check_interval_sec = 1
  healthy_threshold   = 4
  unhealthy_threshold = 5

  tcp_health_check {
    port = "80"
  }
}

# Unmanaged Instance Group for LB
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_group

resource "google_compute_instance_group" "appserver-instancegrp" {
  name        = "coalfire-appserver"
  description = "Instance group for application server"
  zone = var.zone

  instances = google_compute_instance.instance-private.*.self_link

   named_port {
    name = "backend-port"
    port = "80"
  }
} 

# Creating the LB
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule
# used to forward traffic to the correct load balancer for HTTP load balancing
resource "google_compute_global_forwarding_rule"  "global_forwarding_rule" {
  name = "${var.app_name}-global-forwarding-rule"
  project = var.project
  target = google_compute_target_http_proxy.target_http_proxy.self_link
  port_range = "80"
}
# used by one or more global forwarding rule to route incoming HTTP requests to a URL map
resource "google_compute_target_http_proxy" "target_http_proxy" {
  name = "${var.app_name}-proxy"
  project = var.project
  url_map = google_compute_url_map.url_map.self_link
}
# defines a group of virtual machines that will serve traffic for load balancing
resource "google_compute_backend_service" "backend_service" {
  name = "${var.app_name}-backend-service"
  project = var.project
  port_name = "backend-port"
  protocol = "HTTP"
  load_balancing_scheme = "EXTERNAL"
  health_checks = ["${google_compute_health_check.lb-health-check.self_link}"]
  backend {
    group = "${google_compute_instance_group.appserver-instancegrp.self_link}"
    balancing_mode = "RATE"
    max_rate_per_instance = 100
  }
}


# used to route requests to a backend service based on rules that you define for the host and path of an incoming URL
resource "google_compute_url_map" "url_map" {
  name = "${var.app_name}-load-balancer"
  project = var.project
  default_service = google_compute_backend_service.backend_service.self_link
}

