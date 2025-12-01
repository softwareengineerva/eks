# ArgoCD for EKS
# Purpose: GitOps continuous deployment tool for Kubernetes

# ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = "argocd"
    labels = {
      name        = "argocd"
      environment = var.environment
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# Helm release for ArgoCD
resource "helm_release" "argocd" {
  count      = var.enable_argocd ? 1 : 0
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd[0].metadata[0].name

  # Server configuration
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "external"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "ip"
  }

  # High Availability configuration
  set {
    name  = "redis-ha.enabled"
    value = "true"
  }

  set {
    name  = "controller.replicas"
    value = "1" # Test environment, can scale to 3 for HA
  }

  set {
    name  = "server.replicas"
    value = "2" # At least 2 for HA
  }

  set {
    name  = "repoServer.replicas"
    value = "2" # At least 2 for HA
  }

  set {
    name  = "applicationSet.replicas"
    value = "2"
  }

  # Resource limits
  set {
    name  = "server.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "server.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "256Mi"
  }

  # Ingress configuration (disabled, using LoadBalancer instead)
  set {
    name  = "server.ingress.enabled"
    value = "false"
  }

  # Enable metrics
  set {
    name  = "server.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "repoServer.metrics.enabled"
    value = "true"
  }

  # Config
  set {
    name  = "configs.params.server\\.insecure"
    value = "true" # HTTP for test environment
  }

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.aws_load_balancer_controller
  ]
}
