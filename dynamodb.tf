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

# Orders placed at checkout, and the source data for the admin sales tracker.
# 5/5 keeps the account total at 15/15 RCU/WCU, still inside the always-free
# 25/25 tier. Only the id is a key; the dashboard scans this small table and
# aggregates in-app rather than maintaining (and paying for) a date GSI.
resource "aws_dynamodb_table" "orders" {
  name         = "${var.project}-orders"
  billing_mode = "PROVISIONED"
  hash_key     = "id"

  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "id"
    type = "S"
  }
}