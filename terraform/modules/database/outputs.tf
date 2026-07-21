output "identifier" { value = aws_db_instance.main.identifier }
output "arn" { value = aws_db_instance.main.arn }
output "address" { value = aws_db_instance.main.address }
output "port" { value = aws_db_instance.main.port }
output "secret_arn" {
  value     = aws_db_instance.main.master_user_secret[0].secret_arn
  sensitive = true
}

output "kms_key_arn" { value = aws_kms_key.rds.arn }
