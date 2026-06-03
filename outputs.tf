output "products_table_name" {
  description = "Name of the products DynamoDB table."
  value       = aws_dynamodb_table.products.name
}

output "categories_table_name" {
  description = "Name of the categories DynamoDB table."
  value       = aws_dynamodb_table.categories.name
}