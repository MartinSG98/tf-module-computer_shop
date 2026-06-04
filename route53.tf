# The hosted zone is created automatically when the domain is registered in
# Route 53; we look it up rather than manage it here. Shared by the API and
# site custom-domain configs.
data "aws_route53_zone" "this" {
  count        = local.dns_enabled ? 1 : 0
  name         = var.hosted_zone_name
  private_zone = false
}