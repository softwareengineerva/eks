# Secrets Store CSI Driver for EKS
# Purpose: Enable pods to mount secrets from AWS Secrets Manager as volumes

# Helm release for Secrets Store CSI Driver
resource "helm_release" "secrets_store_csi_driver" {
  count      = var.enable_secrets_store_csi_driver ? 1 : 0
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = var.secrets_store_csi_driver_chart_version
  namespace  = "kube-system"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  set {
    name  = "rotationPollInterval"
    value = "120s"
  }

  depends_on = [
    aws_eks_node_group.main
  ]
}

# Helm release for AWS Secrets Manager CSI Provider
resource "helm_release" "aws_secrets_manager_provider" {
  count      = var.enable_secrets_store_csi_driver ? 1 : 0
  name       = "secrets-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = var.aws_secrets_manager_provider_chart_version
  namespace  = "kube-system"

  depends_on = [
    helm_release.secrets_store_csi_driver
  ]
}
