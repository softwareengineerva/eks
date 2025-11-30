# PostgreSQL Secrets in AWS Secrets Manager
# Purpose: Store PostgreSQL credentials securely for use with Secrets Store CSI Driver

# Create PostgreSQL credentials secret
resource "aws_secretsmanager_secret" "postgres_credentials" {
  name        = "${local.name_prefix}-postgres-credentials"
  description = "PostgreSQL database credentials for test application"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-postgres-credentials"
    }
  )
}

# Set PostgreSQL credentials value
resource "aws_secretsmanager_secret_version" "postgres_credentials_value" {
  secret_id = aws_secretsmanager_secret.postgres_credentials.id
  secret_string = jsonencode({
    username = var.postgres_username
    password = var.postgres_password
    database = var.postgres_database
  })
}

# IAM policy for Secrets Store CSI Driver to access PostgreSQL secret
data "aws_iam_policy_document" "postgres_secrets_csi" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.postgres_credentials.arn
    ]
  }
}

# Trust policy for PostgreSQL Secrets CSI role (IRSA)
data "aws_iam_policy_document" "postgres_secrets_csi_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:postgres:postgres-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM role for PostgreSQL to access secrets via CSI driver
resource "aws_iam_role" "postgres_secrets_csi_role" {
  name               = "${local.name_prefix}-postgres-secrets-csi-role"
  assume_role_policy = data.aws_iam_policy_document.postgres_secrets_csi_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-postgres-secrets-csi-role"
    }
  )
}

# IAM policy for PostgreSQL secrets access
resource "aws_iam_policy" "postgres_secrets_csi_policy" {
  name        = "${local.name_prefix}-postgres-secrets-csi-policy"
  description = "IAM policy for PostgreSQL to access secrets via CSI driver"
  policy      = data.aws_iam_policy_document.postgres_secrets_csi.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-postgres-secrets-csi-policy"
    }
  )
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "postgres_secrets_csi" {
  role       = aws_iam_role.postgres_secrets_csi_role.name
  policy_arn = aws_iam_policy.postgres_secrets_csi_policy.arn
}
