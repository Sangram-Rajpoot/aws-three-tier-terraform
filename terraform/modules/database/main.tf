resource "random_id" "final_snapshot" {
  byte_length = 4
}

resource "aws_kms_key" "rds" {
  description             = "Encrypt ${var.name} RDS storage and snapshots"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = merge(var.tags, { Name = "${var.name}-rds" })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-db-subnets" })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.name}-mysql84"
  family = "mysql8.4"

  parameter {
    name         = "require_secure_transport"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "slow_query_log"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "long_query_time"
    value        = "2"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_output"
    value        = "FILE"
    apply_method = "immediate"
  }

  tags = merge(var.tags, { Name = "${var.name}-mysql84" })
}

resource "aws_db_instance" "main" {
  identifier = "${var.name}-mysql"

  engine         = "mysql"
  engine_version = "8.4"
  instance_class = var.instance_class

  parameter_group_name = aws_db_parameter_group.main.name

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name                     = var.database_name
  username                    = var.master_username
  manage_master_user_password = true
  port                        = 3306

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  backup_retention_period = var.backup_retention_days
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:03:30-sun:04:30"

  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately
  copy_tags_to_snapshot      = true

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  database_insights_mode          = "standard"
  performance_insights_enabled    = var.performance_insights_enabled

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-${random_id.final_snapshot.hex}"

  tags = merge(var.tags, { Name = "${var.name}-mysql" })
}
