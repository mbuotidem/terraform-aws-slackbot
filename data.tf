# Data sources
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Initialize all required build directories to prevent "empty archive" errors
resource "terraform_data" "init_build_directories" {
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${local.artifacts_dir}/layer_build/python
      mkdir -p ${local.artifacts_dir}/layer_build/reqsrc
      mkdir -p ${local.artifacts_dir}/lambda_build
      # Create placeholder files to ensure directories are never empty during Terraform planning
      touch ${local.artifacts_dir}/layer_build/python/.placeholder
      touch ${local.artifacts_dir}/lambda_build/.placeholder
    EOT
  }
}

# Resolve requirements source for layer build
# Priority: requirements_inline -> requirements_txt_override_path -> default per mode
locals {
  requirements_inline_enabled = length(var.requirements_inline) > 0
  requirements_file_selected  = var.requirements_txt_override_path != ""

  # Directory to mount into /var/task inside the Docker container
  requirements_host_dir = local.requirements_inline_enabled ? "${local.artifacts_dir}/layer_build/reqsrc" : (
    var.lambda_source_type == "directory" ? var.lambda_source_path : (
  local.requirements_file_selected ? dirname(var.requirements_txt_override_path) : "${path.module}/lambda"))

  # Path to requirements.txt inside host dir
  requirements_host_path = local.requirements_inline_enabled ? "${local.artifacts_dir}/layer_build/reqsrc/requirements.txt" : (
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
    architecture   = var.lambda_architecture
  }
  depends_on = [local_file.requirements_inline_file, terraform_data.init_build_directories]

  provisioner "local-exec" {
    command = <<-EOT
      # Clean the layer directory to ensure fresh build
      echo "Cleaning layer build directory..."
      find ${local.artifacts_dir}/layer_build/python -mindepth 1 ! -name '.placeholder' -delete

      # Use Docker to build Lambda layer with correct architecture
      echo "Using Docker to build Lambda layer for ${var.lambda_architecture} architecture..."
      docker run --rm \
        --platform=linux/${var.lambda_architecture == "x86_64" ? "amd64" : "arm64"} \
        --entrypoint="" \
        -v ${local.requirements_host_dir}:/var/task:ro \
        -v ${local.artifacts_dir}/layer_build/python:/var/layer:rw \
        public.ecr.aws/lambda/python:${var.python_version} \
        /bin/bash -c "
          # First, clean the directory inside Docker (except .placeholder)
          find /var/layer -mindepth 1 ! -name '.placeholder' -delete

          if [ -f /var/task/requirements.txt ]; then
            echo 'Installing dependencies from requirements.txt...'
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
  source_dir  = "${local.artifacts_dir}/layer_build"
  output_path = "${local.artifacts_dir}/layer_build/lambda_layer.zip"

  depends_on = [terraform_data.lambda_layer_build, terraform_data.init_build_directories, local_file.requirements_inline_file]
}

# Trigger for Lambda code changes
resource "terraform_data" "lambda_code_trigger" {
  triggers_replace = {
    lambda_files_hash = sha256(join("", concat(
      [for f in fileset("${path.module}/lambda", "**/*.py") : filesha256("${path.module}/lambda/${f}")],
      [var.bedrock_model_inference_profile]
    )))
  }
}

# Ensure lambda build directory exists
resource "terraform_data" "lambda_build_init" {
  count = var.lambda_source_type == "default" ? 1 : 0

  depends_on = [terraform_data.init_build_directories]
}

# Create the Lambda function code
resource "terraform_data" "lambda_code" {
  count = var.lambda_source_type == "default" ? 1 : 0

  triggers_replace = {
    code_trigger = terraform_data.lambda_code_trigger.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Clean the lambda build directory (except .placeholder)
      echo "Cleaning lambda build directory..."
      find ${local.artifacts_dir}/lambda_build -mindepth 1 ! -name '.placeholder' -delete

      # Copy entire lambda directory structure
      echo "Copying lambda code..."
      cp -r ${path.module}/lambda/* ${local.artifacts_dir}/lambda_build/
    EOT
  }

  depends_on = [terraform_data.lambda_build_init]
}

# Archive the Lambda function code
data "archive_file" "lambda_zip" {
  count       = var.lambda_source_type == "default" ? 1 : 0
  type        = "zip"
  source_dir  = "${local.artifacts_dir}/lambda_build"
  output_path = "${local.artifacts_dir}/lambda_build/lambda_function.zip"

  depends_on = [terraform_data.lambda_code, terraform_data.lambda_build_init]
}

# Conditional archive file for custom Lambda source
data "archive_file" "custom_lambda_zip" {
  count       = var.lambda_source_type == "directory" ? 1 : 0
  type        = "zip"
  source_dir  = var.lambda_source_path
  output_path = "${local.artifacts_dir}/lambda_function_custom.zip"
}

data "aws_bedrock_foundation_model" "anthropic" {
  model_id = var.bedrock_model_id
}

# Lookup Powertools Python layer ARN from SSM Parameter Store
data "aws_ssm_parameter" "powertools_layer_arn" {
  count = var.enable_powertools_layer ? 1 : 0
  name  = "/aws/service/powertools/python/${var.lambda_architecture}/${local.powertools_python_version}/latest"
}
