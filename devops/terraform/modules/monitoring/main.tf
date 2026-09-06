# ------------------------------------------------------------------------------
# 1. NOTIFICATION ROUTING: SNS & LAMBDA FORWARDER
# ------------------------------------------------------------------------------

# Package Lambda function directly from Python source code
data "archive_file" "discord_notifier_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/discord_notifier.py"
  output_path = "${path.module}/lambda/discord_notifier.zip"
}

# SNS Alert Topic
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alarms-${var.environment}"
}

# IAM Execution Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-discord-notifier-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch Logging Permissions for Lambda
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Discord Notifier
resource "aws_lambda_function" "discord_notifier" {
  function_name    = "${var.project_name}-discord-notifier-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.11"
  handler          = "discord_notifier.lambda_handler"
  filename         = data.archive_file.discord_notifier_zip.output_path
  source_code_hash = data.archive_file.discord_notifier_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }
}

# Allow SNS to invoke the Lambda function
resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# Subscribe Lambda to the SNS Topic
resource "aws_sns_topic_subscription" "discord_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_notifier.arn
}

# ------------------------------------------------------------------------------
# 2. CLOUDWATCH ALARMS: LOAD BALANCER & SERVICE HEALTH
# ------------------------------------------------------------------------------

# Alert if backend or frontend returns HTTP 5XX server errors
resource "aws_cloudwatch_metric_alarm" "alb_high_5xx" {
  alarm_name          = "${var.project_name}-alb-high-5xx-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Target returned >= 5 HTTP 5XX responses over 2 consecutive minutes."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# Alert if any Frontend container fails ALB health checks
resource "aws_cloudwatch_metric_alarm" "frontend_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-frontend-unhealthy-hosts-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "One or more Frontend tasks are failing ALB health checks."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = var.frontend_tg_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }
}

# Alert if any Backend container fails ALB health checks
resource "aws_cloudwatch_metric_alarm" "backend_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-backend-unhealthy-hosts-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "One or more Backend tasks are failing ALB health checks."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = var.backend_tg_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }
}

# ------------------------------------------------------------------------------
# 3. CLOUDWATCH ALARMS: ECS RESOURCE UTILIZATION
# ------------------------------------------------------------------------------

# Alert if Backend container memory usage exceeds 80%
resource "aws_cloudwatch_metric_alarm" "backend_memory_high" {
  alarm_name          = "${var.project_name}-backend-high-memory-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Backend service memory utilization exceeded 80%."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.backend_service_name
  }
}

# Alert if Backend container CPU usage exceeds 85%
resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${var.project_name}-backend-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 120
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Backend service CPU utilization exceeded 85%."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.backend_service_name
  }
}


# --------------------------------
# 4. CLOUDWATCH DASHBOARD
# --------------------------------

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Active Alarms Overview & ALB Request Volume
      {
        type   = "alarm"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "Active Alarms Overview"
          alarms = [
            aws_cloudwatch_metric_alarm.alb_high_5xx.arn,
            aws_cloudwatch_metric_alarm.frontend_unhealthy_hosts.arn,
            aws_cloudwatch_metric_alarm.backend_unhealthy_hosts.arn,
            aws_cloudwatch_metric_alarm.backend_memory_high.arn,
            aws_cloudwatch_metric_alarm.backend_cpu_high.arn
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Volume & Errors"
          view    = "timeSeries"
          stacked = false
          region  = "eu-central-1"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 60, color = "#2ca02c" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 60, color = "#d62728" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 60, color = "#ff7f0e" }]
          ]
        }
      },

      # Row 2: Target Health & Response Time (Latency)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Target Groups - Unhealthy Hosts"
          view    = "timeSeries"
          stacked = false
          region  = "eu-central-1"
          metrics = [
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", var.frontend_tg_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { label = "Frontend Unhealthy", color = "#d62728" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", var.backend_tg_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { label = "Backend Unhealthy", color = "#9467bd" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Target Response Time (p95 & Average Latency)"
          view    = "timeSeries"
          stacked = false
          region  = "eu-central-1"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p95", period = 60, label = "p95 Latency (s)", color = "#ff7f0e" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average", period = 60, label = "Avg Latency (s)", color = "#1f77b4" }]
          ]
        }
      },

      # Row 3: ECS Service Resources (CPU & Memory)
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "ECS CPU Utilization (%)"
          view    = "timeSeries"
          stacked = false
          region  = "eu-central-1"
          yAxis   = { left = { min = 0, max = 100 } }
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.frontend_service_name, "ClusterName", var.ecs_cluster_name, { label = "Frontend CPU" }],
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.backend_service_name, "ClusterName", var.ecs_cluster_name, { label = "Backend CPU" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "ECS Memory Utilization (%)"
          view    = "timeSeries"
          stacked = false
          region  = "eu-central-1"
          yAxis   = { left = { min = 0, max = 100 } }
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ServiceName", var.frontend_service_name, "ClusterName", var.ecs_cluster_name, { label = "Frontend Memory" }],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", var.backend_service_name, "ClusterName", var.ecs_cluster_name, { label = "Backend Memory" }]
          ]
        }
      }
    ]
  })
}