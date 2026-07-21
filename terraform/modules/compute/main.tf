data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${var.name}-web-instances"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-app-instances"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "web_artifact_access" {
  statement {
    sid       = "ReadFrontendArtifact"
    actions   = ["s3:GetObject"]
    resources = ["${var.artifact_bucket_arn}/${var.frontend_key}"]
  }

  statement {
    sid       = "ReadArtifactBucketLocation"
    actions   = ["s3:GetBucketLocation"]
    resources = [var.artifact_bucket_arn]
  }
}

data "aws_iam_policy_document" "app_access" {
  statement {
    sid       = "ReadBackendArtifact"
    actions   = ["s3:GetObject"]
    resources = ["${var.artifact_bucket_arn}/${var.backend_key}"]
  }

  statement {
    sid       = "ReadArtifactBucketLocation"
    actions   = ["s3:GetBucketLocation"]
    resources = [var.artifact_bucket_arn]
  }

  statement {
    sid       = "ReadDatabaseSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.database_secret_arn]
  }
}

resource "aws_iam_role_policy" "web_artifact_access" {
  name   = "${var.name}-frontend-artifact"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web_artifact_access.json
}

resource "aws_iam_role_policy" "app_access" {
  name   = "${var.name}-backend-and-database"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_access.json
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.name}-web-instances"
  role = aws_iam_role.web.name
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app-instances"
  role = aws_iam_role.app.name
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.name}-web-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.web_instance_type
  user_data = base64encode(templatefile("${path.module}/templates/web-user-data.sh.tftpl", {
    aws_region       = var.aws_region
    artifact_bucket  = var.artifact_bucket_name
    artifact_key     = var.frontend_key
    artifact_version = var.frontend_version
    internal_alb_dns = var.internal_alb_dns_name
  }))

  iam_instance_profile { name = aws_iam_instance_profile.web.name }
  vpc_security_group_ids = [var.web_security_group_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 16
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring { enabled = true }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-web", Tier = "web" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-web" })
  }

  update_default_version = true
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.name}-web"
  min_size                  = var.web_min_size
  desired_capacity          = var.web_desired_capacity
  max_size                  = var.web_max_size
  vpc_zone_identifier       = var.web_subnet_ids
  target_group_arns         = [var.web_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 180

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 180
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-web", Tier = "web" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_autoscaling_policy" "web_cpu" {
  name                   = "${var.name}-web-cpu"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification { predefined_metric_type = "ASGAverageCPUUtilization" }
    target_value = 60
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.app_instance_type
  user_data = base64encode(templatefile("${path.module}/templates/app-user-data.sh.tftpl", {
    aws_region       = var.aws_region
    artifact_bucket  = var.artifact_bucket_name
    artifact_key     = var.backend_key
    artifact_version = var.backend_version
    database_secret  = var.database_secret_arn
    database_host    = var.database_host
    database_port    = var.database_port
    database_name    = var.database_name
  }))

  iam_instance_profile { name = aws_iam_instance_profile.app.name }
  vpc_security_group_ids = [var.app_security_group_id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring { enabled = true }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app", Tier = "application" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }

  update_default_version = true
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.name}-app"
  min_size                  = var.app_min_size
  desired_capacity          = var.app_desired_capacity
  max_size                  = var.app_max_size
  vpc_zone_identifier       = var.app_subnet_ids
  target_group_arns         = [var.app_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 420
  default_instance_warmup   = 240

  launch_template {
    id      = aws_launch_template.app.id
    version = tostring(aws_launch_template.app.latest_version)
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 240
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-app", Tier = "application" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_autoscaling_policy" "app_cpu" {
  name                   = "${var.name}-app-cpu"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification { predefined_metric_type = "ASGAverageCPUUtilization" }
    target_value = 60
  }
}
