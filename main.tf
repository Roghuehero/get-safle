provider "google" {
  project     = "get-safle"
  region      = "asia-south2"
  credentials = var.gcp_credentials
}

variable "gcp_credentials" {
  type      = string
  sensitive = true
}

# Create GCP Network
resource "google_compute_network" "vpc_network" {
  name = "get-safle-vpc-network"
}

# Create Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "my-subnet"
  region        = "asia-south2"
  network       = google_compute_network.vpc_network.id
  ip_cidr_range = "10.0.0.0/16"
}

# Create GCP Managed Database (Cloud SQL)
resource "google_sql_database_instance" "db_instance" {
  name             = "get-safle-instance"
  database_version = "POSTGRES_13"
  region           = "asia-south2"

  settings {
    tier = "db-f1-micro"
  }
}

resource "google_sql_database" "db" {
  name     = "get-safle"
  instance = google_sql_database_instance.db_instance.name
}

# Create Instance Template for Auto-Scaling Group
resource "google_compute_instance_template" "app_template" {
  name = "get-safle-template"
  
  machine_type = "n1-standard-1"
  
  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
  }
  
  # Updated startup script to install Nginx and run the Node.js app
  metadata_startup_script = <<-EOF
    #!/bin/bash

    # Update package lists
    apt-get update

    # Install Nginx
    apt-get install -y nginx

    # Remove default Nginx configuration
    rm /etc/nginx/sites-enabled/default

    # Create new Nginx configuration for the Node.js app with HTTPS setup
    cat <<EOT >> /etc/nginx/sites-available/myapp
    server {
        listen 80;
        server_name get-safle.sabtech.cloud;

        # Redirect all HTTP traffic to HTTPS
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
            proxy_pass http://localhost:3000; # Change port if needed
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
    EOT

    # Enable the new site and restart Nginx
    ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
    service nginx restart

    # Run the Node.js app
    docker run -d -p 3000:3000 asia-south2-docker.pkg.dev/get-safle/get-safle/app-image:latest  
  EOF

  tags = ["web"]
}

# Health Check
resource "google_compute_health_check" "app_health_check" {
  name                = "app-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
  }
}

# Load Balancer Backend Service
resource "google_compute_backend_service" "app_backend" {
  name          = "app-backend-service"
  health_checks = [google_compute_health_check.app_health_check.id]

  backend {
    group = google_compute_region_instance_group_manager.app_group.instance_group
  }

  depends_on = [google_compute_health_check.app_health_check]  
}

# URL Map for Load Balancer
resource "google_compute_url_map" "app_url_map" {
  name            = "app-url-map"
  default_service = google_compute_backend_service.app_backend.id
}

# HTTP Proxy
resource "google_compute_target_http_proxy" "app_http_proxy" {
  name    = "app-http-proxy"
  url_map = google_compute_url_map.app_url_map.id
}

# Global Forwarding Rule for Load Balancer
resource "google_compute_global_forwarding_rule" "app_forwarding_rule" {
  name                = "app-forwarding-rule"
  target              = google_compute_target_http_proxy.app_http_proxy.id
  port_range          = "80"
  load_balancing_scheme = "EXTERNAL"
}

# Create Instance Group Manager
resource "google_compute_region_instance_group_manager" "app_group" {
  name                    = "app-instance-group"
  region                  = "asia-south2"
  base_instance_name      = "app-instance" 
  target_size             = 1

  version {
    instance_template = google_compute_instance_template.app_template.id
  }

  lifecycle {
    ignore_changes = [target_size] 
  }
}

# Autoscaler
resource "google_compute_region_autoscaler" "app_autoscaler" {
  name   = "app-autoscaler"
  region = "asia-south2"
  target = google_compute_region_instance_group_manager.app_group.id

  autoscaling_policy {
    min_replicas    = 1
    max_replicas    = 3
    cpu_utilization {
      target = 0.6
    }
  }
}
