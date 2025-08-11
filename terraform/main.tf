resource "google_compute_network" "vpc" {
  name                    = var.network
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet
  ip_cidr_range = "10.10.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_container_cluster" "gke" {
  name               = var.cluster_name
  location           = var.zone
  remove_default_node_pool = true
  initial_node_count = 1

  networking_mode = "VPC_NATIVE"
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {}
  release_channel { channel = "REGULAR" }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "np" {
  name       = "${var.cluster_name}-pool"
  location   = google_container_cluster.gke.location
  cluster    = google_container_cluster.gke.name
  node_count = var.node_count

  node_config {
    machine_type = var.node_type
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = { role = "general" }
    metadata = { disable-legacy-endpoints = "true" }
  }

  autoscaling {
    min_node_count = 3
    max_node_count = 8
  }
}
