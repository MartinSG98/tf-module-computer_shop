locals {
  lambda_function_name = "${var.project}-api"

  # OIDC subject claims: restrict each repo to its main branch.
  github_subs = [for repo in var.github_deploy_repos : "repo:${repo}:ref:refs/heads/main"]
}