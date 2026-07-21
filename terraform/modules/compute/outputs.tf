output "web_autoscaling_group_name" { value = aws_autoscaling_group.web.name }
output "app_autoscaling_group_name" { value = aws_autoscaling_group.app.name }
output "web_instance_role_arn" { value = aws_iam_role.web.arn }
output "app_instance_role_arn" { value = aws_iam_role.app.arn }
