output "primary_vault_name" { value = aws_backup_vault.primary.name }
output "dr_vault_arn" { value = aws_backup_vault.dr.arn }
output "primary_kms_key_arn" { value = aws_kms_key.primary_backup.arn }
output "dr_kms_key_arn" { value = aws_kms_key.dr_backup.arn }
