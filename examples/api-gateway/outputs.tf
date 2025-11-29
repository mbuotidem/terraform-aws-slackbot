output "slack_bot_endpoint_url" {
  description = "The URL used to verify the Slack app (API Gateway or Lambda Function URL)"
  value       = module.slack_bot.slack_bot_endpoint_url
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = module.slack_bot.lambda_function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = module.slack_bot.lambda_function_arn
}
