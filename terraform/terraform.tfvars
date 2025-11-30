# AWS Configuration
aws_region  = "us-east-1"
environment = "dev"

# EKS Cluster Configuration
cluster_name    = "concur-test-eks"
cluster_version = "1.34"  # Final upgrade step (1.32->1.33->1.34 completed)

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Subnet Configuration
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# NAT Gateway Configuration
enable_nat_gateway = true
single_nat_gateway = false # Set to true to use only one NAT Gateway (cost savings)

# VPC DNS Configuration
enable_dns_hostnames = true
enable_dns_support   = true

# EKS Node Group Configuration
node_group_instance_types = ["t3.medium"]
node_group_min_size       = 2
node_group_max_size       = 6
node_group_desired_size   = 4

# ArgoCD and Add-ons Configuration
enable_argocd                   = true
enable_ebs_csi_driver           = true
enable_alb_controller           = true
enable_secrets_store_csi_driver = true
enable_cluster_autoscaler       = true
enable_fluent_bit               = true

# EKS Addon Versions (Step 2: Kubernetes 1.34)
vpc_cni_addon_version            = "v1.20.5-eksbuild.1"        # Latest for 1.34
coredns_addon_version            = "v1.12.4-eksbuild.1"        # Latest for 1.34
kube_proxy_addon_version         = "v1.34.1-eksbuild.2"        # Upgraded from v1.33.5
pod_identity_agent_addon_version = "v1.3.10-eksbuild.1"        # Latest for 1.34
ebs_csi_driver_addon_version     = "v1.53.0-eksbuild.1"        # Latest for 1.34

# Helm Chart Versions
argocd_chart_version                       = "7.7.12"
aws_load_balancer_controller_chart_version = "1.11.0"
alb_controller_version                     = "2.11.0"
secrets_store_csi_driver_chart_version     = "1.4.7"
aws_secrets_manager_provider_chart_version = "0.3.9"

# PostgreSQL Configuration
postgres_username = "postgres"
postgres_password = "TestPassword123!" # Change this in production
postgres_database = "testdb"
