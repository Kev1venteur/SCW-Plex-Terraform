terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
    }
  }
  required_version = ">= 0.14"
}

provider "scaleway" {
  zone = "fr-par-1"
  region = "fr-par"
}

resource "scaleway_instance_ip" "public_ip" {
}

resource "scaleway_k8s_cluster" "plex_cluster" {
  name             = "plex_cluster"
  description      = "Cluster for Plex TP-2"
  version          = "1.23.0"
  cni              = "cilium"

  autoscaler_config {
    disable_scale_down              = false
    scale_down_delay_after_add      = "5m"
    estimator                       = "binpacking"
    expander                        = "random"
    ignore_daemonsets_utilization   = true
    balance_similar_node_groups     = true
    expendable_pods_priority_cutoff = -5
  }
}

resource "scaleway_k8s_pool" "plxe" {
  cluster_id  = scaleway_k8s_cluster.plex_cluster.id
  name        = "plex_pool"
  node_type   = "GP1-XS"
  size        = 3
  autoscaling = true
  autohealing = true
  min_size    = 1
  max_size    = 5
}

resource "local_file" "kubeconfig" {
  content = scaleway_k8s_cluster.plex_cluster.kubeconfig[0].config_file
  filename = "${path.module}/kubeconfig"
}

output "cluster_url" {
  value = scaleway_k8s_cluster.plex_cluster.apiserver_url
}
