variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "concur-test-eks"
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "node_group_instance_types" {
  description = "Instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum size of the node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum size of the node group"
  type        = number
  default     = 3
}

variable "node_group_desired_size" {
  description = "Desired size of the node group"
  type        = number
  default     = 2
}

# ArgoCD and Add-ons Configuration

variable "enable_argocd" {
  description = "Enable ArgoCD deployment"
  type        = bool
  default     = true
}

variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI driver"
  type        = bool
  default     = true
}

variable "enable_alb_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_fluent_bit" {
  description = "Enable Fluent Bit for CloudWatch Logs"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler for automatic node scaling"
  type        = bool
  default     = true
}

# EKS Addon Versions

variable "vpc_cni_addon_version" {
  description = "VPC CNI addon version for EKS"
  type        = string
  default     = "v1.20.5-eksbuild.1"
}

variable "coredns_addon_version" {
  description = "CoreDNS addon version for EKS"
  type        = string
  default     = "v1.11.4-eksbuild.24"
}

variable "kube_proxy_addon_version" {
  description = "kube-proxy addon version for EKS"
  type        = string
  default     = "v1.32.9-eksbuild.2"
}

variable "pod_identity_agent_addon_version" {
  description = "EKS Pod Identity Agent addon version"
  type        = string
  default     = "v1.3.10-eksbuild.1"
}

variable "ebs_csi_driver_addon_version" {
  description = "EBS CSI Driver addon version for EKS"
  type        = string
  default     = "v1.53.0-eksbuild.1"
}

# Helm Chart Versions

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.12"
}

variable "aws_load_balancer_controller_chart_version" {
  description = "AWS Load Balancer Controller Helm chart version"
  type        = string
  default     = "1.11.0"
}

variable "alb_controller_version" {
  description = "AWS Load Balancer Controller version for IAM policy"
  type        = string
  default     = "2.11.0"
}

variable "enable_secrets_store_csi_driver" {
  description = "Enable Secrets Store CSI driver"
  type        = bool
  default     = true
}

variable "secrets_store_csi_driver_chart_version" {
  description = "Secrets Store CSI Driver Helm chart version"
  type        = string
  default     = "1.4.7"
}

variable "aws_secrets_manager_provider_chart_version" {
  description = "AWS Secrets Manager Provider Helm chart version"
  type        = string
  default     = "0.3.9"
}

variable "postgres_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "testdb"
}
