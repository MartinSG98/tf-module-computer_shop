# tf-module-computer_shop

Reusable Terraform **module** for the Computer Shop backend infrastructure on AWS.

This module declares resources only — it does **not** configure a provider or a
backend. A root **stack** (see `tf-stack-computer_shop`) configures the AWS
provider (region, tags) and state, then calls this module.

## Resources

- **DynamoDB** — `products` and `categories` tables (free-tier provisioned 5/5).
- **S3 + CloudFront** — private images bucket served via CloudFront (OAC).
- **Frontend hosting** — private S3 bucket + a separate CloudFront distribution
  for the SPA (default root `index.html`, 403/404 → `index.html` for routing).
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
| `api_throttle_rate_limit` | Steady-state requests/sec cap across all routes | `20` |
| `api_throttle_burst_limit` | Max burst of concurrent requests | `40` |

## Outputs

`products_table_name`, `categories_table_name`, `images_bucket_name`,
`cdn_base_url`, `frontend_bucket_name`, `frontend_url`, `lambda_function_name`,
`api_url`, `github_deploy_role_arn`.

## API protection

The API Gateway stage has **rate limiting** (`default_route_settings` throttling),
not an authorizer. This is deliberate:

- The catalog endpoints (`GET /products`, `/categories`) are a **public
  storefront** — product listings are meant to be readable by anyone, so there
  is nothing to authenticate. Adding auth here would gate data that should be
  open.
- The real risk on a public read API is **abuse / runaway cost** (scraping,
  hammering), which **throttling** addresses directly by capping requests/sec and
  burst. That's the right tool for this threat, and it's cheap.
- **Authentication is deferred until there's something to protect** — i.e. when
  we add write/admin endpoints (creating products, the presigned image upload) or
  user features (cart, orders). At that point we attach a **Cognito JWT
  authorizer** to *those routes only* (HTTP API supports this natively) and leave
  the catalog reads public.

So: throttling now (fits a public catalog), auth later (scoped to non-public
routes), rather than bolting on user auth the app doesn't yet have.

## Notes

- Region comes from the **provider** configured by the caller, not a variable.
- Only one GitHub OIDC provider per account per URL — import an existing one.