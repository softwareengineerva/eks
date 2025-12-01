# EKS Cluster Terraform Configuration

This Terraform configuration creates a complete Amazon EKS cluster infrastructure with the following components:

## Author
**Jian Ouyang** (jian.ouyang@sapns2.com)

## Components Created

### Networking
- **VPC**: A custom VPC with configurable CIDR block (default: 10.0.0.0/16)
- **Subnets**:
  - 3 Public subnets across 3 availability zones
  - 3 Private subnets across 3 availability zones
  - Properly tagged for EKS load balancer integration
- **Internet Gateway**: For public subnet internet access
- **NAT Gateways**: One per AZ (or single if configured) for private subnet outbound access
- **Route Tables**: Separate route tables for public and private subnets

### Security
- **Security Groups**:
  - EKS cluster control plane security group
  - EKS worker node security group
  - Properly configured ingress/egress rules for cluster-node communication

### IAM
- **EKS Cluster Role**: With required policies (AmazonEKSClusterPolicy, AmazonEKSVPCResourceController)
- **EKS Node Role**: With required policies (AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly)
- **VPC CNI Role**: For IRSA (IAM Roles for Service Accounts) with VPC CNI addon
- **OIDC Provider**: For pod-level IAM permissions

### EKS Cluster
- **EKS Control Plane**: Managed Kubernetes control plane (v1.34 by default)
- **EKS Addons**:
  - VPC CNI (with IRSA support)
  - CoreDNS
  - kube-proxy
  - EKS Pod Identity Agent
- **EKS Managed Node Group**:
  - AL2023-based nodes
  - Auto-scaling configuration
  - Deployed in private subnets

## Resource Naming

All resources use the prefix `concur-test` by default, as specified in the requirements.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- AWS Provider >= 5.0

## Usage

### Initialize Terraform

```bash
cd terraform
terraform init
```

### Review the Plan

```bash
terraform plan
```

### Apply the Configuration

**Note**: Do not run `terraform apply` without permission.

```bash
terraform apply
```

### Configure kubectl

After the cluster is created, configure kubectl to access the cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name concur-test-eks
```

Or use the output command:

```bash
terraform output -raw configure_kubectl | bash
```

### Verify Cluster Access

```bash
kubectl get nodes
kubectl get pods -A
```

## Customization

### Variables

You can customize the deployment by modifying variables in `variables.tf` or creating a `terraform.tfvars` file:

```hcl
# terraform.tfvars example
aws_region               = "us-west-2"
cluster_name            = "my-custom-eks"
cluster_version         = "1.34"
node_group_instance_types = ["t3.medium", "t3.large"]
node_group_desired_size  = 3
```

### Key Variables

- `aws_region`: AWS region for deployment (default: us-east-1)
- `cluster_name`: Name of the EKS cluster (default: concur-test-eks)
- `cluster_version`: Kubernetes version (default: 1.34)
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `node_group_instance_types`: EC2 instance types for worker nodes (default: ["t3.medium"])
- `node_group_min_size`: Minimum number of nodes (default: 1)
- `node_group_max_size`: Maximum number of nodes (default: 3)
- `node_group_desired_size`: Desired number of nodes (default: 2)

## Outputs

The configuration provides useful outputs including:

- VPC and subnet IDs
- EKS cluster endpoint and certificate
- kubectl configuration command
- IAM role ARNs
- Security group IDs

View all outputs:

```bash
terraform output
```

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           AWS VPC (10.0.0.0/16)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Public Subnet│  │ Public Subnet│  │ Public Subnet│         │
│  │  us-east-1a  │  │  us-east-1b  │  │  us-east-1c  │         │
│  │ 10.0.101.0/24│  │ 10.0.102.0/24│  │ 10.0.103.0/24│         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │ NAT GW          │ NAT GW          │ NAT GW          │
│         │                 │                 │                 │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐         │
│  │Private Subnet│  │Private Subnet│  │Private Subnet│         │
│  │  us-east-1a  │  │  us-east-1b  │  │  us-east-1c  │         │
│  │  10.0.1.0/24 │  │  10.0.2.0/24 │  │  10.0.3.0/24 │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│         │                 │                 │                 │
│         └─────────────────┴─────────────────┘                 │
│                           │                                   │
│                  ┌────────┴─────────┐                         │
│                  │  EKS Node Group  │                         │
│                  │   (AL2023 Nodes) │                         │
│                  └──────────────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴──────────┐
                    │  EKS Control Plane │
                    │    (Managed)       │
                    └────────────────────┘
```

## Notes

- The EKS cluster is configured with both public and private endpoint access
- Worker nodes are deployed in private subnets for security
- NAT Gateways enable outbound internet access for private subnets
- All resources are tagged with the project name "concur-test"
- The configuration follows AWS EKS best practices
- Cluster logging is enabled for audit and troubleshooting

## Support

For issues or questions, please contact the author.
