# Slack Signing Secret
resource "aws_secretsmanager_secret" "slack_signing_secret" {
  name                    = "SlackSigningSecret-${var.lambda_function_name}"
  description             = "Slack signing secret for verification"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "time_static" "slack_signing_secret_update" {
  triggers = {
    secret = var.slack_signing_secret
  }
}

resource "aws_secretsmanager_secret_version" "slack_signing_secret" {
  secret_id = aws_secretsmanager_secret.slack_signing_secret.id
  secret_string_wo = jsonencode({
    secret     = var.slack_signing_secret
    version_id = time_static.slack_signing_secret_update.unix
  })
  secret_string_wo_version = time_static.slack_signing_secret_update.unix
}
# Slack Bot Token Secret
resource "aws_secretsmanager_secret" "slack_bot_token" {
  name                    = "SlackBotToken-${var.lambda_function_name}"
  description             = "Slack bot token for authentication"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "time_static" "slack_bot_token_update" {
  triggers = {
    token = var.slack_bot_token
  }
}

resource "aws_secretsmanager_secret_version" "slack_bot_token" {
  secret_id = aws_secretsmanager_secret.slack_bot_token.id
  secret_string_wo = jsonencode({
    token      = var.slack_bot_token
    version_id = time_static.slack_bot_token_update.unix
  })
  secret_string_wo_version = time_static.slack_bot_token_update.unix
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "slack_bot_lambda_log" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Only create dispatcher and API Gateway if use_function_url is false
locals {
  create_gateway_and_dispatcher = var.use_function_url == false
}

resource "aws_cloudwatch_log_group" "slack_bot_api_access_log" {
  name              = "/aws/apigateway/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# IAM Role for Lambda
resource "aws_iam_role" "slack_bot_role" {
  name        = var.lambda_function_name
  description = "Role for Slack bot lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
    }]
  })

  tags = var.tags
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.slack_bot_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# IAM Policy for Lambda
resource "aws_iam_role_policy" "slack_bot_role_policy" {
  name = var.lambda_function_name
  role = aws_iam_role.slack_bot_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "bedrock:InvokeModel"
        Effect   = "Allow"
        Resource = [data.aws_bedrock_foundation_model.anthropic.model_arn, "arn:aws:bedrock:*::foundation-model/${var.bedrock_model_id}", "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_inference_profile}"]
      },
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = [aws_secretsmanager_secret.slack_bot_token.arn, aws_secretsmanager_secret.slack_signing_secret.arn]
      },
      {
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunction"
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${var.lambda_function_name}*"]

      }
    ]
  })
}

# Lambda Layer
resource "aws_lambda_layer_version" "dependencies" {
  filename            = data.archive_file.lambda_layer_zip.output_path
  layer_name          = coalesce(var.lambda_function_name, var.lambda_layer_name)
  description         = "Python dependencies for Slack bot"
  source_code_hash    = data.archive_file.lambda_layer_zip.output_base64sha256
  compatible_runtimes = ["python${var.python_version}"]

  depends_on = [data.archive_file.lambda_layer_zip]
}

# Lambda Function
resource "aws_lambda_function" "slack_bot_lambda" {
  filename = var.lambda_source_type == "zip" ? var.lambda_source_path : (var.lambda_source_type == "directory" ? data.archive_file.custom_lambda_zip[0].output_path : data.archive_file.lambda_zip[0].output_path)

  function_name    = var.lambda_function_name
  role             = aws_iam_role.slack_bot_role.arn
  handler          = "index.handler"
  runtime          = "python${var.python_version}"
  timeout          = var.lambda_timeout
  description      = "Handles Slack bot actions"
  source_code_hash = var.lambda_source_type == "zip" ? filebase64sha256(var.lambda_source_path) : (var.lambda_source_type == "directory" ? data.archive_file.custom_lambda_zip[0].output_base64sha256 : data.archive_file.lambda_zip[0].output_base64sha256)

  publish = true

  # Use Lambda layer for dependencies if created
  layers = var.enable_application_signals ? [aws_lambda_layer_version.dependencies.arn, var.opentelemetry_python_layer_arns[data.aws_region.current]] : [aws_lambda_layer_version.dependencies.arn]

  environment {
    variables = merge(
      var.lambda_env_vars,
      {
        token  = aws_secretsmanager_secret.slack_bot_token.name
        secret = aws_secretsmanager_secret.slack_signing_secret.name
      },
      var.enable_application_signals ? {
        "AWS_LAMBDA_EXEC_WRAPPER" = "/opt/otel-instrument"
      } : {}
    )
  }



  # snap_start {
  #   apply_on = "PublishedVersions"
  # }



  memory_size = 512

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.slack_bot_lambda_log.name
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy.slack_bot_role_policy,
    aws_cloudwatch_log_group.slack_bot_lambda_log
  ]

  tags = var.tags

}

