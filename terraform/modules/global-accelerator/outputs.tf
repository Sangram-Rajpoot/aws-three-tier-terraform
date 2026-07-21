output "dns_name" { value = var.enabled ? aws_globalaccelerator_accelerator.main[0].dns_name : null }
output "hosted_zone_id" { value = var.enabled ? aws_globalaccelerator_accelerator.main[0].hosted_zone_id : null }
output "static_ips" { value = var.enabled ? tolist(aws_globalaccelerator_accelerator.main[0].ip_sets)[0].ip_addresses : [] }
output "arn" { value = var.enabled ? aws_globalaccelerator_accelerator.main[0].id : null }
