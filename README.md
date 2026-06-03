# tf-module-computer_shop

Reusable Terraform **module** for the Computer Shop backend infrastructure on AWS.

This module declares resources only — it does **not** configure a provider or a
backend. A root **stack** (see `tf-stack-computer_shop`) configures the AWS
provider (region, tags) and state, then calls this module.

## Resources

- **DynamoDB** — `products` and `categories` tables (free-tier provisioned 5/5).
- **S3 + CloudFront** — private images bucket served via CloudFront (OAC).
- **Lambda** — function shell (placeholder code; CI/CD owns deploys).
- **API Gateway (HTTP API)** — proxies all requests to the Lambda.
- **GitHub OIDC** — provider + keyless deploy role.

## Usage

```hcl
provider "aws" {
  region = "eu-west-2"
}

module "computer_shop" {
  source = "git::https://github.com/MartinSG98/tf-module-computer_shop.git?ref=v0.1.0"

  project             = "computer-shop"
  cors_allow_origins  = "https://shop.example.com"
  github_deploy_repos = ["MartinSG98/computer-shop-backend"]
}
```

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| `project` | Name prefix for resources and tags | `computer-shop` |
| `cors_allow_origins` | Comma-separated CORS origins for the API | `""` |
| `github_deploy_repos` | Repos (owner/name) allowed to assume the deploy role (main branch) | `["MartinSG98/computer-shop-backend"]` |

## Outputs

`products_table_name`, `categories_table_name`, `images_bucket_name`,
`cdn_base_url`, `lambda_function_name`, `api_url`, `github_deploy_role_arn`.

## Notes

- Region comes from the **provider** configured by the caller, not a variable.
- Only one GitHub OIDC provider per account per URL — import an existing one.