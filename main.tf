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

resource "scaleway_k8s_pool" "plex_pool" {
  cluster_id  = scaleway_k8s_cluster.plex_cluster.id
  name        = "plex_pool"
  node_type   = "GP1-XS" #RENDER-S for GPUs
  size        = 3
  autoscaling = true
  autohealing = true
  min_size    = 1
  max_size    = 5
}

resource "null_resource" "kubeconfig" {
  depends_on = [scaleway_k8s_pool.plex_pool]
  triggers = {
    host                   = scaleway_k8s_cluster.plex_cluster.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.plex_cluster.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.plex_cluster.kubeconfig[0].cluster_ca_certificate
  }
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig-plex_cluster.yaml"
    host  = null_resource.kubeconfig.triggers.host
    token = null_resource.kubeconfig.triggers.token
    cluster_ca_certificate = base64decode(
    null_resource.kubeconfig.triggers.cluster_ca_certificate
    )
  }
}

resource "scaleway_lb_ip" "nginx_ip" {
}

resource "helm_release" "nginx_ingress" {
  name      = "nginx-ingress"
  namespace = "kube-system"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"

  set {
    name = "controller.service.loadBalancerIP"
    value = scaleway_lb_ip.nginx_ip.ip_address
  }

  // enable proxy protocol to get client ip addr instead of loadbalancer one
  set {
    name = "controller.config.use-proxy-protocol"
    value = "true"
  }
 
  set {
    name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/scw-loadbalancer-proxy-protocol-v2"
    value = "true"
  }

  // enable to avoid node forwarding
  set {
    name = "controller.service.externalTrafficPolicy"
    value = "Local"
  }
}

resource "helm_release" "plex" {
  name       = "plex"
  repository = "https://k8s-at-home.com/charts/"
  chart      = "plex"

  set {
    name  = "cluster.enabled"
    value = "true"
  }

  set {
    name  = "metrics.enabled"
    value = "true"
  }
  
  set {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
    type  = "string"
  }
}
