# Test Application IRSA for AWS Secrets Manager
# Purpose: Demonstrate pod-level IAM permissions for accessing AWS Secrets Manager

# Create a test secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "test_secret" {
  name        = "${local.name_prefix}-test-secret"
  description = "Test secret for IRSA demonstration"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-test-secret"
    }
  )
}

# Set the secret value
resource "aws_secretsmanager_secret_version" "test_secret_value" {
  secret_id = aws_secretsmanager_secret.test_secret.id
  secret_string = jsonencode({
    username = "test-user"
    password = "test-password-123"
    database = "test-database"
    message  = "This secret was retrieved using IRSA!"
  })
}

# IAM policy for Secrets Manager read access
data "aws_iam_policy_document" "test_app_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.test_secret.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }
}

# Trust policy for test app IRSA
data "aws_iam_policy_document" "test_app_secrets_assume_role" {
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
      values   = ["system:serviceaccount:secrets-demo:secrets-demo-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM role for test app
resource "aws_iam_role" "test_app_secrets_reader" {
  name               = "${local.name_prefix}-test-app-secrets-reader-role"
  assume_role_policy = data.aws_iam_policy_document.test_app_secrets_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-test-app-secrets-reader-role"
    }
  )
}

# IAM policy for test app
resource "aws_iam_policy" "test_app_secrets" {
  name        = "${local.name_prefix}-test-app-secrets-policy"
  description = "IAM policy for test app to read secrets from Secrets Manager"
  policy      = data.aws_iam_policy_document.test_app_secrets.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-test-app-secrets-policy"
    }
  )
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "test_app_secrets" {
  role       = aws_iam_role.test_app_secrets_reader.name
  policy_arn = aws_iam_policy.test_app_secrets.arn
}
