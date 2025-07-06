variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "asia-northeast1"
}

variable "app_name" {
  description = "The name of the application"
  type        = string
  default     = "rails-cloud-run-sample"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "production"
}

variable "container_image" {
  description = "Container image URL for the Rails application"
  type        = string
  default     = "mirror.gcr.io/nginx:latest"
}
