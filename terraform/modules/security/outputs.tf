output "public_alb_security_group_id" { value = aws_security_group.public_alb.id }
output "web_security_group_id" { value = aws_security_group.web.id }
output "internal_alb_security_group_id" { value = aws_security_group.internal_alb.id }
output "app_security_group_id" { value = aws_security_group.app.id }
output "database_security_group_id" { value = aws_security_group.database.id }
