# Fluent Bit for CloudWatch Logs Integration
# Purpose: Collect pod logs and send to CloudWatch with per-app log groups

# IAM policy for Fluent Bit to write to CloudWatch Logs
data "aws_iam_policy_document" "fluent_bit" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/*"]
  }
}

# Trust policy for Fluent Bit - Pod Identity (migrated from IRSA)
# BEFORE (IRSA): Required OIDC provider + complex trust policy with conditions
# AFTER (Pod Identity): Simple trust policy with pods.eks.amazonaws.com service principal
data "aws_iam_policy_document" "fluent_bit_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM role for Fluent Bit
resource "aws_iam_role" "fluent_bit" {
  count              = var.enable_fluent_bit ? 1 : 0
  name               = "${local.name_prefix}-fluent-bit-role"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-fluent-bit-role"
    }
  )
}

# IAM policy for Fluent Bit
resource "aws_iam_policy" "fluent_bit" {
  count       = var.enable_fluent_bit ? 1 : 0
  name        = "${local.name_prefix}-fluent-bit-policy"
  description = "IAM policy for Fluent Bit to write logs to CloudWatch"
  policy      = data.aws_iam_policy_document.fluent_bit.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-fluent-bit-policy"
    }
  )
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "fluent_bit" {
  count      = var.enable_fluent_bit ? 1 : 0
  role       = aws_iam_role.fluent_bit[0].name
  policy_arn = aws_iam_policy.fluent_bit[0].arn
}

# Pod Identity Association - Replaces IRSA ServiceAccount annotation
# BEFORE (IRSA): Required annotation on ServiceAccount:
#   eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/fluent-bit-role
# AFTER (Pod Identity): EKS manages the association automatically
#   - No annotation needed on ServiceAccount
#   - Visible in AWS Console: EKS → Cluster → Access → Pod Identity associations
#   - Simpler troubleshooting and cross-cluster role reuse
resource "aws_eks_pod_identity_association" "fluent_bit" {
  count           = var.enable_fluent_bit ? 1 : 0
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "logging"
  service_account = "fluent-bit"
  role_arn        = aws_iam_role.fluent_bit[0].arn

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-fluent-bit-pod-identity"
    }
  )
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}
