# tf-module-computer_shop

Terraform for the Computer Shop backend infrastructure on AWS (eu-west-2).

## What it provisions

- **DynamoDB** — `products` and `categories` tables (free-tier provisioned 5/5).
- **S3 + CloudFront** — private bucket for product images, served via CloudFront.
- **Lambda** — the FastAPI app (Mangum handler), packaged with Linux wheels.
- **API Gateway (HTTP API)** — public endpoint that proxies to the Lambda.
- **GitHub OIDC** — an IAM role GitHub Actions assumes to deploy (no static keys).

## Status

Scaffold only — provider, variables, and conventions. Resources are added in
later steps.

## Prerequisites

- Terraform >= 1.5
- AWS credentials for the **initial** apply (bootstrap). After that, CI deploys
  via the GitHub OIDC role.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

State is **local** (`terraform.tfstate`, gitignored) for now.

## Conventions

- Region and a `project` name prefix come from `variables.tf`.
- All resources are tagged via the provider's `default_tags` (`Project`,
  `ManagedBy`).