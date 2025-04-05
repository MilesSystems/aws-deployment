variable git_hub_org {
  description = "The GitHub organization or user name"
  type = string
  default = "MilesSystems"
}

variable git_hub_repo {
  description = "The GitHub repository name (optional)"
  type = string
  default = "*"
}

variable git_hub_branch {
  description = "The GitHub branch name (optional)"
  type = string
  default = "refs/heads/*"
}

variable role_name {
  description = "The name of the IAM Role to be created"
  type = string
  default = "GitHubOIDCRole"
}

