terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr, aws.global]
    }
    archive = { source = "hashicorp/archive" }
    random  = { source = "hashicorp/random" }
  }
}