resource "aws_lambda_function_url" "slack_bot_lambda" {
  count              = local.create_gateway_and_dispatcher ? 0 : 1
  function_name      = aws_lambda_function.slack_bot_lambda.function_name
  authorization_type = "NONE"
}

# CloudWatch Log Group for Dispatcher Lambda
resource "aws_cloudwatch_log_group" "slack_bot_dispatcher_log" {
  count             = local.create_gateway_and_dispatcher ? 1 : 0
  name              = "/aws/lambda/${var.lambda_function_name}-dispatcher"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# IAM Role for Dispatcher Lambda
resource "aws_iam_role" "slack_bot_dispatcher_role" {
  count       = local.create_gateway_and_dispatcher ? 1 : 0
  name        = "${var.lambda_function_name}-dispatcher"
  description = "Role for Slack bot dispatcher lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
    }]
  })
  tags = var.tags
}

# Attach AWS managed policy for Lambda basic execution (dispatcher)
resource "aws_iam_role_policy_attachment" "dispatcher_lambda_basic_execution" {
  count      = local.create_gateway_and_dispatcher ? 1 : 0
  role       = aws_iam_role.slack_bot_dispatcher_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Dispatcher Lambda
resource "aws_iam_role_policy" "slack_bot_dispatcher_policy" {
  count = local.create_gateway_and_dispatcher ? 1 : 0
  name  = "${var.lambda_function_name}-dispatcher"
  role  = aws_iam_role.slack_bot_dispatcher_role[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = [aws_lambda_function.slack_bot_lambda.arn]
      }
    ]
  })
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "slack_bot_endpoint" {
  count         = local.create_gateway_and_dispatcher ? 1 : 0
  name          = var.lambda_function_name
  protocol_type = "HTTP"
  description   = "Proxy for Bedrock Slack bot backend."
  tags          = var.tags
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "slack_bot_endpoint_default_stage" {
  count       = local.create_gateway_and_dispatcher ? 1 : 0
  api_id      = aws_apigatewayv2_api.slack_bot_endpoint[0].id
  name        = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.slack_bot_api_access_log.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      userAgent      = "$context.identity.userAgent"
    })
  }
  tags = var.tags
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "slack_bot_integration" {
  count                  = local.create_gateway_and_dispatcher ? 1 : 0
  api_id                 = aws_apigatewayv2_api.slack_bot_endpoint[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.slack_bot_dispatcher[0].invoke_arn
  payload_format_version = "2.0"
}

# Dispatcher Lambda Function (returns immediate response and invokes main Lambda async)
resource "aws_lambda_function" "slack_bot_dispatcher" {
  count            = local.create_gateway_and_dispatcher ? 1 : 0
  filename         = data.archive_file.dispatcher_zip.output_path
  function_name    = "${var.lambda_function_name}-dispatcher"
  role             = aws_iam_role.slack_bot_dispatcher_role[0].arn
  handler          = "index.handler"
  runtime          = "python${var.python_version}"
  timeout          = 3
  description      = "Dispatcher that returns immediate response and invokes main Lambda async"
  source_code_hash = data.archive_file.dispatcher_zip.output_base64sha256
  publish          = true
  memory_size      = 1024
  environment {
    variables = {
      MAIN_LAMBDA_FUNCTION = aws_lambda_function.slack_bot_lambda.function_name
    }
  }
  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.slack_bot_dispatcher_log[0].name
  }
  depends_on = [
    aws_iam_role_policy.slack_bot_dispatcher_policy,
    aws_cloudwatch_log_group.slack_bot_dispatcher_log
  ]
  tags = var.tags
}

