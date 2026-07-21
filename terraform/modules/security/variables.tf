variable "name" { type = string }
variable "vpc_id" { type = string }
variable "https_enabled" {
  type        = bool
  description = "Whether to allow internet HTTPS traffic to the public ALB."
}
variable "tags" {
  type    = map(string)
  default = {}
}
