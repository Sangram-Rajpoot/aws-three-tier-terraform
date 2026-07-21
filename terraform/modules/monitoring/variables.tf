variable "name" { type = string }
variable "alarm_email" { type = string }
variable "public_alb_arn_suffix" { type = string }
variable "internal_alb_arn_suffix" { type = string }
variable "web_target_group_arn_suffix" { type = string }
variable "app_target_group_arn_suffix" { type = string }
variable "web_autoscaling_group_name" { type = string }
variable "app_autoscaling_group_name" { type = string }
variable "database_identifier" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
