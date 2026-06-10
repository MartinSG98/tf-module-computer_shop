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
- **Build evaluator** — a dedicated Lambda (its own role, on `POST /evaluate`)
  that scores a PC build, with a versioned S3 bucket for the ONNX model. Its role
  can read the model from S3 and call one **Amazon Bedrock** model for build
  suggestions (`bedrock:InvokeModel`, scoped to `eval_suggest_model_id`).
- **GitHub OIDC** — provider + keyless deploy roles (backend: Lambda code;
  frontend: S3 sync + CloudFront invalidation; build evaluator: Lambda code +
  model upload).
- **Custom domains (optional)** — ACM certs, DNS validation, and Route 53 alias
  records for a custom API domain and/or site domain. Off unless configured.

## Usage

```hcl
provider "aws" {
  region = "eu-west-2"
}

# Required: CloudFront (site) ACM certificates must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "computer_shop" {
  source = "git::https://github.com/MartinSG98/tf-module-computer_shop.git?ref=v0.0.1"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project               = "computer-shop"
  github_deploy_repos   = ["MartinSG98/computer-shop-backend"]
  github_frontend_repos = ["MartinSG98/computer_shop_ui"]
  # cors_allow_origins = "https://shop.example.com"  # extra; frontend URL is always allowed

  # Optional custom domains (see "Custom domains" below):
  # api_domain_name  = "api.msg-computers.com"
  # site_domain_name = "msg-computers.com"
  # hosted_zone_name = "msg-computers.com"
}
```

The `aws.us_east_1` aliased provider is **always required** (it's a
`configuration_alias`), even when no custom domain is set.

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| `project` | Name prefix for resources and tags | `computer-shop` |
| `cors_allow_origins` | _Extra_ CORS origins beyond the frontend CloudFront URL (always allowed) | `""` |
| `github_deploy_repos` | Repos (owner/name) allowed to assume the **backend** deploy role (main branch) | `["MartinSG98/computer-shop-backend"]` |
| `github_frontend_repos` | Repos (owner/name) allowed to assume the **frontend** deploy role (main branch) | `["MartinSG98/computer_shop_ui"]` |
| `github_eval_repos` | Repos (owner/name) allowed to assume the **build-evaluator** deploy role (main branch) | `["MartinSG98/computer-shop-build-eval"]` |
| `github_agent_repos` | Repos (owner/name) allowed to assume the **support-agent** deploy role (main branch) | `["MartinSG98/computer-shop-support-agent"]` |
| `eval_allowed_origin` | `Access-Control-Allow-Origin` returned by the evaluator Lambda | `"*"` |
| `eval_suggest_model_id` | Bedrock model id the evaluator invokes for build suggestions (must be available on-demand in the region) | `"amazon.nova-lite-v1:0"` |
| `agent_model_id` | Bedrock model id the support agent invokes for chat (must be available on-demand in the region) | `"openai.gpt-oss-120b-1:0"` |
| `api_domain_name` | Custom domain for the API, e.g. `api.msg-computers.com`. Empty = default invoke URL only | `""` |
| `site_domain_name` | Custom domain for the site, e.g. `msg-computers.com`. Empty = default CloudFront URL only | `""` |
| `hosted_zone_name` | Route 53 public hosted zone the custom domains live in. Required when either domain is set | `""` |
| `api_throttle_rate_limit` | Steady-state requests/sec cap across all routes | `20` |
| `api_throttle_burst_limit` | Max burst of concurrent requests | `40` |

## Outputs

`products_table_name`, `categories_table_name`, `images_bucket_name`,
`cdn_base_url`, `frontend_bucket_name`, `frontend_url`,
`frontend_distribution_id`, `lambda_function_name`, `api_url`,
`api_custom_domain_url`, `site_custom_domain_url`,
`github_deploy_role_arn`, `github_frontend_deploy_role_arn`,
`eval_lambda_function_name`, `models_bucket_name`, `eval_model_key`,
`eval_url`, `github_eval_deploy_role_arn`, `agent_runtime_arn`,
`agent_runtime_id`, `agent_artifacts_bucket_name`, `agent_code_key`,
`github_agent_deploy_role_arn`.

(`api_custom_domain_url` / `site_custom_domain_url` are `null` when the
corresponding domain isn't configured.)

## Custom domains

Both are **opt-in** and independent — set `api_domain_name` and/or
`site_domain_name` (plus `hosted_zone_name`) to enable. With them empty the
module is a no-op and the stack keeps using the default `*.execute-api` /
`*.cloudfront.net` URLs.

When enabled, the module creates:

- An **ACM certificate** per domain with **DNS validation**. The API cert is
  regional (the stack's region, e.g. `eu-west-2`); the site cert is created in
  **us-east-1** via the `aws.us_east_1` provider, because CloudFront requires it.
  The site cert covers both the apex and `www` (the latter as a SAN on the same
  cert, so there is no second certificate).
- **Route 53 records** in the looked-up hosted zone: the cert-validation
  records, an `A` alias for the API → API Gateway, and `A`/`AAAA` aliases for both
  the site apex and `www` → CloudFront. Alias queries to AWS targets are free.
- The API custom domain + base-path mapping to the `$default` stage, and the
  site domain (apex + `www`) attached to the frontend CloudFront distribution
  (aliases + cert). Both serve the site; there is no www-to-apex redirect.

The site's `https://` origins (apex and `www`) are **added to the API's CORS
allow-list automatically** when `site_domain_name` is set — no need to also list
them in `cors_allow_origins`.

The **hosted zone is looked up, not created** (`data "aws_route53_zone"`).
Register the domain first (Route 53 → Registered domains, which auto-creates the
zone) — Terraform can't register domains.

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
- The `aws.us_east_1` provider is a required `configuration_alias` (for the
  CloudFront site cert) — callers must always pass it, even with no custom domain.
- Only one GitHub OIDC provider per account per URL — import an existing one.

## Related

Part of the Computer Shop project:

- [computer-shop-backend](https://github.com/MartinSG98/computer-shop-backend) — FastAPI backend API
- [computer_shop_ui](https://github.com/MartinSG98/computer_shop_ui) — React/Vite/Mantine frontend
- [computer-shop-build-eval](https://github.com/MartinSG98/computer-shop-build-eval) — PC build scorer + suggestions (eval Lambda)
- [computer-shop-support-agent](https://github.com/MartinSG98/computer-shop-support-agent) — customer support agent (Bedrock AgentCore Runtime)
- [tf-stack-computer_shop](https://github.com/MartinSG98/tf-stack-computer_shop) — Terraform deployment stack