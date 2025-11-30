# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(
    local.common_tags,
    {
      Name = var.cluster_name
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

# EKS Cluster Addons
# VPC CNI
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_addon_version
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-vpc-cni"
    }
  )
}

# CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = var.coredns_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-coredns"
    }
  )

  depends_on = [aws_eks_node_group.main]
}

# kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = var.kube_proxy_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-kube-proxy"
    }
  )
}

# EKS Pod Identity Agent
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = var.pod_identity_agent_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-pod-identity-agent"
    }
  )
}

# EKS Managed Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id
  version         = var.cluster_version  # Keep node group version in sync with cluster

  instance_types = var.node_group_instance_types
  ami_type       = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role        = "general"
    environment = var.environment
  }

  tags = merge(
    local.common_tags,
    {
      Name                                            = "${var.cluster_name}-node-group"
      "k8s.io/cluster-autoscaler/enabled"             = var.enable_cluster_autoscaler ? "true" : "false"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = var.enable_cluster_autoscaler ? "owned" : ""
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
