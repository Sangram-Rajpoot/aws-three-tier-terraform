variable "project_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "project_name must use lowercase letters, numbers, and hyphens, and cannot start or end with a hyphen."
  }
}
variable "environment" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.environment))
    error_message = "environment must use lowercase letters, numbers, and hyphens."
  }
}
variable "aws_region" { type = string }
variable "vpc_cidr" { type = string }
variable "availability_zones" { type = list(string) }
variable "single_nat_gateway" { type = bool }
variable "frontend_source_dir" { type = string }
variable "backend_source_dir" { type = string }
variable "artifact_bucket_force_destroy" { type = bool }
variable "certificate_arn" { type = string }
variable "enable_deletion_protection" { type = bool }
variable "enable_global_accelerator" { type = bool }
variable "hosted_zone_id" { type = string }
variable "domain_name" { type = string }
variable "web_instance_type" { type = string }
variable "app_instance_type" { type = string }
variable "web_min_size" { type = number }
variable "web_desired_capacity" { type = number }
variable "web_max_size" { type = number }
variable "app_min_size" { type = number }
variable "app_desired_capacity" { type = number }
variable "app_max_size" { type = number }
variable "database_name" {
  type = string
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,63}$", var.database_name))
    error_message = "database_name must start with a letter and contain only letters, numbers, or underscores."
  }
}
variable "database_master_username" {
  type = string
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,15}$", var.database_master_username))
    error_message = "database_master_username must start with a letter, contain only letters and numbers, and be at most 16 characters."
  }
}
variable "database_instance_class" { type = string }
variable "database_allocated_storage" { type = number }
variable "database_max_allocated_storage" { type = number }
variable "database_multi_az" { type = bool }
variable "database_backup_retention_days" { type = number }
variable "database_deletion_protection" { type = bool }
variable "database_skip_final_snapshot" { type = bool }
variable "database_performance_insights" { type = bool }
variable "database_apply_immediately" { type = bool }
variable "dr_backup_retention_days" { type = number }
variable "alarm_email" { type = string }
variable "additional_tags" {
  type    = map(string)
  default = {}
}
