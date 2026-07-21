resource "aws_globalaccelerator_accelerator" "main" {
  count = var.enabled ? 1 : 0

  name            = substr(var.name, 0, 64)
  ip_address_type = "IPV4"
  enabled         = true
  tags            = var.tags
}

resource "aws_globalaccelerator_listener" "main" {
  count = var.enabled ? 1 : 0

  accelerator_arn = aws_globalaccelerator_accelerator.main[0].id
  protocol        = "TCP"
  client_affinity = "NONE"

  dynamic "port_range" {
    for_each = toset(var.listener_ports)
    content {
      from_port = port_range.value
      to_port   = port_range.value
    }
  }
}

resource "aws_globalaccelerator_endpoint_group" "primary" {
  count = var.enabled ? 1 : 0

  listener_arn            = aws_globalaccelerator_listener.main[0].id
  endpoint_group_region   = var.aws_region
  traffic_dial_percentage = 100

  endpoint_configuration {
    endpoint_id                    = var.public_alb_arn
    client_ip_preservation_enabled = true
    weight                         = 100
  }
}
