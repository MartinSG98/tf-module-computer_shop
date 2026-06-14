output "products_table_name" {
  description = "Name of the products DynamoDB table."
  value       = aws_dynamodb_table.products.name
}

output "categories_table_name" {
  description = "Name of the categories DynamoDB table."
  value       = aws_dynamodb_table.categories.name
}

output "images_bucket_name" {
  description = "Name of the S3 bucket holding product images."
  value       = aws_s3_bucket.images.bucket
}

output "frontend_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend SPA."
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_url" {
  description = "CloudFront URL of the frontend app."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "site_custom_domain_url" {
  description = "Custom domain URL of the site (null if no custom domain is configured)."
  value       = local.site_domain_enabled ? "https://${var.site_domain_name}" : null
}

output "frontend_distribution_id" {
  description = "CloudFront distribution ID for the frontend (for cache invalidation)."
  value       = aws_cloudfront_distribution.frontend.id
}

output "github_frontend_deploy_role_arn" {
  description = "IAM role ARN for the frontend GitHub Actions to assume via OIDC."
  value       = aws_iam_role.github_frontend_deploy.arn
}

output "cdn_base_url" {
  description = "CloudFront base URL for product images (use as CDN_BASE_URL)."
  value       = "https://${aws_cloudfront_distribution.images.domain_name}"
}

output "lambda_function_name" {
  description = "Lambda function name (target for CI/CD update-function-code)."
  value       = aws_lambda_function.api.function_name
}

output "api_url" {
  description = "Base invoke URL of the HTTP API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_custom_domain_url" {
  description = "Custom domain URL of the API (null if no custom domain is configured)."
  value       = local.api_domain_enabled ? "https://${var.api_domain_name}" : null
}

output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC (configure as a CI secret/var)."
  value       = aws_iam_role.github_deploy.arn
}

output "eval_lambda_function_name" {
  description = "Build-evaluator Lambda name (target for the eval repo's update-function-code)."
  value       = aws_lambda_function.eval.function_name
}

output "models_bucket_name" {
  description = "S3 bucket holding the evaluator model (upload model.onnx to the build-eval/ prefix)."
  value       = aws_s3_bucket.models.bucket
}

output "eval_model_key" {
  description = "S3 key the evaluator Lambda loads the model from."
  value       = local.eval_model_key
}

output "github_eval_deploy_role_arn" {
  description = "IAM role ARN for the build-evaluator CI to assume via OIDC."
  value       = aws_iam_role.github_eval_deploy.arn
}

output "agent_runtime_arn" {
  description = "AgentCore runtime ARN of the support agent (used by callers to invoke it)."
  value       = aws_bedrockagentcore_agent_runtime.support_agent.agent_runtime_arn
}

output "agent_runtime_id" {
  description = "AgentCore runtime id of the support agent (target for CI's update-agent-runtime)."
  value       = aws_bedrockagentcore_agent_runtime.support_agent.agent_runtime_id
}

output "agent_artifacts_bucket_name" {
  description = "S3 bucket the support-agent CI uploads the code zip to."
  value       = aws_s3_bucket.agent_artifacts.bucket
}

output "agent_code_key" {
  description = "S3 key of the support-agent code zip."
  value       = local.agent_code_key
}

output "github_agent_deploy_role_arn" {
  description = "IAM role ARN for the support-agent CI to assume via OIDC."
  value       = aws_iam_role.github_agent_deploy.arn
}

output "eval_url" {
  description = "Build-evaluator endpoint (POST)."
  value       = "${aws_apigatewayv2_stage.default.invoke_url}evaluate"
}

output "cognito_user_pool_id" {
  description = "Cognito user pool id (for the frontend auth config)."
  value       = aws_cognito_user_pool.main.id
}

output "cognito_app_client_id" {
  description = "Cognito app client id used by the frontend SPA (also the JWT audience)."
  value       = aws_cognito_user_pool_client.app.id
}

output "cognito_region" {
  description = "Region the Cognito user pool lives in (for the frontend auth config)."
  value       = data.aws_region.current.name
}