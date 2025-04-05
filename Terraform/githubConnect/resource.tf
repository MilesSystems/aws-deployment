resource "aws_iam_openid_connect_provider" "git_hub_oidc_provider" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = [
    "sts.amazonaws.com"
  ]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

resource "aws_iam_role" "git_hub_oidc_role" {
  name = var.role_name
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.git_hub_oidc_provider.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            token.actions.githubusercontent.com:aud = "sts.amazonaws.com"
          }
          StringLike = {
            token.actions.githubusercontent.com:sub = [
              "repo:${var.git_hub_org}/${var.git_hub_repo}:ref:${var.git_hub_branch}",
              "repo:${var.git_hub_org}/${var.git_hub_repo}:ref:pull/*",
              "repo:${var.git_hub_org}/${var.git_hub_repo}"
            ]
          }
        }
      }
    ]
  }
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}

