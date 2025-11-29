# TODO: Make bot policy dynamic based on passed in vars
variable "slack_signing_secret" {
  description = "The Slack signing secret for verification"
  type        = string
  sensitive   = true
  default     = "asigningsecret"
}

variable "slack_bot_token" {
  description = "The Slack bot token for authentication"
  type        = string
  sensitive   = true
  default     = "xoxb-"

  validation {
    condition     = can(regex("^xoxb-", var.slack_bot_token))
    error_message = "Slack bot token must start with 'xoxb-'."
  }
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "terraform-aws-slackbot-lambdalith"
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 731
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "provisioned_concurrency_count" {
  description = "Enable provisioned concurrency for the Lambda to eliminate cold starts"
  type        = number
  default     = 1
}

variable "bedrock_model_id" {
  description = "The Bedrock model ID to use for AI responses"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

# Obtain from https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html
variable "bedrock_model_inference_profile" {
  description = "Inference profile ID to use"
  type        = string
  default     = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "lambda_layer_name" {
  description = "Name of the Lambda layer"
  type        = string
  default     = "terraform-aws-slackbot-lambdalith"
}

variable "python_version" {
  description = "Python version for the Lambda layer"
  type        = string
  default     = "3.12"

  validation {
    condition     = contains(["3.8", "3.9", "3.10", "3.11", "3.12"], var.python_version)
    error_message = "Python version must be one of: 3.8, 3.9, 3.10, 3.11, 3.12."
  }
}

variable "lambda_source_path" {
  description = "Path to custom Lambda function source code (zip file or directory)"
  type        = string
  default     = "./lambda"
}

variable "lambda_source_type" {
  description = "Type of Lambda source: 'default', 'zip', or 'directory'"
  type        = string
  default     = "default"
  validation {
    condition     = contains(["default", "zip", "directory"], var.lambda_source_type)
    error_message = "lambda_source_type must be 'default', 'zip', or 'directory'."
  }
  validation {
    condition     = var.lambda_source_type == "default" || var.lambda_source_path != ""
    error_message = "lambda_source_path must be provided when lambda_source_type is 'zip' or 'directory'."
  }
}

# Optional: allow callers to influence dependencies in default mode
variable "requirements_txt_override_path" {
  description = "Path to a requirements.txt file to use for building the Lambda layer (takes precedence over the module's default when provided)."
  type        = string
  default     = ""

  validation {
    condition     = var.requirements_txt_override_path == "" || can(file(var.requirements_txt_override_path))
    error_message = "requirements_txt_override_path must point to an existing file if provided."
  }
}

variable "requirements_inline" {
  description = "Inline list of Python dependency specifiers to render into a requirements.txt for the Lambda layer. Takes precedence over requirements_txt_override_path when non-empty."
  type        = list(string)
  default     = []
}

variable "slack_app_name" {
  description = "Name of the Slack app in the manifest"
  type        = string
  default     = "Bolt Python Assistant"
}

variable "slack_app_description" {
  description = "Description of the Slack app assistant"
  type        = string
  default     = "Hi, I am an assistant built using Bolt for Python. I am here to help you out!"
}

variable "slack_slash_command" {
  description = "Slash command for the Slack app"
  type        = string
  default     = "/start-process"
}

variable "slack_slash_command_description" {
  description = "The description for the slash command"
  type        = string
  default     = "Ask a question to the Bedrock bot"
}

variable "lambda_env_vars" {
  description = "Environment variables to add to Lambda"
  type        = map(string)
  default = {
    "BEDROCK_MODEL_INFERENCE_PROFILE" = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
  }
}

variable "create_api_gateway" {
  description = "If true, create API Gateway instead of Lambda Function URL. Lambda Function URL is recommended for most use cases due to simplicity and lower cost."
  type        = bool
  default     = false
}

variable "enable_application_signals" {
  default     = false
  description = "If true, enables Application signals for monitoring and observability."
  type        = bool
}

variable "opentelemetry_python_layer_arns" {
  type        = map(string)
  description = "Map of AWS region to OpenTelemetry Lambda Layer ARN for Python."
  default = {
    "us-east-1"      = "arn:aws:lambda:us-east-1:615299751070:layer:AWSOpenTelemetryDistroPython:16"
    "us-east-2"      = "arn:aws:lambda:us-east-2:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "us-west-1"      = "arn:aws:lambda:us-west-1:615299751070:layer:AWSOpenTelemetryDistroPython:20"
    "us-west-2"      = "arn:aws:lambda:us-west-2:615299751070:layer:AWSOpenTelemetryDistroPython:20"
    "af-south-1"     = "arn:aws:lambda:af-south-1:904233096616:layer:AWSOpenTelemetryDistroPython:10"
    "ap-east-1"      = "arn:aws:lambda:ap-east-1:888577020596:layer:AWSOpenTelemetryDistroPython:10"
    "ap-south-2"     = "arn:aws:lambda:ap-south-2:796973505492:layer:AWSOpenTelemetryDistroPython:10"
    "ap-southeast-3" = "arn:aws:lambda:ap-southeast-3:039612877180:layer:AWSOpenTelemetryDistroPython:10"
    "ap-southeast-4" = "arn:aws:lambda:ap-southeast-4:713881805771:layer:AWSOpenTelemetryDistroPython:10"
    "ap-south-1"     = "arn:aws:lambda:ap-south-1:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "ap-northeast-3" = "arn:aws:lambda:ap-northeast-3:615299751070:layer:AWSOpenTelemetryDistroPython:12"
    "ap-northeast-2" = "arn:aws:lambda:ap-northeast-2:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "ap-southeast-1" = "arn:aws:lambda:ap-southeast-1:615299751070:layer:AWSOpenTelemetryDistroPython:12"
    "ap-southeast-2" = "arn:aws:lambda:ap-southeast-2:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "ap-northeast-1" = "arn:aws:lambda:ap-northeast-1:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "ca-central-1"   = "arn:aws:lambda:ca-central-1:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "eu-central-1"   = "arn:aws:lambda:eu-central-1:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "eu-west-1"      = "arn:aws:lambda:eu-west-1:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "eu-west-2"      = "arn:aws:lambda:eu-west-2:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "eu-south-1"     = "arn:aws:lambda:eu-south-1:257394471194:layer:AWSOpenTelemetryDistroPython:10"
    "eu-west-3"      = "arn:aws:lambda:eu-west-3:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "eu-south-2"     = "arn:aws:lambda:eu-south-2:490004653786:layer:AWSOpenTelemetryDistroPython:10"
    "eu-north-1"     = "arn:aws:lambda:eu-north-1:615299751070:layer:AWSOpenTelemetryDistroPython:13"
    "eu-central-2"   = "arn:aws:lambda:eu-central-2:156041407956:layer:AWSOpenTelemetryDistroPython:10"
    "il-central-1"   = "arn:aws:lambda:il-central-1:746669239226:layer:AWSOpenTelemetryDistroPython:10"
    "me-south-1"     = "arn:aws:lambda:me-south-1:980921751758:layer:AWSOpenTelemetryDistroPython:10"
    "me-central-1"   = "arn:aws:lambda:me-central-1:739275441131:layer:AWSOpenTelemetryDistroPython:10"
    "sa-east-1"      = "arn:aws:lambda:sa-east-1:615299751070:layer:AWSOpenTelemetryDistroPython:13"
  }
}

variable "additional_lambda_layer_arns" {
  type        = list(string)
  description = "Additional Lambda layer ARNs to attach to the function. Ensure layers match the selected lambda_architecture."
  default     = []
  # Example x86_64: ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python312-x86_64:27"]
  # Example arm64:   ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python312-arm64:27"]
}

variable "enable_snapstart" {
  description = "Enable SnapStart for faster cold starts (Java 11+ runtimes only). Cannot be used with provisioned concurrency."
  type        = bool
  default     = false
}

variable "sqs_batch_size" {
  description = "Maximum number of SQS messages to process in a single Lambda invocation"
  type        = number
  default     = 10

  validation {
    condition     = var.sqs_batch_size >= 1 && var.sqs_batch_size <= 10
    error_message = "SQS batch size must be between 1 and 10 for FIFO queues."
  }
}

variable "sqs_maximum_concurrency" {
  description = "Maximum number of concurrent Lambda functions that can be invoked by SQS"
  type        = number
  default     = 2

  validation {
    condition     = var.sqs_maximum_concurrency >= 2 && var.sqs_maximum_concurrency <= 1000
    error_message = "SQS maximum concurrency must be between 2 and 1000."
  }
}

variable "enable_sqs_processing" {
  type        = bool
  default     = true
  description = "Enable async SQS processing for Slack events"
}

variable "enable_powertools_layer" {
  type        = bool
  default     = true
  description = "Enable AWS Lambda Powertools Python layer for enhanced logging and tracing"
}

variable "lambda_architecture" {
  description = "Instruction set architecture for Lambda function"
  type        = string
  default     = "x86_64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "Lambda architecture must be either 'x86_64' or 'arm64'."
  }
}
