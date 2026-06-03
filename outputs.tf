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

output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC (configure as a CI secret/var)."
  value       = aws_iam_role.github_deploy.arn
}