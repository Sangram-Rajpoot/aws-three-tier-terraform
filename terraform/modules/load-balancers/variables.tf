variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_subnet_ids" { type = list(string) }
variable "public_alb_security_group_id" { type = string }
variable "internal_alb_security_group_id" { type = string }
variable "certificate_arn" { type = string }
variable "https_enabled" { type = bool }
variable "deletion_protection" { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
