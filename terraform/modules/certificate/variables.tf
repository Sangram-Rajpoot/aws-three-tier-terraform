variable "enabled" { type = bool }
variable "hosted_zone_id" { type = string }
variable "domain_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
