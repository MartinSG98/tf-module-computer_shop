locals {
  lambda_function_name = "${var.project}-api"
  eval_function_name   = "${var.project}-build-eval"
  eval_model_key       = "build-eval/model.onnx"

  # AgentCore runtime names allow [a-zA-Z0-9_] only, so hyphens become underscores.
  agent_runtime_name = "${replace(var.project, "-", "_")}_support_agent"
  agent_code_key     = "support-agent/agent.zip"

  # Custom domains are opt-in: each is only wired up when its name is supplied.
  api_domain_enabled  = var.api_domain_name != ""
  site_domain_enabled = var.site_domain_name != ""
  # The Route 53 zone is needed if either custom domain is in use.
  dns_enabled = local.api_domain_enabled || local.site_domain_enabled

  # OIDC subject claims: restrict each repo to its main branch.
  github_subs          = [for repo in var.github_deploy_repos : "repo:${repo}:ref:refs/heads/main"]
  github_frontend_subs = [for repo in var.github_frontend_repos : "repo:${repo}:ref:refs/heads/main"]
  github_eval_subs     = [for repo in var.github_eval_repos : "repo:${repo}:ref:refs/heads/main"]
  github_agent_subs    = [for repo in var.github_agent_repos : "repo:${repo}:ref:refs/heads/main"]

  # API CORS: always allow the hosted frontend's CloudFront URL, the site's
  # custom domain (when configured), plus any extra origins from the variable.
  frontend_origin = "https://${aws_cloudfront_distribution.frontend.domain_name}"
  site_origin     = local.site_domain_enabled ? "https://${var.site_domain_name}" : ""
  # The site is served on www too, so its origin must be allowed by the API CORS.
  site_www_origin = local.site_domain_enabled ? "https://www.${var.site_domain_name}" : ""
  api_cors_origins = join(",", compact([
    local.frontend_origin,
    local.site_origin,
    local.site_www_origin,
    var.cors_allow_origins,
  ]))
}