provider "google" {
  project     = "get-safle"
  region      = "asia-south2"
  credentials = var.gcp_credentials
}

variable "gcp_credentials" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

# Data block to retrieve existing network
data "google_compute_network" "existing_vpc_network3" {
  name = "get-safle-vpc-network"
}

# If VPC network does not exist, create one
resource "google_compute_network" "vpc_network3" {
  count = length(data.google_compute_network.existing_vpc_network3.name) == 0 ? 1 : 0
  name  = "get-safle-vpc-network"
}

# Subnet (created only if network is created)
resource "google_compute_subnetwork" "subnet3" {
  count       = length(data.google_compute_network.existing_vpc_network3.name) == 0 ? 1 : 0
  name        = "get-safle-subnet"
  region      = "asia-south2"
  network     = google_compute_network.vpc_network3[0].id
  ip_cidr_range = "10.0.0.0/16"
}

# Instance Template
resource "google_compute_instance_template" "app_template3" {
  name         = "get-safle-template"
  machine_type = "n1-standard-1"

  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = data.google_compute_network.existing_vpc_network3.id
    subnetwork = google_compute_subnetwork.subnet3[0].id
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y nginx
    docker run -d -p 3000:3000 asia-south2-docker.pkg.dev/get-safle/get-safle/app-image:latest
    echo "${var.ssh_public_key}" >> /home/ubuntu/.ssh/authorized_keys
  EOF
}

# Managed Instance Group
resource "google_compute_region_instance_group_manager" "app_group3" {
  name               = "get-safle-instance-group"
  base_instance_name = "get-safle-instance"
  region             = "asia-south2"
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.app_template3.id
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

# Autoscaler
resource "google_compute_region_autoscaler" "app_autoscaler3" {
  name   = "get-safle-autoscaler"
  region = "asia-south2"
  target = google_compute_region_instance_group_manager.app_group3.id

  autoscaling_policy {
    min_replicas = 1
    max_replicas = 3
    cpu_utilization {
      target = 0.6
    }
  }
}

# Load Balancer Backend Service
resource "google_compute_backend_service" "app_backend3" {
  name = "get-safle-backend-service"

  backend {
    group = google_compute_region_instance_group_manager.app_group3.instance_group
  }
}

# URL Map for Load Balancer
resource "google_compute_url_map" "app_url_map3" {
  name           = "get-safle-url-map"
  default_service = google_compute_backend_service.app_backend3.id
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "app_http_proxy3" {
  name    = "get-safle-http-proxy"
  url_map = google_compute_url_map.app_url_map3.id
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "app_forwarding_rule3" {
  name       = "get-safle-forwarding-rule"
  target     = google_compute_target_http_proxy.app_http_proxy3.id
  port_range = "80"
}
