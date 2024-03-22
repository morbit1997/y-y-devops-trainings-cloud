terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file("myserver-morbit-a6cddc8c63fb.json")

  project = "myserver-morbit"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_compute_instance_template" "my_template_cat" {
  name = "my-template-cat"
  machine_type = "e2-micro"
  region = "us-central1"

  disk {
    source_image = "cos-cloud/cos-stable"
    auto_delete = true
  }
  network_interface {
    network = "default"
    access_config {
    }
  }
  metadata_startup_script = templatefile("docker_run.tftpl",{
    int_ip_prom = google_compute_address.input_prom.address
  })
}
resource "google_compute_instance_group_manager" "catgtp_insances" {
  name = "catgtp-instanses"
  base_instance_name = "catgtp-instanses"
  zone = "us-central1-c"
  named_port {
    name = "http"
    port = 8080
  }
  version {
    instance_template = google_compute_instance_template.my_template_cat.self_link
  }
  target_size = 2
}
resource "google_compute_firewall" "open_custom_ports" {
 name    = "open-8080-9090"
 network = "default"

 allow {
   protocol = "icmp"
 }

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "9090"]
  }

 source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_project_default_network_tier" "default" {
  network_tier = "PREMIUM"
  
}
resource "google_compute_global_address" "default" {
  name = "lb-ipv4"
  ip_version = "IPV4"
}

resource "google_compute_backend_service" "my_backend" {
  name = "my-backend"
  protocol = "HTTP"
  timeout_sec = 30
  load_balancing_scheme = "EXTERNAL"
  port_name = "http"
  backend {
    group = google_compute_instance_group_manager.catgtp_insances.instance_group
    balancing_mode = "UTILIZATION"
    capacity_scaler = 1.0
  }
  health_checks = [google_compute_http_health_check.my_health_check.id]
}
resource "google_compute_url_map" "default" {
  name = "web-map-http"
  default_service = google_compute_backend_service.my_backend.id
}
resource "google_compute_target_http_proxy" "default" {
  name = "http-lb-proxy"
  url_map = google_compute_url_map.default.id
  
}
resource "google_compute_global_forwarding_rule" "my_forwarding_rule" { 
  name       = "my-forwarding-rule" 
  load_balancing_scheme = "EXTERNAL"
  port_range = "80"
  target     = google_compute_target_http_proxy.default.id
  ip_address = google_compute_global_address.default.id
} 
 
# Создание здоровья проверки 
resource "google_compute_http_health_check" "my_health_check" { 
  name               = "my-health-check"
  request_path       = "/ping" 
  port = 8080
  check_interval_sec = 1 
  timeout_sec        = 1 
}
resource "google_compute_address" "input_prom" {
  name = "prom-ip"
  address_type = "INTERNAL"
  
}
resource "google_compute_instance" "promet" {
  name         = "prom-instance"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    network = "default"
    network_ip = google_compute_address.input_prom.address
    access_config {
    }
  }
  metadata_startup_script = file("prom_conf.tftpl")
  
}
