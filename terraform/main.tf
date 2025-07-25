terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "cloud_run_api" {
  service = "run.googleapis.com"
}

resource "google_project_service" "alloydb_api" {
  service = "alloydb.googleapis.com"
}

resource "google_project_service" "container_api" {
  service = "container.googleapis.com"
}

resource "google_project_service" "cloudbuild_api" {
  service = "cloudbuild.googleapis.com"
}

resource "google_project_service" "secretmanager_api" {
  service = "secretmanager.googleapis.com"
}

resource "google_project_service" "servicenetworking_api" {
  service = "servicenetworking.googleapis.com"
}

resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "artifactregistry_api" {
  service = "artifactregistry.googleapis.com"
}

# VPC Network
resource "google_compute_network" "rails_vpc" {
  name                    = "${var.app_name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute_api]
}

# Subnet for Cloud Run
resource "google_compute_subnetwork" "rails_subnet" {
  name          = "${var.app_name}-subnet"
  ip_cidr_range = "10.1.0.0/24"
  region        = var.region
  network       = google_compute_network.rails_vpc.id
}

# Service Account for Cloud Run
resource "google_service_account" "rails_service_account" {
  account_id   = "${var.app_name}-run"
  display_name = "Rails Cloud Run Service Account"
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "rails_app" {
  name     = var.app_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.rails_service_account.email

    vpc_access {
      network_interfaces {
        network    = google_compute_network.rails_vpc.name
        subnetwork = google_compute_subnetwork.rails_subnet.name
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.container_image

      ports {
        container_port = 80
      }

      env {
        name  = "RAILS_ENV"
        value = "production"
      }

      env {
        name  = "RAILS_LOG_TO_STDOUT"
        value = "true"
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }

      startup_probe {
        http_get {
          path = "/"
          port = 80
        }
        initial_delay_seconds = 30
        timeout_seconds       = 10
        period_seconds        = 10
        failure_threshold     = 3
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 10
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_service.cloud_run_api,
    google_compute_subnetwork.rails_subnet,
    google_alloydb_instance.rails_primary
  ]
}

# Cloud Run IAM - Allow public access
resource "google_cloud_run_service_iam_binding" "noauth" {
  location = google_cloud_run_v2_service.rails_app.location
  service  = google_cloud_run_v2_service.rails_app.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

# Private service connection for AlloyDB
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.app_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.rails_vpc.id
  depends_on    = [google_project_service.servicenetworking_api]
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.rails_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

# AlloyDB Cluster
resource "google_alloydb_cluster" "rails_cluster" {
  cluster_id = "${var.app_name}-cluster"
  location   = var.region

  network_config {
    network = google_compute_network.rails_vpc.id
  }

  initial_user {
    user     = var.db_user
    password = var.db_password
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.alloydb_api
  ]
}

# AlloyDB Primary Instance
resource "google_alloydb_instance" "rails_primary" {
  cluster       = google_alloydb_cluster.rails_cluster.name
  instance_id   = "${var.app_name}-primary"
  instance_type = "PRIMARY"

  machine_config {
    cpu_count = 2
  }

  depends_on = [google_alloydb_cluster.rails_cluster]
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "rails_repo" {
  location      = var.region
  repository_id = "${var.app_name}-repo"
  description   = "Docker repository for Rails application"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry_api]
}

# Service Account for GitHub Actions
resource "google_service_account" "github_actions_sa" {
  account_id   = "${var.app_name}-ga"
  display_name = "GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD pipeline"
}

# Service Account Key for GitHub Actions
resource "google_service_account_key" "github_actions_key" {
  service_account_id = google_service_account.github_actions_sa.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# IAM roles for GitHub Actions Service Account
resource "google_project_iam_member" "github_actions_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_cloud_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_secret_manager_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}
