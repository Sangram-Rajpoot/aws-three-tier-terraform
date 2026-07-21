output "public_alb_dns_name" { value = module.load_balancers.public_alb_dns_name }
output "global_accelerator_dns_name" { value = module.global_accelerator.dns_name }
output "global_accelerator_static_ips" { value = module.global_accelerator.static_ips }
output "domain_name" { value = module.dns.fqdn }
output "database_endpoint" { value = module.database.address }
output "database_secret_arn" {
  value     = module.database.secret_arn
  sensitive = true
}
output "artifact_bucket_name" { value = module.artifacts.bucket_name }
output "backup_primary_vault" { value = module.backup.primary_vault_name }
output "backup_dr_vault_arn" { value = module.backup.dr_vault_arn }
output "sns_topic_arn" { value = module.monitoring.sns_topic_arn }
