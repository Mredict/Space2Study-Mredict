# 1. CloudWatch Log Group for MongoDB
resource "aws_cloudwatch_log_group" "mongodb" {
  name              = "/ecs/${var.project_name}-mongodb-${var.environment}"
  retention_in_days = 30
}

# 2. Service Discovery Private DNS (mongodb.local)
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

#  health_check_custom_config {}
}

# 3. EFS Security Group
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg-${var.environment}"
  description = "Allows NFS inbound from DocumentDB ECS Task"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow NFS port 2049"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.db_sg_id]
  }

  egress {
    description = "Allow outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-efs-sg-${var.environment}"
  }
}

# 4. EFS File System
resource "aws_efs_file_system" "mongodb_data" {
  creation_token = "${var.project_name}-mongodb-efs-${var.environment}"
  encrypted      = true

  tags = {
    Name = "${var.project_name}-mongodb-efs-${var.environment}"
  }
}

# 5. EFS Mount Targets in Private Subnets
resource "aws_efs_mount_target" "mongodb" {
  count           = length(var.private_subnets)
  file_system_id  = aws_efs_file_system.mongodb_data.id
  subnet_id       = var.private_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}

# 6. EFS Access Point (Runs as UID/GID 999 for MongoDB)
resource "aws_efs_access_point" "mongodb" {
  file_system_id = aws_efs_file_system.mongodb_data.id

  posix_user {
    gid = 999
    uid = 999
  }

  root_directory {
    path = "/mongodb_data"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "755"
    }
  }
}

# 7. MongoDB Task Definition
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

    secrets = [
      {
        name      = "MONGO_INITDB_ROOT_USERNAME"
        valueFrom = "${var.app_secrets_arn}:DB_USERNAME::"
      },
      {
        name      = "MONGO_INITDB_ROOT_PASSWORD"
        valueFrom = "${var.app_secrets_arn}:DB_PASSWORD::"
      }
    ]

    mountPoints = [{
      sourceVolume  = "mongodb_efs"
      containerPath = "/data/db"
      readOnly      = false
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mongodb.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "mongodb"
      }
    }
  }])

  volume {
    name = "mongodb_efs"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.mongodb_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.mongodb.id
        iam             = "DISABLED"
      }
    }
  }
}

# 8. MongoDB ECS Service in Private Subnets
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

  depends_on = [aws_efs_mount_target.mongodb]
}