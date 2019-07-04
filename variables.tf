variable "application_name" {
  default = "kubernetes-the-hard-way"
}

variable "network_name" {
  default = "kubernetes-the-hard-way"
  
}

variable "vpc_cidr" {
  default = "10.240.0.0/24"
}

variable "compute_zone" {
  default = "us-central1-a"
}

variable "source_ranges" {
  default = ["10.240.0.0/24", "10.200.0.0/16"]
}

variable "my_ip" {
  default = ["0.0.0.0/0"]
}

variable "gcp_region" {
  default = "us-central1"
}

variable "controller_count" {
  default = 1
}

variable "worker_count" {
  default = 1
}

variable "machine_type" {
  default = "g1-small"
}