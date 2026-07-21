module "platform" {
  source = "../../stacks/three-tier"
  providers = {
    aws        = aws
    aws.dr     = aws.dr
    aws.global = aws.global
  }

  project_name                   = var.project_name
  environment                    = var.environment
  aws_region                     = var.aws_region
  vpc_cidr                       = var.vpc_cidr
  availability_zones             = slice(data.aws_availability_zones.available.names, 0, 2)
  single_nat_gateway             = var.single_nat_gateway
  frontend_source_dir            = abspath("${path.root}/../../../application/frontend")
  backend_source_dir             = abspath("${path.root}/../../../application/backend")
  artifact_bucket_force_destroy  = var.artifact_bucket_force_destroy
  certificate_arn                = var.certificate_arn
  enable_deletion_protection     = var.enable_deletion_protection
  enable_global_accelerator      = var.enable_global_accelerator
  hosted_zone_id                 = var.hosted_zone_id
  domain_name                    = var.domain_name
  web_instance_type              = var.web_instance_type
  app_instance_type              = var.app_instance_type
  web_min_size                   = var.web_min_size
  web_desired_capacity           = var.web_desired_capacity
  web_max_size                   = var.web_max_size
  app_min_size                   = var.app_min_size
  app_desired_capacity           = var.app_desired_capacity
  app_max_size                   = var.app_max_size
  database_name                  = var.database_name
  database_master_username       = var.database_master_username
  database_instance_class        = var.database_instance_class
  database_allocated_storage     = var.database_allocated_storage
  database_max_allocated_storage = var.database_max_allocated_storage
  database_multi_az              = var.database_multi_az
  database_backup_retention_days = var.database_backup_retention_days
  database_deletion_protection   = var.database_deletion_protection
  database_skip_final_snapshot   = var.database_skip_final_snapshot
  database_performance_insights  = var.database_performance_insights
  database_apply_immediately     = var.database_apply_immediately
  dr_backup_retention_days       = var.dr_backup_retention_days
  alarm_email                    = var.alarm_email
  additional_tags                = var.default_tags
}
