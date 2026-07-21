resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

locals {
  actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "public_alb_5xx" {
  alarm_name          = "${var.name}-public-alb-5xx"
  alarm_description   = "Public ALB is returning server errors"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.public_alb_arn_suffix }
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "web_unhealthy" {
  alarm_name          = "${var.name}-web-unhealthy-targets"
  alarm_description   = "Web target group has unhealthy targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"
  dimensions = {
    LoadBalancer = var.public_alb_arn_suffix
    TargetGroup  = var.web_target_group_arn_suffix
  }
  alarm_actions = local.actions
  ok_actions    = local.actions
  tags          = var.tags
}


resource "aws_cloudwatch_metric_alarm" "app_unhealthy" {
  alarm_name          = "${var.name}-app-unhealthy-targets"
  alarm_description   = "Application target group has unhealthy targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"
  dimensions = {
    LoadBalancer = var.internal_alb_arn_suffix
    TargetGroup  = var.app_target_group_arn_suffix
  }
  alarm_actions = local.actions
  ok_actions    = local.actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-high-cpu"
  alarm_description   = "RDS CPU is above 80 percent"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  dimensions          = { DBInstanceIdentifier = var.database_identifier }
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.name}-rds-low-storage"
  alarm_description   = "RDS free storage is below 5 GiB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 5368709120
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"
  dimensions          = { DBInstanceIdentifier = var.database_identifier }
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "web_cpu" {
  alarm_name          = "${var.name}-web-high-cpu"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  dimensions          = { AutoScalingGroupName = var.web_autoscaling_group_name }
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "app_cpu" {
  alarm_name          = "${var.name}-app-high-cpu"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  dimensions          = { AutoScalingGroupName = var.app_autoscaling_group_name }
  alarm_actions       = local.actions
  ok_actions          = local.actions
  tags                = var.tags
}
