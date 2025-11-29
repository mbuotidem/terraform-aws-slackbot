locals {
  # Centralized artifacts directory for all generated files
  artifacts_dir = "${path.module}/.artifacts"

  create_gateway       = var.create_api_gateway
  create_sqs_resources = var.enable_sqs_processing

  # Format Python version for Powertools SSM parameter (e.g., "3.12" -> "python3.12")
  powertools_python_version = "python${var.python_version}"

  # Build the layers list conditionally
  lambda_layers = concat(
    var.additional_lambda_layer_arns,
    [aws_lambda_layer_version.dependencies.arn],
    var.enable_application_signals ? [var.opentelemetry_python_layer_arns[data.aws_region.current.name]] : [],
    var.enable_powertools_layer ? [data.aws_ssm_parameter.powertools_layer_arn[0].value] : []
  )
}
