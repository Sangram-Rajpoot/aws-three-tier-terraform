resource "terraform_data" "environment_validation" {
  input = {
    aws_region = var.aws_region
    dr_region  = var.dr_region
  }

  lifecycle {
    precondition {
      condition     = var.aws_region != var.dr_region
      error_message = "dr_region must be different from aws_region."
    }
  }
}
