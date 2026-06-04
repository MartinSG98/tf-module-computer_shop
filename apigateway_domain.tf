# Optional custom domain for the HTTP API (e.g. api.msg-computers.com).
# All resources are gated on local.api_domain_enabled so the module still
# works with just the default *.execute-api URL when no domain is set.

# Regional cert in the API's own region (eu-west-2) — API Gateway custom
# domains require the cert in the same region, not us-east-1.
resource "aws_acm_certificate" "api" {
  count             = local.api_domain_enabled ? 1 : 0
  domain_name       = var.api_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "api_cert_validation" {
  for_each = local.api_domain_enabled ? {
    for dvo in aws_acm_certificate.api[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id         = data.aws_route53_zone.this[0].zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api" {
  count                   = local.api_domain_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.api[0].arn
  validation_record_fqdns = [for r in aws_route53_record.api_cert_validation : r.fqdn]
}

resource "aws_apigatewayv2_domain_name" "api" {
  count       = local.api_domain_enabled ? 1 : 0
  domain_name = var.api_domain_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api[0].certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

# Map the custom domain (root path) to the $default stage.
resource "aws_apigatewayv2_api_mapping" "api" {
  count       = local.api_domain_enabled ? 1 : 0
  api_id      = aws_apigatewayv2_api.http.id
  domain_name = aws_apigatewayv2_domain_name.api[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

# Alias the custom domain at the API Gateway regional endpoint (free queries).
resource "aws_route53_record" "api" {
  count   = local.api_domain_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.api_domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}