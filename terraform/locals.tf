locals {
  name_prefix = "concur-test"

  common_tags = {
    Project     = local.name_prefix
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  vpc_tags = {
    Name = "${local.name_prefix}-vpc"
  }

  # EKS requires specific subnet tags for load balancer and ingress controller functionality
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
