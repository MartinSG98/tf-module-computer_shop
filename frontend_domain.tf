# Optional custom domain for the frontend site (e.g. msg-computers.com).
# Gated on local.site_domain_enabled. The CloudFront alias + certificate are
# attached to the existing frontend distribution in frontend.tf.

# CloudFront certificates MUST live in us-east-1, regardless of stack region.
resource "aws_acm_certificate" "site" {
  count             = local.site_domain_enabled ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = var.site_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "site_cert_validation" {
  for_each = local.site_domain_enabled ? {
    for dvo in aws_acm_certificate.site[0].domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "site" {
  count                   = local.site_domain_enabled ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site[0].arn
  validation_record_fqdns = [for r in aws_route53_record.site_cert_validation : r.fqdn]
}

# Point the apex domain at the frontend CloudFront distribution.
resource "aws_route53_record" "site_a" {
  count   = local.site_domain_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.site_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_aaaa" {
  count   = local.site_domain_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.site_domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}