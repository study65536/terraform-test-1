resource "aws_lb" "this" {
  name                       = var.name
  load_balancer_type         = "application"
  internal                   = var.internal
  subnets                    = var.subnet_ids
  security_groups            = var.security_group_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection
  tags                       = merge(var.tags, { Name = var.name })

  dynamic "access_logs" {
    for_each = var.access_logs[*]
    content {
      bucket  = access_logs.value.bucket
      prefix  = access_logs.value.prefix
      enabled = true
    }
  }
}

resource "aws_lb_target_group" "this" {
  name_prefix = "app-"
  port        = var.target_port
  protocol    = var.target_protocol
  target_type = "instance"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = var.name })

  health_check {
    enabled  = true
    path     = var.health_check_path
    protocol = var.target_protocol
    matcher  = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each         = var.targets
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = each.value
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
  tags              = var.tags

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener" "redirect" {
  count             = var.enable_http_redirect ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  tags              = var.tags

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
