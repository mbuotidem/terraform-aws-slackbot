output "slack_bot_token_secret_name" {
  description = "The name of the Secrets Manager secret containing the Slack bot token"
  value       = aws_secretsmanager_secret.slack_bot_token.name
}

output "slack_bot_token_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing the Slack bot token"
  value       = aws_secretsmanager_secret.slack_bot_token.arn
}

output "slack_bot_token_console_url" {
  description = "The AWS console URL for the Slack bot token secret"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/secretsmanager/secret?name=${aws_secretsmanager_secret.slack_bot_token.name}&region=${data.aws_region.current.name}"
}

output "slack_bot_endpoint_url" {
  description = "The URL used to verify the Slack app (API Gateway or Lambda Function URL)"
  value       = local.create_gateway ? "${aws_apigatewayv2_api.slack_bot_endpoint[0].api_endpoint}/" : aws_lambda_function_url.slack_bot_lambda[0].function_url
}

output "lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.slack_bot_lambda.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.slack_bot_lambda.arn
}

output "api_gateway_id" {
  description = "The ID of the API Gateway (if created)"
  value       = length(aws_apigatewayv2_api.slack_bot_endpoint) > 0 ? aws_apigatewayv2_api.slack_bot_endpoint[0].id : null
}

output "lambda_layer_arn" {
  description = "The ARN of the Lambda layer (if created)"
  value       = aws_lambda_layer_version.dependencies.arn
}

output "lambda_layer_version" {
  description = "The version of the Lambda layer (if created)"
  value       = aws_lambda_layer_version.dependencies.version
}

output "slack_app_manifest_file" {
  description = "The path to the generated Slack app manifest file"
  value       = local_file.slack_app_manifest.filename
}

output "slack_app_manifest_content" {
  description = "The content of the generated Slack app manifest"
  value       = local_file.slack_app_manifest.content
}
