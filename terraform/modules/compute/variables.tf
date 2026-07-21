variable "name" { type = string }
variable "aws_region" { type = string }
variable "web_subnet_ids" { type = list(string) }
variable "app_subnet_ids" { type = list(string) }
variable "web_security_group_id" { type = string }
variable "app_security_group_id" { type = string }
variable "web_target_group_arn" { type = string }
variable "app_target_group_arn" { type = string }
variable "internal_alb_dns_name" { type = string }
variable "artifact_bucket_name" { type = string }
variable "artifact_bucket_arn" { type = string }
variable "frontend_key" { type = string }
variable "frontend_version" { type = string }
variable "backend_key" { type = string }
variable "backend_version" { type = string }
variable "database_secret_arn" {
  type      = string
  sensitive = true
}
variable "database_host" { type = string }
variable "database_port" { type = number }
variable "database_name" { type = string }
variable "web_instance_type" { type = string }
variable "app_instance_type" { type = string }
variable "web_min_size" { type = number }
variable "web_desired_capacity" { type = number }
variable "web_max_size" { type = number }
variable "app_min_size" { type = number }
variable "app_desired_capacity" { type = number }
variable "app_max_size" { type = number }
variable "tags" {
  type    = map(string)
  default = {}
}
