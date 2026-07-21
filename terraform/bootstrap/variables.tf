variable "project_name" {
  type    = string
  default = "taskflow"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "bucket_name" {
  type        = string
  default     = ""
  description = "Optional fixed state bucket name. Leave blank to generate a globally unique name."
}
