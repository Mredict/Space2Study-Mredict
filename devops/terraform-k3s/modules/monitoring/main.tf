data "archive_file" "discord_notifier_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/discord_notifier.py"
  output_path = "${path.module}/lambda/discord_notifier.zip"
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alarms-${var.environment}"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-discord-notifier-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "discord_notifier" {
  function_name    = "${var.project_name}-discord-notifier-${var.environment}"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "discord_notifier.lambda_handler"
  filename         = data.archive_file.discord_notifier_zip.output_path
  source_code_hash = data.archive_file.discord_notifier_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = { DISCORD_WEBHOOK_URL = var.discord_webhook_url }
  }
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_sns_topic_subscription" "discord_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.discord_notifier.arn
}

# EC2 status check alarms for every node
resource "aws_cloudwatch_metric_alarm" "node_status_check" {
  for_each            = var.node_instance_ids
  alarm_name          = "${var.project_name}-${each.key}-status-check-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Node ${each.key} is failing EC2 instance/system status checks."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = { InstanceId = each.value }
}

resource "aws_cloudwatch_metric_alarm" "node_cpu_credit_low" {
  for_each            = var.node_instance_ids
  alarm_name          = "${var.project_name}-${each.key}-cpu-credits-low-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUCreditBalance"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "Node ${each.key} is running low on CPU credits (burstable instance)."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = { InstanceId = each.value }
}
