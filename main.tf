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
  description      = "Cluster for Plex TP-3."
  version          = "1.23"
  cni              = "flannel" # More mature and stable than Calico, Weave and Cilium
  #ingress	   = "nginx" # There is a bug that appear to have deleted the ingress argument
  # See https://github.com/hashicorp/terraform/issues/28986

  auto_upgrade {
    enable				= true
    maintenance_window_start_hour       = 3
    maintenance_window_day              = "any"
  }
  
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
  node_type   = "GP1-XS" #Change to RENDER-S for GPUs instances - but will cost more
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

# Use of Helm to deploy services inside the cluster in one step
provider "helm" {
  kubernetes {
    host  = null_resource.kubeconfig.triggers.host
    token = null_resource.kubeconfig.triggers.token
    cluster_ca_certificate = base64decode(
      null_resource.kubeconfig.triggers.cluster_ca_certificate
    )
  }
}

resource "scaleway_lb_ip" "nginx_ip" {
}

# Deploying nginx load-balancer via Helm
resource "helm_release" "nginx_ingress" {
  name      = "nginx-ingress"
  namespace = "kube-system"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"

  set {
    name = "controller.service.loadBalancerIP"
    value = scaleway_lb_ip.nginx_ip.ip_address
  }

  # Proxy protocol to get client ip addr instead of loadbalancer one
  set {
    name = "controller.config.use-proxy-protocol"
    value = "true"
  }
 
  set {
    name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/scw-loadbalancer-proxy-protocol-v2"
    value = "true"
  }

  # Avoid node ip forwarding
  set {
    name = "controller.service.externalTrafficPolicy"
    value = "Local"
  }
  
  # Cert manager to get signed let's encrypt certificate
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/scw-loadbalancer-use-hostname"
    value = "true"
  }
}

# Deploy Plex via Helm from k8s@home artifactory
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
  
  set { #Enable plex metrics monitoring for prometeus
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
    type  = "string"
  }
}

# Récupération du fichier kubeconfig
resource "local_file" "kubeconfig" {
  content = scaleway_k8s_cluster.plex_cluster.kubeconfig[0].config_file
  filename = "${path.module}/kubeconfig"
}

# Output infos
output "cluster_url" {
  value = scaleway_k8s_cluster.plex_cluster.apiserver_url
}

output "public_loadbalancer_ip" {
  value = scaleway_lb_ip.nginx_ip.ip_address
}
