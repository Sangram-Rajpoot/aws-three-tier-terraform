variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "database_name" { type = string }
variable "master_username" { type = string }
variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "max_allocated_storage" { type = number }
variable "multi_az" { type = bool }
variable "backup_retention_days" { type = number }
variable "deletion_protection" { type = bool }
variable "skip_final_snapshot" { type = bool }
variable "performance_insights_enabled" { type = bool }
variable "apply_immediately" { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
