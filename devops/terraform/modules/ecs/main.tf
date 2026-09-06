# 1. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# 2. CloudWatch Log Groups for Container Logging
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend-${var.environment}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}-frontend-${var.environment}"
  retention_in_days = 30
}

# 3. IAM Role: Task Execution (Allows ECS agent to pull from ECR and push logs to CloudWatch)

resource "aws_iam_policy" "ecs_secrets_policy" {
  name = "${var.project_name}-ecs-secrets-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.secret_arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. IAM Role: Task Role (Permissions needed by the application runtime)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# 5. Frontend Task Definition
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name                   = "frontend"
    image                  = var.frontend_image
    essential              = true
    readonlyRootFilesystem = false
    user                   = "101"

    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])
}

# 6. Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "backend"
    image     = var.backend_image
    essential = true

    readonlyRootFilesystem = true
    user                   = "1000"

    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]

    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "SERVER_PORT", value = "8080" },
      { name = "SERVER_URL", value = "https://${var.alb_dns_name}" },
      { name = "CLIENT_URL", value = "https://${var.alb_dns_name}" },
      { name = "COOKIE_DOMAIN", value = var.alb_dns_name },
      { name = "MAIL_FIRSTNAME", value = "Admin" },
      { name = "MAIL_LASTNAME", value = "Space2Study" },
      { name = "JWT_ACCESS_EXPIRES_IN", value = "1h" },
      { name = "JWT_REFRESH_EXPIRES_IN", value = "7d" },
      { name = "JWT_RESET_EXPIRES_IN", value = "1h" },
      { name = "JWT_CONFIRM_EXPIRES_IN", value = "1h" },
      { name = "MONGODB_URL", value = var.mongodb_url }
    ]

    secrets = [
      {
        name      = "MAIL_USER"
        valueFrom = "${var.app_secrets_arn}:MAIL_USER::"
      },
      {
        name      = "MAIL_PASS"
        valueFrom = "${var.app_secrets_arn}:MAIL_PASS::"
      },
      {
        name      = "GMAIL_CLIENT_ID"
        valueFrom = "${var.app_secrets_arn}:GMAIL_CLIENT_ID::"
      },
      {
        name      = "GMAIL_CLIENT_SECRET"
        valueFrom = "${var.app_secrets_arn}:GMAIL_CLIENT_SECRET::"
      },
      {
        name      = "GMAIL_REFRESH_TOKEN"
        valueFrom = "${var.app_secrets_arn}:GMAIL_REFRESH_TOKEN::"
      },
      {
        name      = "GMAIL_REDIRECT_URI"
        valueFrom = "${var.app_secrets_arn}:GMAIL_REDIRECT_URI::"
      },
      {
        name      = "JWT_ACCESS_SECRET"
        valueFrom = "${var.app_secrets_arn}:JWT_ACCESS_SECRET::"
      },
      {
        name      = "JWT_REFRESH_SECRET"
        valueFrom = "${var.app_secrets_arn}:JWT_REFRESH_SECRET::"
      },
      {
        name      = "JWT_RESET_SECRET"
        valueFrom = "${var.app_secrets_arn}:JWT_RESET_SECRET::"
      },
      {
        name      = "JWT_CONFIRM_SECRET"
        valueFrom = "${var.app_secrets_arn}:JWT_CONFIRM_SECRET::"
      }
    ]

    mountPoints = [{
      sourceVolume  = "tmp"
      containerPath = "/tmp"
      readOnly      = false
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])

  volume {
    name = "tmp"
  }
}

# 7. Frontend ECS Service
resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.frontend_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.frontend_target_group_arn
    container_name   = "frontend"
    container_port   = 8080
  }
}

# 8. Backend ECS Service
resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.backend_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.backend_target_group_arn
    container_name   = "backend"
    container_port   = 8080
  }
}