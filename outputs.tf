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

output "cdn_base_url" {
  description = "CloudFront base URL for product images (use as CDN_BASE_URL)."
  value       = "https://${aws_cloudfront_distribution.images.domain_name}"
}