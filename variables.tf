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