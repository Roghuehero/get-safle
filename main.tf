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

# Data source to check existing network
data "google_compute_network" "existing_vpc_network" {
  name = "get-safle-vpc-network"
}

# Create VPC network only if it doesn't exist
resource "google_compute_network" "vpc_network3" {
  count = data.google_compute_network.existing_vpc_network.id == "" ? 1 : 0

  name = "get-safle-vpc-network"
}

# Data source to check existing SQL instance
data "google_sql_database_instance" "existing_db_instance" {
  name = "get-safle-instance"
}

# Create Cloud SQL instance only if it doesn't exist
resource "google_sql_database_instance" "db_instance3" {
  count = data.google_sql_database_instance.existing_db_instance.id == "" ? 1 : 0

  name             = "get-safle-instance"
  database_version = "POSTGRES_13"
  region           = "asia-south2"

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "db3" {
  count    = google_sql_database_instance.db_instance3.count
  name     = "get-safle"
  instance = google_sql_database_instance.db_instance3.name
}

resource "google_sql_database_instance" "db_instance3" {
  count = length(data.google_sql_database_instance.existing_db_instance.instances) == 0 ? 1 : 0
  name  = "get-safle-instance3"
  database_version = "POSTGRES_13"
  region = "asia-south2"

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "db3" {
  count    = length(data.google_sql_database_instance.existing_db_instance.instances) == 0 ? 1 : 0
  name     = "get-safle3"
  instance = google_sql_database_instance.db_instance3.name
}

# Instance Template with startup script and SSH
resource "google_compute_instance_template" "app_template3" {
  name = "get-safle-template3"

  machine_type = "n1-standard-1"

  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = google_compute_network.vpc_network3.id
    subnetwork = google_compute_subnetwork.subnet3.id
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash

    apt-get update
    apt-get install -y nginx

    rm /etc/nginx/sites-enabled/default

    cat <<EOT >> /etc/nginx/sites-available/myapp
    server {
      listen 80;
      server_name get-safle.sabtech.cloud;
      return 301 https://\$host\$request_uri;
    }

    server {
      listen 443 ssl;
      server_name get-safle.sabtech.cloud;

      ssl_certificate /etc/letsencrypt/live/get-safle.sabtech.cloud/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/get-safle.sabtech.cloud/privkey.pem;
      include /etc/letsencrypt/options-ssl-nginx.conf;
      ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

      location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
      }
    }
    EOT

    ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
    service nginx restart

    docker run -d -p 3000:3000 asia-south2-docker.pkg.dev/get-safle/get-safle/app-image:latest

    echo "${var.ssh_public_key}" >> /home/ubuntu/.ssh/authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys
  EOF

  tags = ["web"]
}

# Health Check
resource "google_compute_health_check" "app_health_check3" {
  name = "app-health-check3"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
  }
}

# Backend Service for Load Balancer
resource "google_compute_backend_service" "app_backend3" {
  name         = "app-backend-service3"
  health_checks = [google_compute_health_check.app_health_check3.id]

  backend {
    group = google_compute_region_instance_group_manager.app_group3.instance_group
  }

  depends_on = [google_compute_health_check.app_health_check3]
}

# URL Map for Load Balancer
resource "google_compute_url_map" "app_url_map3" {
  name           = "app-url-map3"
  default_service = google_compute_backend_service.app_backend3.id
}

# HTTP Proxy for Load Balancer
resource "google_compute_target_http_proxy" "app_http_proxy3" {
  name    = "app-http-proxy3"
  url_map = google_compute_url_map.app_url_map3.id
}

# Global Forwarding Rule for Load Balancer
resource "google_compute_global_forwarding_rule" "app_forwarding_rule3" {
  name                   = "app-forwarding-rule3"
  target                 = google_compute_target_http_proxy.app_http_proxy3.id
  port_range             = "80"
  load_balancing_scheme  = "EXTERNAL"
}

# Instance Group Manager
resource "google_compute_region_instance_group_manager" "app_group3" {
  name              = "app-instance-group3"
  region            = "asia-south2"
  base_instance_name = "app-instance3"
  target_size       = 1

  version {
    instance_template = google_compute_instance_template.app_template3.id
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

# Autoscaler
resource "google_compute_region_autoscaler" "app_autoscaler3" {
  name     = "app-autoscaler3"
  region   = "asia-south2"
  target   = google_compute_region_instance_group_manager.app_group3.id

  autoscaling_policy {
    min_replicas = 1
    max_replicas = 3
    cpu_utilization {
      target = 0.6
    }
  }
}
