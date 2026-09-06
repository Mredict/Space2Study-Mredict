output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = aws_sns_topic.alerts.arn
}

output "lambda_function_arn" {
  description = "ARN of the Discord notifier Lambda function"
  value       = aws_lambda_function.discord_notifier.arn
}