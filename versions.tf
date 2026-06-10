terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.21+ is needed for aws_bedrockagentcore_agent_runtime (support agent).
      version = "~> 6.21"
      # us_east_1 is required for the CloudFront (site) ACM certificate.
      configuration_aliases = [aws.us_east_1]
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}