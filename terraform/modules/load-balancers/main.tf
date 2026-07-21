resource "aws_lb" "public" {
  name                       = substr("${var.name}-public", 0, 32)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.public_alb_security_group_id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.deletion_protection
  drop_invalid_header_fields = true
  idle_timeout               = 60
  tags                       = merge(var.tags, { Name = "${var.name}-public-alb" })
}

resource "aws_lb_target_group" "web" {
  name        = substr("${var.name}-web", 0, 32)
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 20
    timeout             = 5
    path                = "/health.html"
    matcher             = "200"
  }

  deregistration_delay = 30
  tags                 = merge(var.tags, { Name = "${var.name}-web-tg" })
}

resource "aws_lb_listener" "public_http_forward" {
  count = var.https_enabled ? 0 : 1

  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "public_http_redirect" {
  count = var.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "public_https" {
  count = var.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb" "internal" {
  name                       = substr("${var.name}-internal", 0, 32)
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [var.internal_alb_security_group_id]
  subnets                    = var.app_subnet_ids
  enable_deletion_protection = var.deletion_protection
  drop_invalid_header_fields = true
  idle_timeout               = 60
  tags                       = merge(var.tags, { Name = "${var.name}-internal-alb" })
}

resource "aws_lb_target_group" "app" {
  name        = substr("${var.name}-app", 0, 32)
  port        = 8000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 20
    timeout             = 5
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30
  tags                 = merge(var.tags, { Name = "${var.name}-app-tg" })
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
