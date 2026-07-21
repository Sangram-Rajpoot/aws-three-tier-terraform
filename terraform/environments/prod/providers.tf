provider "aws" {
  region = var.aws_region
  default_tags { tags = var.default_tags }
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region
  default_tags { tags = var.default_tags }
}

# AWS Global Accelerator API operations must use the us-west-2 control-plane endpoint.
# The accelerator remains a global service and points to the workload in var.aws_region.
provider "aws" {
  alias  = "global"
  region = "us-west-2"
  default_tags { tags = var.default_tags }
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }
}
