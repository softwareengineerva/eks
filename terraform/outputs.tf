# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# EKS Cluster Outputs
output "cluster_id" {
  description = "The ID/name of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

# EKS Node Group Outputs
output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.main.status
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = aws_security_group.node.id
}

output "node_iam_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  value       = aws_iam_role.node.arn
}

# Kubectl Configuration
output "configure_kubectl" {
  description = "Configure kubectl: run the following command to update your kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# ArgoCD Outputs
output "argocd_admin_password_command" {
  description = "Command to retrieve ArgoCD admin password"
  value       = var.enable_argocd ? "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : "ArgoCD not enabled"
}

output "argocd_server_service_command" {
  description = "Command to get ArgoCD server service details"
  value       = var.enable_argocd ? "kubectl get service -n argocd argocd-server" : "ArgoCD not enabled"
}

# EBS CSI Driver Outputs
output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : "EBS CSI driver not enabled"
}

# AWS Load Balancer Controller Outputs
output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = var.enable_alb_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : "ALB controller not enabled"
}

# Test App IRSA Outputs
output "test_app_secrets_role_arn" {
  description = "IAM role ARN for test app secrets access"
  value       = aws_iam_role.test_app_secrets_reader.arn
}

output "test_secret_arn" {
  description = "ARN of the test secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.test_secret.arn
}

output "test_secret_name" {
  description = "Name of the test secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.test_secret.name
}

# PostgreSQL Secrets Outputs
output "postgres_secrets_csi_role_arn" {
  description = "IAM role ARN for PostgreSQL Secrets Store CSI access"
  value       = aws_iam_role.postgres_secrets_csi_role.arn
}

output "postgres_secret_arn" {
  description = "ARN of PostgreSQL credentials in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.postgres_credentials.arn
}

output "postgres_secret_name" {
  description = "Name of PostgreSQL credentials secret"
  value       = aws_secretsmanager_secret.postgres_credentials.name
}

# Fluent Bit Outputs
output "fluent_bit_role_arn" {
  description = "IAM role ARN for Fluent Bit to write to CloudWatch Logs"
  value       = var.enable_fluent_bit ? aws_iam_role.fluent_bit[0].arn : null
}

# Cluster Autoscaler Outputs
output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler to manage node group scaling"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}
