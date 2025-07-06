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
    google_compute_subnetwork.rails_subnet
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
