variable "project" {
  description = "Project name; used as a prefix for resource names and tags."
  type        = string
  default     = "computer-shop"
}

variable "cors_allow_origins" {
  description = "Comma-separated CORS origins for the API (e.g. https://shop.example.com). Empty falls back to the API's local-dev defaults."
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