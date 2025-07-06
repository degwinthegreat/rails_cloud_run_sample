terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
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
