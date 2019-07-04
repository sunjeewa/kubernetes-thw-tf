# GCP VPC
resource "google_compute_network" "vpc_network" {
  name                    = "${var.network_name}"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "vpc_subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = "${var.vpc_cidr}"
  region        = "${var.gcp_region}"
  network       = "${var.network_name}"
}

# Firewall rule that allows internal communication across all protocols

resource "google_compute_firewall" "allow-internal" {
  name    = "${var.application_name}-allow-internal"
  network = "${var.network_name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
  }

  source_ranges = "${var.source_ranges}"
}

resource "google_compute_firewall" "allow-external" {
  name    = "${var.application_name}-allow-external"
  network = "${var.network_name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = "${var.my_ip}"
}

# Allocate a static IP address that will be attached to the external load balancer fronting the Kubernetes API Servers:
resource "google_compute_address" "ip_address" {
  name   = "public-ip"
  region = "${var.gcp_region}"
}

output "public_ip" {
  value = "${google_compute_address.ip_address.address}"
}

# Create compute instances which will host the Kubernetes control plane:
resource "google_compute_instance" "controller_0" {
  name         = "controller-0"
  machine_type = "${var.machine_type}"
  zone         = "${var.compute_zone}"

  tags = ["type", "controller"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  // Local SSD disk
  //scratch_disk {}

  network_interface {
    network    = "${var.network_name}"
    network_ip = "10.240.0.10"
    subnetwork = "${var.network_name}-subnet"

    access_config {
      // Ephemeral IP
    }
  }
  metadata = {
    type = "controller"
  }
  metadata_startup_script = "echo hi > /test.txt"
  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }
}

output "controller-0 ip" {
  value = "${google_compute_instance.controller_0.network_interface.0.access_config.0.nat_ip}"
}

resource "local_file" "controller_0_conf" {
  content  = "${google_compute_instance.controller_0.network_interface.0.access_config.0.nat_ip}"
  filename = "conf/controller-0.conf"
}

# Create compute instances which will host the Kubernetes workers:
resource "google_compute_instance" "worker_0" {
  name         = "worker-0"
  machine_type = "${var.machine_type}"
  zone         = "${var.compute_zone}"

  tags = ["type", "worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  // Local SSD disk
  //scratch_disk {}

  network_interface {
    network    = "${var.network_name}"
    network_ip = "10.240.0.20"
    subnetwork = "${var.network_name}-subnet"

    access_config {
      // Ephemeral IP
    }
  }
  metadata = {
    type     = "worker"
    pod-cidr = "10.200.${count.index}.0/24"
  }
  metadata_startup_script = "echo hi > /test.txt"
  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }
}

output "worker-0 ip" {
  value = "${google_compute_instance.worker_0.network_interface.0.access_config.0.nat_ip}"
}

locals {
  nat_ip_worker_0         = "${google_compute_instance.worker_0.network_interface.0.access_config.0.nat_ip}"
  nat_ip_controller_0     = "${google_compute_instance.controller_0.network_interface.0.access_config.0.nat_ip}"
  network_ip_worker_0     = "${google_compute_instance.worker_0.network_interface.0.network_ip}"
  network_ip_controller_0 = "${google_compute_instance.controller_0.network_interface.0.network_ip}"
  api_public_ip           = "${google_compute_address.ip_address.address}"
}

# Provision a Network Load Balancer
resource "google_compute_http_health_check" "kubernetes" {
  name               = "authentication-health-check"
  request_path       = "/healthz"
  host               = "kubernetes.default.svc.cluster.local"
  timeout_sec        = 10
  check_interval_sec = 30
}

resource "google_compute_firewall" "healthcheck-fw-rule" {
  name    = "${var.application_name}-allow-healthcheck"
  network = "${var.network_name}"

  allow {
    protocol = "tcp"
  }

  source_ranges = ["209.85.152.0/22", "209.85.204.0/22", "35.191.0.0/16"]
}

# Create a target pool
resource "google_compute_target_pool" "kubernetes-target-pool" {
  name = "kubernetes-target-pool"

  instances = [
    "us-central1-a/controller-0",
  ]

  health_checks = [
    "${google_compute_http_health_check.kubernetes.name}",
  ]
}

# gcloud compute forwarding-rules create kubernetes-forwarding-rule \
#   --address ${KUBERNETES_PUBLIC_ADDRESS} \
#   --ports 6443 \
#   --region $(gcloud config get-value compute/region) \
#   --target-pool kubernetes-target-pool

resource "google_compute_forwarding_rule" "kubernetes-forwarding-rule" {
  name       = "kubernetes-forwarding-rule"
  ip_address = "${google_compute_address.ip_address.address}"
  target     = "${google_compute_target_pool.kubernetes-target-pool.self_link}"
  port_range = "6443"
}
