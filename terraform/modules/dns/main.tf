resource "aws_route53_record" "accelerator" {
  count = var.enabled && var.global_accelerator_enabled ? 1 : 0

  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = var.global_accelerator_dns_name
    zone_id                = var.global_accelerator_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "alb" {
  count = var.enabled && !var.global_accelerator_enabled ? 1 : 0

  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = var.public_alb_dns_name
    zone_id                = var.public_alb_zone_id
    evaluate_target_health = true
  }
}
