output "front_ip" {
  value = google_compute_global_address.default.address
}

output "prometheus_ip" {
  value = google_compute_instance.promet.network_interface.0.access_config.0.nat_ip

}