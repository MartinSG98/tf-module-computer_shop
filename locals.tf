locals {
  lambda_function_name = "${var.project}-api"

  # OIDC subject claims: restrict each repo to its main branch.
  github_subs          = [for repo in var.github_deploy_repos : "repo:${repo}:ref:refs/heads/main"]
  github_frontend_subs = [for repo in var.github_frontend_repos : "repo:${repo}:ref:refs/heads/main"]

  # API CORS: always allow the hosted frontend's CloudFront URL, plus any extra
  # origins supplied via the variable (e.g. a custom domain or localhost).
  frontend_origin = "https://${aws_cloudfront_distribution.frontend.domain_name}"
  api_cors_origins = (
    var.cors_allow_origins != ""
    ? "${local.frontend_origin},${var.cors_allow_origins}"
    : local.frontend_origin
  )
}