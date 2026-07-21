output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "backend_example" {
  value = <<-EOT
  terraform {
    backend "s3" {
      bucket       = "${aws_s3_bucket.state.id}"
      key          = "three-tier/dev/terraform.tfstate"
      region       = "${var.aws_region}"
      encrypt      = true
      use_lockfile = true
    }
  }
  EOT
}