# Lambda Alias for Dispatcher (stable reference for provisioned concurrency)
resource "aws_lambda_alias" "slack_bot_dispatcher_live" {
  count            = (var.enable_dispatcher_provisioned_concurrency && local.create_gateway_and_dispatcher) ? 1 : 0
  name             = "live"
  function_name    = aws_lambda_function.slack_bot_dispatcher[0].function_name
  function_version = aws_lambda_function.slack_bot_dispatcher[0].version
}

# Provisioned Concurrency for Dispatcher Lambda (keeps it warm for instant responses)
resource "aws_lambda_provisioned_concurrency_config" "slack_bot_dispatcher_concurrency" {
  count                             = (var.enable_dispatcher_provisioned_concurrency && local.create_gateway_and_dispatcher) ? 1 : 0
  function_name                     = aws_lambda_function.slack_bot_dispatcher[0].function_name
  provisioned_concurrent_executions = 1
  qualifier                         = aws_lambda_alias.slack_bot_dispatcher_live[0].name

}

# resource "aws_lambda_provisioned_concurrency_config" "slack_bot_lambda" {
#   function_name                     = aws_lambda_function.slack_bot_lambda.function_name
#   provisioned_concurrent_executions = 1
#   qualifier                         = aws_lambda_function.slack_bot_lambda.version
# }

# API Gateway Route
resource "aws_apigatewayv2_route" "slack_bot_route" {
  count     = local.create_gateway_and_dispatcher ? 1 : 0
  api_id    = aws_apigatewayv2_api.slack_bot_endpoint[0].id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.slack_bot_integration[0].id}"
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  count         = local.create_gateway_and_dispatcher ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_bot_dispatcher[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.slack_bot_endpoint[0].execution_arn}/*"
}

# Generate Slack app manifest with API Gateway URL
resource "local_file" "slack_app_manifest" {
  content = templatefile("${path.module}/manifest.json.tpl", {
    api_gateway_url           = var.use_function_url ? aws_lambda_function_url.slack_bot_lambda[0].function_url : (local.create_gateway_and_dispatcher ? "${aws_apigatewayv2_api.slack_bot_endpoint[0].api_endpoint}/" : "")
    app_name                  = var.slack_app_name
    app_description           = var.slack_app_description
    slash_command             = var.slack_slash_command
    slash_command_description = var.slack_slash_command_description
  })
  filename = "${path.cwd}/slack_app_manifest.json"
}

# Store copy of Slack app manifest in SSM Parameter Store
resource "aws_ssm_parameter" "slack_app_manifest" {
  name        = "/slack-app/${var.lambda_function_name}/manifest"
  description = "Slack app manifest for ${var.lambda_function_name}"
  type        = "String"
  value = templatefile("${path.module}/manifest.json.tpl", {
    api_gateway_url           = var.use_function_url ? aws_lambda_function_url.slack_bot_lambda[0].function_url : (local.create_gateway_and_dispatcher ? "${aws_apigatewayv2_api.slack_bot_endpoint[0].api_endpoint}/" : "")
    app_name                  = var.slack_app_name
    app_description           = var.slack_app_description
    slash_command             = var.slack_slash_command
    slash_command_description = var.slack_slash_command_description
  })
  tags = var.tags
}


resource "aws_cloudwatch_event_bus" "bus" {
  name = var.lambda_function_name
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_application_signals" {
  count      = var.enable_application_signals ? 1 : 0
  role       = aws_iam_role.slack_bot_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

