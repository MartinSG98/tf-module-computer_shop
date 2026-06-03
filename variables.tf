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