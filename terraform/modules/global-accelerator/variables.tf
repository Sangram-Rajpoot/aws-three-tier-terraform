variable "name" { type = string }
variable "enabled" { type = bool }
variable "public_alb_arn" { type = string }
variable "aws_region" { type = string }
variable "listener_ports" { type = list(number) }
variable "tags" {
  type    = map(string)
  default = {}
}
