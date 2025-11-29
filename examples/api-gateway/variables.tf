variable "slack_bot_token" {
  description = "The Slack bot token for authentication"
  type        = string
}

variable "bedrock_model_id" {
  description = "The Bedrock model ID to use for AI responses"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "slack_signing_secret" {
  description = "The Slack signing secret for verification"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "function_url" {
  description = "The Lambda Function URL to use in the Slack manifest (only used when create_api_gateway is false)."
  type        = string
  default     = ""
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "lambda-function-url-terraform-aws-slackbot-lambdalith"
}
