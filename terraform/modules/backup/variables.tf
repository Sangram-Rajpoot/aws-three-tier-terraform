variable "name" { type = string }
variable "rds_arn" { type = string }
variable "source_kms_key_arn" { type = string }
variable "backup_retention_days" { type = number }
variable "dr_backup_retention_days" { type = number }
variable "tags" {
  type    = map(string)
  default = {}
}
