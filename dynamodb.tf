resource "aws_dynamodb_table" "products" {
  name         = "${var.project}-products"
  billing_mode = "PROVISIONED"
  hash_key     = "id"

  # 5/5 stays within the DynamoDB always-free tier (25 RCU + 25 WCU per account).
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "categories" {
  name         = "${var.project}-categories"
  billing_mode = "PROVISIONED"
  hash_key     = "slug"

  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "slug"
    type = "S"
  }
}