resource "aws_security_group" "public_alb" {
  name        = "${var.name}-public-alb"
  description = "Internet traffic to the public ALB"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-public-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "public_http" {
  security_group_id = aws_security_group.public_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from the internet"
}

resource "aws_vpc_security_group_ingress_rule" "public_https" {
  count = var.https_enabled ? 1 : 0

  security_group_id = aws_security_group.public_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from the internet"
}

resource "aws_vpc_security_group_egress_rule" "public_alb_all" {
  security_group_id = aws_security_group.public_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "web" {
  name        = "${var.name}-web"
  description = "Web tier instances"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-web-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "web_from_public_alb" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.public_alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Nginx traffic from public ALB"
}

resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "internal_alb" {
  name        = "${var.name}-internal-alb"
  description = "Internal ALB between web and application tiers"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-internal-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_from_web" {
  security_group_id            = aws_security_group.internal_alb.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "API traffic from web tier"
}

resource "aws_vpc_security_group_egress_rule" "internal_alb_all" {
  security_group_id = aws_security_group.internal_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Application tier instances"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-app-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_internal_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.internal_alb.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  description                  = "Flask API traffic from internal ALB"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "database" {
  name        = "${var.name}-database"
  description = "RDS MySQL access from application tier only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-database-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "database_from_app" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "MySQL from application tier"
}

resource "aws_vpc_security_group_egress_rule" "database_all" {
  security_group_id = aws_security_group.database.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
