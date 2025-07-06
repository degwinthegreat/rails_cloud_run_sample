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

output "artifact_registry_repository" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.rails_repo.repository_id}"
}

output "github_actions_service_account_email" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github_actions_sa.email
}

output "github_actions_service_account_key" {
  description = "Base64 encoded service account key for GitHub Actions"
  value       = google_service_account_key.github_actions_key.private_key
  sensitive   = true
}

output "container_image_url" {
  description = "Full container image URL for Artifact Registry"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.rails_repo.repository_id}/${var.app_name}"
}
