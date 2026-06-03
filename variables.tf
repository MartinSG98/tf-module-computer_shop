variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-west-2"
}

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