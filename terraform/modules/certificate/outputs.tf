output "certificate_arn" {
  value = var.enabled ? aws_acm_certificate_validation.main[0].certificate_arn : null
}
