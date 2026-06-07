# Build evaluator: a dedicated Lambda that scores a PC build 0-100 using an ONNX
# model stored in S3. Kept separate from the API Lambda so its ML dependencies
# (onnxruntime, numpy) don't bloat the main function. Reachable at POST /evaluate
# on the existing HTTP API. Code + model are deployed by the eval repo's CI.

# --- Model storage (versioned, so every upload is tracked by timestamp) ---
resource "aws_s3_bucket" "models" {
  bucket = "${var.project}-models-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket                  = aws_s3_bucket.models.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Execution role ---
resource "aws_iam_role" "eval_exec" {
  name               = "${var.project}-eval-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "eval_basic" {
  role       = aws_iam_role.eval_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read-only access to the model object (least privilege).
data "aws_iam_policy_document" "eval_model_read" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.models.arn}/*"]
  }
}

resource "aws_iam_role_policy" "eval_model_read" {
  name   = "${var.project}-eval-model-read"
  role   = aws_iam_role.eval_exec.id
  policy = data.aws_iam_policy_document.eval_model_read.json
}

# --- Function ---
resource "aws_cloudwatch_log_group" "eval" {
  name              = "/aws/lambda/${local.eval_function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "eval" {
  function_name = local.eval_function_name
  role          = aws_iam_role.eval_exec.arn
  # python3.12 runs on Amazon Linux 2023 (newer glibc), which the onnxruntime/
  # numpy wheels require. The API Lambda stays 3.11 (no native deps).
  runtime     = "python3.12"
  handler     = "app.handler.handler"
  timeout     = 30
  memory_size = 1024

  # Placeholder until the eval repo CI pushes the real (onnxruntime) package.
  filename         = data.archive_file.placeholder.output_path
  source_code_hash = data.archive_file.placeholder.output_base64sha256

  environment {
    variables = {
      MODEL_BUCKET   = aws_s3_bucket.models.bucket
      MODEL_KEY      = local.eval_model_key
      ALLOWED_ORIGIN = var.eval_allowed_origin
    }
  }

  depends_on = [aws_cloudwatch_log_group.eval]

  lifecycle {
    # Terraform owns config; CI/CD owns the code.
    ignore_changes = [filename, source_code_hash]
  }
}

# --- Route on the existing HTTP API: POST/OPTIONS /evaluate -> eval Lambda ---
resource "aws_apigatewayv2_integration" "eval" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.eval.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "eval_post" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /evaluate"
  target    = "integrations/${aws_apigatewayv2_integration.eval.id}"
}

# Preflight: the handler returns CORS headers for OPTIONS.
resource "aws_apigatewayv2_route" "eval_options" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "OPTIONS /evaluate"
  target    = "integrations/${aws_apigatewayv2_integration.eval.id}"
}

resource "aws_lambda_permission" "apigw_eval" {
  statement_id  = "AllowAPIGatewayInvokeEval"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.eval.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}