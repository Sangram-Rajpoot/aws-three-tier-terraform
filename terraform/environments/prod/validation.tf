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

    precondition {
      condition     = !var.single_nat_gateway
      error_message = "Production must use one NAT Gateway per Availability Zone."
    }

    precondition {
      condition     = var.web_min_size >= 2 && var.web_desired_capacity >= 2
      error_message = "Production web capacity must keep at least two instances."
    }

    precondition {
      condition     = var.app_min_size >= 2 && var.app_desired_capacity >= 2
      error_message = "Production application capacity must keep at least two instances."
    }

    precondition {
      condition     = var.database_multi_az
      error_message = "Production RDS must have Multi-AZ enabled."
    }

    precondition {
      condition     = var.enable_deletion_protection && var.database_deletion_protection
      error_message = "Production ALB and RDS deletion protection must be enabled."
    }

    precondition {
      condition     = !var.database_skip_final_snapshot
      error_message = "Production RDS must create a final snapshot during deletion."
    }

    precondition {
      condition     = !var.artifact_bucket_force_destroy
      error_message = "Production artifact buckets must not use force_destroy."
    }
  }
}
