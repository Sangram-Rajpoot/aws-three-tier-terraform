output "public_alb_dns_name" { value = module.platform.public_alb_dns_name }
output "global_accelerator_dns_name" { value = module.platform.global_accelerator_dns_name }
output "global_accelerator_static_ips" { value = module.platform.global_accelerator_static_ips }
output "domain_name" { value = module.platform.domain_name }
output "database_endpoint" { value = module.platform.database_endpoint }
output "database_secret_arn" {
  value     = module.platform.database_secret_arn
  sensitive = true
}
output "artifact_bucket_name" { value = module.platform.artifact_bucket_name }
output "backup_primary_vault" { value = module.platform.backup_primary_vault }
output "backup_dr_vault_arn" { value = module.platform.backup_dr_vault_arn }
output "sns_topic_arn" { value = module.platform.sns_topic_arn }
