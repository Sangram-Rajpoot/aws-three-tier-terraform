terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

resource "aws_kms_key" "primary_backup" {
  description             = "Encrypt ${var.name} backups in the primary Region"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = merge(var.tags, { Name = "${var.name}-primary-backup" })
}

resource "aws_kms_alias" "primary_backup" {
  name          = "alias/${var.name}-primary-backup"
  target_key_id = aws_kms_key.primary_backup.key_id
}

resource "aws_kms_key" "dr_backup" {
  provider = aws.dr

  description             = "Encrypt ${var.name} backup copies in the DR Region"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = merge(var.tags, { Name = "${var.name}-dr-backup" })
}

resource "aws_kms_alias" "dr_backup" {
  provider = aws.dr

  name          = "alias/${var.name}-dr-backup"
  target_key_id = aws_kms_key.dr_backup.key_id
}

resource "aws_backup_vault" "primary" {
  name        = "${var.name}-primary-vault"
  kms_key_arn = aws_kms_key.primary_backup.arn
  tags        = var.tags
}

resource "aws_backup_vault" "dr" {
  provider = aws.dr

  name        = "${var.name}-dr-vault"
  kms_key_arn = aws_kms_key.dr_backup.arn
  tags        = var.tags
}

resource "aws_backup_plan" "main" {
  name = "${var.name}-rds-backup"

  rule {
    rule_name         = "daily-rds-backup"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 5 * * ? *)"
    start_window      = 60
    completion_window = 360

    lifecycle {
      delete_after = var.backup_retention_days
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn
      lifecycle {
        delete_after = var.dr_backup_retention_days
      }
    }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "assume_backup" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.assume_backup.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

data "aws_iam_policy_document" "backup_kms" {
  statement {
    sid = "UseBackupEncryptionKeys"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = [
      var.source_kms_key_arn,
      aws_kms_key.primary_backup.arn,
      aws_kms_key.dr_backup.arn,
    ]
  }

  statement {
    sid     = "CreateBackupKmsGrants"
    actions = ["kms:CreateGrant"]
    resources = [
      var.source_kms_key_arn,
      aws_kms_key.primary_backup.arn,
      aws_kms_key.dr_backup.arn,
    ]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "backup_kms" {
  name   = "${var.name}-backup-kms"
  role   = aws_iam_role.backup.id
  policy = data.aws_iam_policy_document.backup_kms.json
}

resource "aws_backup_selection" "rds" {
  name         = "${var.name}-rds-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.main.id
  resources    = [var.rds_arn]

  depends_on = [
    aws_iam_role_policy_attachment.backup,
    aws_iam_role_policy_attachment.restore,
    aws_iam_role_policy.backup_kms,
  ]
}
