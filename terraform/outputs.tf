output "cloud_run_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.rails_app.uri
}
output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.rails_vpc.name
}

output "service_account_email" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.rails_service_account.email
}

output "subnet_name" {
  description = "Name of the subnet used for Direct VPC Egress"
  value       = google_compute_subnetwork.rails_subnet.name
}

output "alloydb_cluster_name" {
  description = "Name of the AlloyDB cluster"
  value       = google_alloydb_cluster.rails_cluster.name
}

output "alloydb_primary_ip" {
  description = "IP address of the AlloyDB primary instance"
  value       = google_alloydb_instance.rails_primary.ip_address
  sensitive   = true
}
