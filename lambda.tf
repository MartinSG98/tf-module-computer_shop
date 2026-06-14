# --- Execution role -----------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# CloudWatch Logs (write log streams/events).
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Least privilege: read-only on the catalog tables, read + write on orders
# (checkout writes, the admin dashboard reads).
data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.products.arn,
      aws_dynamodb_table.categories.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:PutItem",
    ]
    resources = [aws_dynamodb_table.orders.arn]
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "${var.project}-lambda-dynamodb-read"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_dynamodb.json
}

# Invoke the support agent (chat route proxies to AgentCore). The /* covers
# the runtime's endpoint/version sub-resources that invocations resolve to.
data "aws_iam_policy_document" "lambda_agent_invoke" {
  statement {
    effect  = "Allow"
    actions = ["bedrock-agentcore:InvokeAgentRuntime"]
    resources = [
      aws_bedrockagentcore_agent_runtime.support_agent.agent_runtime_arn,
      "${aws_bedrockagentcore_agent_runtime.support_agent.agent_runtime_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda_agent_invoke" {
  name   = "${var.project}-lambda-agent-invoke"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_agent_invoke.json
}

# --- Function -----------------------------------------------------------------

# Log group owned by Terraform so retention is set (Lambda would otherwise
# auto-create it with never-expire).
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = 14
}

# Placeholder package so the function can be created. CI/CD in the backend repo
# pushes the real code via update-function-code; see ignore_changes below.
data "archive_file" "placeholder" {
  type        = "zip"
  output_path = "${path.module}/build/placeholder.zip"
  source {
    content  = "def handler(event, context):\n    return {'statusCode': 503, 'body': 'Not deployed yet'}\n"
    filename = "placeholder.py"
  }
}

resource "aws_lambda_function" "api" {
  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.11"
  handler       = "app.lambda_handler.handler"
  # 30s matches the API Gateway integration cap; the chat route blocks on the
  # support agent, whose cold first message can exceed the old 15s.
  timeout     = 30
  memory_size = 512

  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      PRODUCTS_TABLE     = aws_dynamodb_table.products.name
      CATEGORIES_TABLE   = aws_dynamodb_table.categories.name
      ORDERS_TABLE       = aws_dynamodb_table.orders.name
      CDN_BASE_URL       = "https://${aws_cloudfront_distribution.images.domain_name}"
      CORS_ALLOW_ORIGINS = local.api_cors_origins
      AGENT_RUNTIME_ARN  = aws_bedrockagentcore_agent_runtime.support_agent.agent_runtime_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  lifecycle {
    # Terraform owns config (role, env, runtime); CI/CD owns the code.
    ignore_changes = [filename, source_code_hash]
  }
}