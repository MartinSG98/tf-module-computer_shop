variable "project" {
  description = "Project name; used as a prefix for resource names and tags."
  type        = string
  default     = "computer-shop"
}

variable "cors_allow_origins" {
  description = "EXTRA comma-separated CORS origins, in addition to the frontend CloudFront URL (which is always allowed). Use for a custom domain or local dev, e.g. https://shop.example.com."
  type        = string
  default     = ""
}

variable "github_deploy_repos" {
  description = "GitHub repos (owner/name) whose main branch may assume the backend deploy role via OIDC."
  type        = list(string)
  default     = ["MartinSG98/computer-shop-backend"]
}

variable "github_frontend_repos" {
  description = "GitHub repos (owner/name) whose main branch may assume the frontend deploy role via OIDC."
  type        = list(string)
  default     = ["MartinSG98/computer_shop_ui"]
}

variable "github_eval_repos" {
  description = "GitHub repos (owner/name) whose main branch may assume the build-evaluator deploy role via OIDC."
  type        = list(string)
  default     = ["MartinSG98/computer-shop-build-eval"]
}

variable "github_agent_repos" {
  description = "GitHub repos (owner/name) whose main branch may assume the support-agent deploy role via OIDC."
  type        = list(string)
  default     = ["MartinSG98/computer-shop-support-agent"]
}

variable "agent_model_id" {
  description = "Bedrock model id the support agent invokes for chat. Must be available (on-demand) in this region."
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

variable "eval_allowed_origin" {
  description = "Access-Control-Allow-Origin returned by the evaluator Lambda. '*' is fine for this public, no-auth scoring endpoint."
  type        = string
  default     = "*"
}

variable "eval_suggest_model_id" {
  description = "Bedrock model id the evaluator Lambda invokes for build suggestions. Must be available (on-demand) in this region."
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

variable "api_domain_name" {
  description = "Custom domain for the API, e.g. api.msg-computers.com. Leave empty to use only the default API Gateway invoke URL."
  type        = string
  default     = ""
}

variable "site_domain_name" {
  description = "Custom domain for the frontend site, e.g. msg-computers.com. Leave empty to use only the default CloudFront URL."
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "Route 53 public hosted zone the custom domains live in, e.g. msg-computers.com. Required when api_domain_name or site_domain_name is set."
  type        = string
  default     = ""
}

variable "api_throttle_rate_limit" {
  description = "Steady-state requests-per-second cap across all API routes."
  type        = number
  default     = 20
}

variable "api_throttle_burst_limit" {
  description = "Maximum burst of concurrent requests for the API."
  type        = number
  default     = 40
}