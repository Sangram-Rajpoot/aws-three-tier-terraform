variable "name" { type = string }
variable "frontend_source_dir" { type = string }
variable "backend_source_dir" { type = string }
variable "force_destroy" { type = bool }
variable "tags" {
  type    = map(string)
  default = {}
}
