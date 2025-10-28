# Data sources
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Initialize all required build directories to prevent "empty archive" errors
resource "terraform_data" "init_build_directories" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/layer_build/python
      mkdir -p ${path.module}/layer_build/reqsrc
      mkdir -p ${path.module}/lambda_build
      mkdir -p ${path.module}/dispatcher_build
      # Create placeholder files to ensure directories are never empty during Terraform planning
      touch ${path.module}/layer_build/python/.placeholder
      touch ${path.module}/lambda_build/.placeholder
      touch ${path.module}/dispatcher_build/.placeholder
    EOT
  }
}

# Resolve requirements source for layer build
# Priority: requirements_inline -> requirements_txt_override_path -> default per mode
locals {
  requirements_inline_enabled = length(var.requirements_inline) > 0
  requirements_file_selected  = var.requirements_txt_override_path != ""

  # Directory to mount into /var/task inside the Docker container
  requirements_host_dir = local.requirements_inline_enabled ? "${path.module}/layer_build/reqsrc" : (
    var.lambda_source_type == "directory" ? var.lambda_source_path : (
  local.requirements_file_selected ? dirname(var.requirements_txt_override_path) : "${path.module}/lambda"))

  # Path to requirements.txt inside host dir
  requirements_host_path = local.requirements_inline_enabled ? "${path.module}/layer_build/reqsrc/requirements.txt" : (
  local.requirements_file_selected ? var.requirements_txt_override_path : "${local.requirements_host_dir}/requirements.txt")

  # Stable hash for triggers to avoid plan/apply inconsistencies
  requirements_trigger_hash = local.requirements_inline_enabled ? sha256(join("\n", var.requirements_inline)) : (
    local.requirements_file_selected ? (fileexists(var.requirements_txt_override_path) ? filemd5(var.requirements_txt_override_path) : "") : (
      var.lambda_source_type == "directory" ? (fileexists("${var.lambda_source_path}/requirements.txt") ? filemd5("${var.lambda_source_path}/requirements.txt") : "") : filemd5("${path.module}/lambda/requirements.txt")
    )
  )
}

# If inline requirements are provided, materialize them to a file
resource "local_file" "requirements_inline_file" {
  count      = local.requirements_inline_enabled ? 1 : 0
  filename   = local.requirements_host_path
  content    = join("\n", var.requirements_inline)
  depends_on = [terraform_data.init_build_directories]
}

# Build Lambda layer from requirements.txt
resource "terraform_data" "lambda_layer_build" {
  triggers_replace = {
    # Hash of selected requirements content (stable across plan/apply)
    requirements   = local.requirements_trigger_hash
    python_version = var.python_version
  }
  depends_on = [local_file.requirements_inline_file, terraform_data.init_build_directories]

  provisioner "local-exec" {
    command = <<-EOT
      # Use Docker to build Lambda layer with correct x86_64 architecture
      echo "Using Docker to build Lambda layer..."
      docker run --rm \
        --platform=linux/amd64 \
        --entrypoint="" \
        -v ${local.requirements_host_dir}:/var/task:ro \
        -v ${path.module}/layer_build/python:/var/layer:rw \
        public.ecr.aws/lambda/python:${var.python_version} \
        /bin/bash -c "
          if [ -f /var/task/requirements.txt ]; then
            pip install -r /var/task/requirements.txt -t /var/layer --no-cache-dir
          else
            echo 'No requirements.txt found, skipping dependency installation'
          fi
          # Ensure directory is never empty by keeping placeholder if no packages installed
          if [ ! \"\$(ls -A /var/layer | grep -v '.placeholder')\" ]; then
            touch /var/layer/.placeholder
          fi
        "
    EOT
  }

}

# Archive the Lambda layer
data "archive_file" "lambda_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/layer_build"
  output_path = "${path.module}/layer_build/lambda_layer.zip"

  depends_on = [terraform_data.lambda_layer_build, terraform_data.init_build_directories, local_file.requirements_inline_file]
}

# Trigger for Lambda code changes
resource "terraform_data" "lambda_code_trigger" {
  triggers_replace = {
    shell_hash = sha256(join("", [
      file("${path.module}/lambda/index.py"),
      var.bedrock_model_inference_profile
    ]))
  }
}

# Ensure lambda build directory exists
resource "terraform_data" "lambda_build_init" {
  count = var.lambda_source_type == "default" ? 1 : 0

  depends_on = [terraform_data.init_build_directories]
}

# Create the Lambda function code
resource "local_file" "lambda_code" {
  count = var.lambda_source_type == "default" ? 1 : 0

  content = templatefile("${path.module}/lambda/index.py", {
    bedrock_model_id = var.bedrock_model_inference_profile

  })
  filename = "${path.module}/lambda_build/index.py"

  depends_on = [terraform_data.lambda_build_init]

  # Force recreation when trigger changes
  lifecycle {
    replace_triggered_by = [
      terraform_data.lambda_code_trigger
    ]
  }
}

# Archive the Lambda function code
data "archive_file" "lambda_zip" {
  count       = var.lambda_source_type == "default" ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/lambda_build"
  output_path = "${path.module}/lambda_build/lambda_function.zip"

  depends_on = [local_file.lambda_code, terraform_data.lambda_build_init]
}

# Conditional archive file for custom Lambda source
data "archive_file" "custom_lambda_zip" {
  count       = var.lambda_source_type == "directory" ? 1 : 0
  type        = "zip"
  source_dir  = var.lambda_source_path
  output_path = "${path.module}/lambda_function_custom.zip"
}

data "aws_bedrock_foundation_model" "anthropic" {
  model_id = var.bedrock_model_id
}

# Ensure dispatcher build directory exists
resource "terraform_data" "dispatcher_build_init" {
  count = var.use_function_url ? 0 : 1

  depends_on = [terraform_data.init_build_directories]
}

# Create dispatcher Lambda function
resource "local_file" "dispatcher_lambda_code" {
  count    = var.use_function_url ? 0 : 1
  content  = <<EOF
import json
import boto3
import os

def handler(event, context):
    """
    Dispatcher Lambda that immediately returns 200 OK and invokes main Lambda async
    """
    
    # Get the main Lambda function name from environment
    main_function_name = os.environ['MAIN_LAMBDA_FUNCTION']
    
    # Create Lambda client
    lambda_client = boto3.client('lambda')
    
    try:
        # Invoke the main Lambda function asynchronously
        lambda_client.invoke(
            FunctionName=main_function_name,
            InvocationType='Event',  # Asynchronous invocation
            Payload=json.dumps(event)
        )
        
        # Return immediate 200 OK response for Slack
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            }
        }
        
    except Exception as e:
        print(f"Error invoking main Lambda: {str(e)}")
        # Still return 200 to Slack to avoid retries
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'message': 'Request received'
            })
        }
EOF
  filename = "${path.module}/dispatcher_build/index.py"

  depends_on = [terraform_data.dispatcher_build_init]
}

# Archive the dispatcher Lambda function
data "archive_file" "dispatcher_zip" {
  count       = var.use_function_url ? 0 : 1
  type        = "zip"
  source_dir  = "${path.module}/dispatcher_build"
  output_path = "${path.module}/dispatcher_build/dispatcher_function.zip"

  depends_on = [local_file.dispatcher_lambda_code, terraform_data.dispatcher_build_init]
}
