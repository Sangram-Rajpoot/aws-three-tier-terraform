variable "project_name" {
  type    = string
  default = "taskflow"
}
variable "environment" { type = string }
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
variable "dr_region" {
  type    = string
  default = "ap-southeast-1"
}
variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
variable "single_nat_gateway" { type = bool }
variable "certificate_arn" {
  type    = string
  default = ""
}
variable "enable_deletion_protection" { type = bool }
variable "enable_global_accelerator" {
  type    = bool
  default = true
}
variable "hosted_zone_id" {
  type    = string
  default = ""
}
variable "domain_name" {
  type    = string
  default = ""
}
variable "web_instance_type" {
  type    = string
  default = "t3.micro"
}
variable "app_instance_type" {
  type    = string
  default = "t3.micro"
}
variable "web_min_size" { type = number }
variable "web_desired_capacity" { type = number }
variable "web_max_size" { type = number }
variable "app_min_size" { type = number }
variable "app_desired_capacity" { type = number }
variable "app_max_size" { type = number }
variable "database_name" {
  type    = string
  default = "taskflow"
}
variable "database_master_username" {
  type    = string
  default = "taskflowadmin"
}
variable "database_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "database_allocated_storage" {
  type    = number
  default = 20
}
variable "database_max_allocated_storage" {
  type    = number
  default = 100
}
variable "database_multi_az" {
  type    = bool
  default = true
}
variable "database_backup_retention_days" {
  type    = number
  default = 7
}
variable "database_deletion_protection" { type = bool }
variable "database_skip_final_snapshot" { type = bool }
variable "database_performance_insights" {
  type    = bool
  default = false
}
variable "database_apply_immediately" {
  type    = bool
  default = false
}
variable "dr_backup_retention_days" {
  type    = number
  default = 35
}
variable "artifact_bucket_force_destroy" { type = bool }
variable "alarm_email" {
  type    = string
  default = ""
}
variable "default_tags" {
  type    = map(string)
  default = {}
}
