locals {
  name = "${var.project_name}-${var.environment}"
  tags = merge(var.additional_tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  dns_enabled   = var.hosted_zone_id != "" && var.domain_name != ""
  https_enabled = var.certificate_arn != "" || (var.hosted_zone_id != "" && var.domain_name != "")
}

module "network" {
  source = "../../modules/network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway
  tags               = local.tags
}

module "security" {
  source = "../../modules/security"

  name          = local.name
  vpc_id        = module.network.vpc_id
  https_enabled = local.https_enabled
  tags          = local.tags
}

module "database" {
  source = "../../modules/database"

  name                         = local.name
  subnet_ids                   = module.network.database_subnet_ids
  security_group_id            = module.security.database_security_group_id
  database_name                = var.database_name
  master_username              = var.database_master_username
  instance_class               = var.database_instance_class
  allocated_storage            = var.database_allocated_storage
  max_allocated_storage        = var.database_max_allocated_storage
  multi_az                     = var.database_multi_az
  backup_retention_days        = var.database_backup_retention_days
  deletion_protection          = var.database_deletion_protection
  skip_final_snapshot          = var.database_skip_final_snapshot
  performance_insights_enabled = var.database_performance_insights
  apply_immediately            = var.database_apply_immediately
  tags                         = local.tags
}

module "artifacts" {
  source = "../../modules/artifacts"

  name                = local.name
  frontend_source_dir = var.frontend_source_dir
  backend_source_dir  = var.backend_source_dir
  force_destroy       = var.artifact_bucket_force_destroy
  tags                = local.tags
}


module "certificate" {
  source = "../../modules/certificate"

  enabled        = local.dns_enabled && var.certificate_arn == ""
  hosted_zone_id = var.hosted_zone_id
  domain_name    = var.domain_name
  tags           = local.tags
}

locals {
  effective_certificate_arn = var.certificate_arn != "" ? var.certificate_arn : (module.certificate.certificate_arn != null ? module.certificate.certificate_arn : "")
}

module "load_balancers" {
  source = "../../modules/load-balancers"

  name                           = local.name
  vpc_id                         = module.network.vpc_id
  public_subnet_ids              = module.network.public_subnet_ids
  app_subnet_ids                 = module.network.app_subnet_ids
  public_alb_security_group_id   = module.security.public_alb_security_group_id
  internal_alb_security_group_id = module.security.internal_alb_security_group_id
  certificate_arn                = local.effective_certificate_arn
  https_enabled                  = local.https_enabled
  deletion_protection            = var.enable_deletion_protection
  tags                           = local.tags
}

module "compute" {
  source = "../../modules/compute"

  name                  = local.name
  aws_region            = var.aws_region
  web_subnet_ids        = module.network.web_subnet_ids
  app_subnet_ids        = module.network.app_subnet_ids
  web_security_group_id = module.security.web_security_group_id
  app_security_group_id = module.security.app_security_group_id
  web_target_group_arn  = module.load_balancers.web_target_group_arn
  app_target_group_arn  = module.load_balancers.app_target_group_arn
  internal_alb_dns_name = module.load_balancers.internal_alb_dns_name
  artifact_bucket_name  = module.artifacts.bucket_name
  artifact_bucket_arn   = module.artifacts.bucket_arn
  frontend_key          = module.artifacts.frontend_key
  frontend_version      = module.artifacts.frontend_version
  backend_key           = module.artifacts.backend_key
  backend_version       = module.artifacts.backend_version
  database_secret_arn   = module.database.secret_arn
  database_host         = module.database.address
  database_port         = module.database.port
  database_name         = var.database_name
  web_instance_type     = var.web_instance_type
  app_instance_type     = var.app_instance_type
  web_min_size          = var.web_min_size
  web_desired_capacity  = var.web_desired_capacity
  web_max_size          = var.web_max_size
  app_min_size          = var.app_min_size
  app_desired_capacity  = var.app_desired_capacity
  app_max_size          = var.app_max_size
  tags                  = local.tags
}

module "global_accelerator" {
  source = "../../modules/global-accelerator"
  providers = {
    aws = aws.global
  }

  name           = local.name
  enabled        = var.enable_global_accelerator
  public_alb_arn = module.load_balancers.public_alb_arn
  aws_region     = var.aws_region
  listener_ports = local.https_enabled ? [80, 443] : [80]
  tags           = local.tags
}

module "dns" {
  source = "../../modules/dns"

  enabled                     = local.dns_enabled
  hosted_zone_id              = var.hosted_zone_id
  domain_name                 = var.domain_name
  global_accelerator_enabled  = var.enable_global_accelerator
  global_accelerator_dns_name = module.global_accelerator.dns_name
  global_accelerator_zone_id  = module.global_accelerator.hosted_zone_id
  public_alb_dns_name         = module.load_balancers.public_alb_dns_name
  public_alb_zone_id          = module.load_balancers.public_alb_zone_id
}

module "backup" {
  source = "../../modules/backup"
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  name                     = local.name
  rds_arn                  = module.database.arn
  source_kms_key_arn       = module.database.kms_key_arn
  backup_retention_days    = var.database_backup_retention_days
  dr_backup_retention_days = var.dr_backup_retention_days
  tags                     = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                        = local.name
  alarm_email                 = var.alarm_email
  public_alb_arn_suffix       = module.load_balancers.public_alb_arn_suffix
  internal_alb_arn_suffix     = module.load_balancers.internal_alb_arn_suffix
  web_target_group_arn_suffix = module.load_balancers.web_target_group_arn_suffix
  app_target_group_arn_suffix = module.load_balancers.app_target_group_arn_suffix
  web_autoscaling_group_name  = module.compute.web_autoscaling_group_name
  app_autoscaling_group_name  = module.compute.app_autoscaling_group_name
  database_identifier         = module.database.identifier
  tags                        = local.tags
}
