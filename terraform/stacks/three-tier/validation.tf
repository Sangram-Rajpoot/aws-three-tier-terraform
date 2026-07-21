resource "terraform_data" "input_validation" {
  input = {
    availability_zones = var.availability_zones
    domain_name        = var.domain_name
    hosted_zone_id     = var.hosted_zone_id
  }

  lifecycle {
    precondition {
      condition     = length(var.availability_zones) >= 2
      error_message = "At least two Availability Zones are required for this architecture."
    }

    precondition {
      condition = (
        can(cidrsubnet(var.vpc_cidr, 8, 31)) &&
        try(
          tonumber(split("/", var.vpc_cidr)[1]) >= 16 &&
          tonumber(split("/", var.vpc_cidr)[1]) <= 20,
          false
        )
      )
      error_message = "vpc_cidr must be an IPv4 CIDR between /16 and /20; the examples use 10.20.0.0/16."
    }

    precondition {
      condition = (
        (var.hosted_zone_id == "" && var.domain_name == "") ||
        (var.hosted_zone_id != "" && var.domain_name != "")
      )
      error_message = "hosted_zone_id and domain_name must either both be empty or both be configured."
    }


    precondition {
      condition     = length("${var.project_name}-${var.environment}") <= 30
      error_message = "The combined project_name-environment value must not exceed 30 characters."
    }

    precondition {
      condition = (
        floor(var.web_min_size) == var.web_min_size &&
        floor(var.web_desired_capacity) == var.web_desired_capacity &&
        floor(var.web_max_size) == var.web_max_size &&
        floor(var.app_min_size) == var.app_min_size &&
        floor(var.app_desired_capacity) == var.app_desired_capacity &&
        floor(var.app_max_size) == var.app_max_size
      )
      error_message = "Auto Scaling capacities must be whole numbers."
    }

    precondition {
      condition = (
        var.web_min_size >= 0 &&
        var.web_min_size <= var.web_desired_capacity &&
        var.web_desired_capacity <= var.web_max_size
      )
      error_message = "Web capacity must satisfy 0 <= min_size <= desired_capacity <= max_size."
    }

    precondition {
      condition = (
        var.app_min_size >= 0 &&
        var.app_min_size <= var.app_desired_capacity &&
        var.app_desired_capacity <= var.app_max_size
      )
      error_message = "Application capacity must satisfy 0 <= min_size <= desired_capacity <= max_size."
    }

    precondition {
      condition     = var.database_backup_retention_days >= 1 && var.database_backup_retention_days <= 35
      error_message = "RDS backup retention must be between 1 and 35 days."
    }

    precondition {
      condition     = var.dr_backup_retention_days >= var.database_backup_retention_days
      error_message = "DR backup retention must be greater than or equal to primary backup retention."
    }

    precondition {
      condition = (
        var.database_allocated_storage > 0 &&
        var.database_max_allocated_storage >= var.database_allocated_storage
      )
      error_message = "database_max_allocated_storage must be greater than or equal to database_allocated_storage."
    }
  }
}
