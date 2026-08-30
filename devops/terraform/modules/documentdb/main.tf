# 1. CloudWatch Log Group for MongoDB
resource "aws_cloudwatch_log_group" "mongodb" {
  name              = "/ecs/${var.project_name}-mongodb-${var.environment}"
  retention_in_days = 30
}

# 2. Service Discovery Private DNS (so backend can resolve mongodb.local)
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "local"
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "mongodb" {
  name = "mongodb"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# 3. MongoDB Task Definition
resource "aws_ecs_task_definition" "mongodb" {
  family                   = "${var.project_name}-mongodb-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([{
    name      = "database"
    image     = "mongo:8.3.8-noble"
    essential = true

    portMappings = [{
      containerPort = 27017
      hostPort      = 27017
      protocol      = "tcp"
    }]

    environment = [
      { name = "MONGO_INITDB_ROOT_USERNAME", value = var.db_username },
      { name = "MONGO_INITDB_ROOT_PASSWORD", value = var.db_password }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mongodb.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "mongodb"
      }
    }
  }])
}

# 4. MongoDB ECS Service in Private Subnets
resource "aws_ecs_service" "mongodb" {
  name            = "${var.project_name}-mongodb-${var.environment}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.mongodb.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [var.db_sg_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.mongodb.arn
  }
}