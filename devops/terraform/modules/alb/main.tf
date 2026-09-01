# 1. Public Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets

  drop_invalid_header_fields = true # DevSecOps: Mitigate HTTP desync/smuggling attacks

  tags = {
    Name = "${var.project_name}-alb-${var.environment}"
  }
}

# 2. Target Group for Backend API Services
resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-backend-tg-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/" # Or verify your Express health endpoint
    port                = "8080"
    protocol            = "HTTP"
    matcher             = "200-399,404" # Prevents task teardown while routes initialize
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# 3. Target Group for Frontend UI
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-frontend-tg-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for ECS Fargate

  health_check {
    enabled             = true
    path                = "/"
    port                = "8080"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# 4. HTTP Listener (Port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action: route standard traffic to the Frontend target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# 5. Listener Rule: Route /api/* to the Backend API Target Group
resource "aws_lb_listener_rule" "api_routing" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/api"]
    }
  }
}