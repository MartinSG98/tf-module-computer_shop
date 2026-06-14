resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"
  # CORS is handled by the FastAPI app (CORSMiddleware), not the gateway, to
  # avoid duplicated headers.
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Catch-all: every method/path proxies to the Lambda; FastAPI does the routing.
# This route stays unauthenticated so the storefront (products, categories,
# chat) remains public.
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Cognito JWT authorizer. Validates the bearer token's signature, issuer, and
# audience (the app client id). It does NOT check group membership; the backend
# reads cognito:groups to separate admins from normal users. The frontend must
# send the ID token, since only it carries the `aud` claim this checks against.
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.http.id
  name             = "${var.project}-cognito-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.app.id]
    issuer   = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  }
}

# Admin routes require a valid Cognito token. This more-specific route key takes
# precedence over $default for /admin/* paths, so only the admin surface is
# locked down while everything else stays open. Same Lambda integration:
# FastAPI routes /admin/* internally and enforces the admins group there.
resource "aws_apigatewayv2_route" "admin" {
  api_id             = aws_apigatewayv2_api.http.id
  route_key          = "ANY /admin/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# $default stage means clean URLs with no stage path prefix.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  # Caps abuse / runaway cost on the public read API. This is rate limiting,
  # not authentication — see the README ("API protection").
  default_route_settings {
    throttling_rate_limit  = var.api_throttle_rate_limit
    throttling_burst_limit = var.api_throttle_burst_limit
  }
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}