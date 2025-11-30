# AWS Python Slack Bot with Bedrock Integration

A Terraform module for quickly deploying a **Python** Slack [AI assistant](https://docs.slack.dev/ai/developing-ai-apps) to AWS Lambda.


![alt text](https://raw.githubusercontent.com/mbuotidem/terraform-aws-slackbot/refs/heads/main/architecture.png)

## Prerequisites
Docker

## Quickstart
```hcl
module "slack_bot" {
  source = "mbuotidem/slackbot/aws"

  # slack_bot_token      = "xoxb-your-bot-token"
  # slack_signing_secret = "your-signing-secret"

  # Optional: Customize your Slack app manifest
  slack_app_name                   = "My Custom Bot"
  slack_app_description            = "A custom bot built with Terraform and AWS Lambda"
  slack_slash_command              = "/slash-command"
  slack_slash_command_description  = "Executes my custom command"

  tags = {
    Environment = "production"
    Project     = "slack-bot"
  }
}
```

1. **Deploy the Terraform module**
   Run `terraform apply`. This uses dummy default values for `slack_bot_token` and `slack_signing_secret` to create your Slack Lambda and generate a Slack app manifest.
   - Manifest location: Written to the directory where you run Terraform as `slack_app_manifest.json`.
   - Also available via outputs: `slack_app_manifest_file` (path) and `slack_app_manifest_content` (JSON).
   - Stored in SSM Parameter Store at `/slack-app/<lambda_function_name>/manifest`.

2. **Create your Slack app using the manifest**
   - Go to [Slack API: Your Apps](https://api.slack.com/apps)
   - Click **Create New App** → **From an app manifest**
   - Select your workspace and click **Next**
   - Copy the contents of `slack_app_manifest.json` and paste into the manifest field
   - Click **Next**, review, and then **Create**

3. **Install the app in your Slack workspace**
   - Click **Install to Workspace** and authorize the app

4. **Retrieve Slack credentials**
   - Get the **Bot User OAuth Token** (starts with `xoxb-`) from the **OAuth & Permissions** page
   - Get the **Signing Secret** from the **Basic Information** page

5. **Update your Terraform configuration**
   - Uncomment and set `slack_bot_token` and `slack_signing_secret` in your module block

6. **Apply the changes**
   - Rerun `terraform apply` to update your deployment with the real credentials
---

**⚠️ IMPORTANT:** The initial apply uses placeholder Slack credentials so the app and manifest can be created. **The bot will not respond in Slack** until you replace `slack_bot_token` and `slack_signing_secret` with real values and re-apply.

---


## Architecture

The module creates the following AWS resources:

- AWS Lambda function for processing Slack events (with configurable source code)
- SQS Queue for decoupling ingestion of events from processing and reacting to them
- Lambda layer for Python dependencies
- Lambda function URL or API Gateway HTTP API for Slack events HTTP request url
- Secrets Manager secrets for Slack bot token and signing secret
- CloudWatch log groups for logging
- IAM roles and policies
- Parameter Store for generated Slack App manifest

It ships with sample lambda function code so you can verify functionality. You can also use your own code - see [Customization](#customization) below.

## Customization

### Using Your Own Lambda Code

| Mode | When to Use | Configuration |
|------|-------------|---------------|
| **Default** | Quick prototyping with included sample | No extra config. Uses `lambda/index.py`. After deploy, use [Console-to-IDE](https://aws.amazon.com/blogs/aws/simplify-serverless-development-with-console-to-ide-and-remote-debugging-for-aws-lambda/) for development. |
| **Directory** | Terraform-managed custom code deployment | `lambda_source_type = "directory"`<br/>`lambda_source_path = "/path/to/code"` |
| **ZIP** | CI/CD builds zip, Terraform deploys | `lambda_source_type = "zip"`<br/>`lambda_source_path = "/path/to/lambda.zip"` |

### Managing Dependencies

Override the default requirements.txt:

```hcl
# Option 1: Inline
requirements_inline = ["boto3==1.34.131", "slack-bolt>=1.21,<2"]

# Option 2: Custom file
requirements_txt_override_path = "/path/to/requirements.txt"
```

**Note:** Docker is required to build the Lambda layer.

## Advanced Configuration

<details>
<summary><strong>Lambda Function URL vs API Gateway</strong></summary>

Control the endpoint type with `create_api_gateway`:

**Lambda Function URL** (default: `create_api_gateway = false`)
- Simplest, lowest-cost, fastest latency
- No custom domain or WAF support
- Best for: Prototypes and dev environments

**API Gateway HTTP API** (`create_api_gateway = true`)
- Supports custom domains, WAF, advanced logging
- Higher cost, slight latency overhead
- Best for: Production deployments

The module outputs `slack_bot_endpoint_url` with the correct URL for Slack.
</details>

<details>
<summary><strong>Observability with Application Signals</strong></summary>

Set `enable_application_signals = true` to enable AWS OpenTelemetry auto-instrumentation for traces and metrics. This adds runtime overhead and observability costs.
</details>

## Troubleshooting

### Common Issues

1. **"Invalid signature" or "dispatch_failed" errors**: Verify your signing secret is correct
2. **Bot not responding**: Check CloudWatch logs for Lambda errors
3. **Permission denied**: Ensure your bot has the required OAuth scopes
4. **Timeout errors**: Increase `lambda_timeout` if needed

### Logs

Check CloudWatch logs for the Lambda function:
```bash
aws logs tail /aws/lambda/your-function-name --follow
```

---

<!-- BEGIN_TF_DOCS -->
<details>
<summary><strong>📋 Full Terraform Reference</strong></summary>



## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.11.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.7.1 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_time"></a> [time](#provider\_time) | 0.11.2 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_lambda_layer_arns"></a> [additional\_lambda\_layer\_arns](#input\_additional\_lambda\_layer\_arns) | Additional Lambda layer ARNs to attach to the function. Ensure layers match the selected lambda\_architecture. | `list(string)` | `[]` | no |
| <a name="input_bedrock_model_id"></a> [bedrock\_model\_id](#input\_bedrock\_model\_id) | The Bedrock model ID to use for AI responses | `string` | `"anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_bedrock_model_inference_profile"></a> [bedrock\_model\_inference\_profile](#input\_bedrock\_model\_inference\_profile) | Inference profile ID to use | `string` | `"us.anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_create_api_gateway"></a> [create\_api\_gateway](#input\_create\_api\_gateway) | If true, create API Gateway instead of Lambda Function URL. Lambda Function URL is recommended for most use cases due to simplicity and lower cost. | `bool` | `false` | no |
| <a name="input_enable_application_signals"></a> [enable\_application\_signals](#input\_enable\_application\_signals) | If true, enables Application signals for monitoring and observability. | `bool` | `false` | no |
| <a name="input_enable_powertools_layer"></a> [enable\_powertools\_layer](#input\_enable\_powertools\_layer) | Enable AWS Lambda Powertools Python layer for enhanced logging and tracing | `bool` | `true` | no |
| <a name="input_enable_snapstart"></a> [enable\_snapstart](#input\_enable\_snapstart) | Enable SnapStart for faster cold starts (Java 11+ runtimes only). Cannot be used with provisioned concurrency. | `bool` | `false` | no |
| <a name="input_enable_sqs_processing"></a> [enable\_sqs\_processing](#input\_enable\_sqs\_processing) | Enable async SQS processing for Slack events | `bool` | `true` | no |
| <a name="input_lambda_architecture"></a> [lambda\_architecture](#input\_lambda\_architecture) | Instruction set architecture for Lambda function | `string` | `"x86_64"` | no |
| <a name="input_lambda_env_vars"></a> [lambda\_env\_vars](#input\_lambda\_env\_vars) | Environment variables to add to Lambda | `map(string)` | <pre>{<br/>  "BEDROCK_MODEL_INFERENCE_PROFILE": "us.anthropic.claude-3-5-sonnet-20241022-v2:0"<br/>}</pre> | no |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Name of the Lambda function | `string` | `"terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_lambda_layer_name"></a> [lambda\_layer\_name](#input\_lambda\_layer\_name) | Name of the Lambda layer | `string` | `"terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_lambda_source_path"></a> [lambda\_source\_path](#input\_lambda\_source\_path) | Path to custom Lambda function source code (zip file or directory) | `string` | `"./lambda"` | no |
| <a name="input_lambda_source_type"></a> [lambda\_source\_type](#input\_lambda\_source\_type) | Type of Lambda source: 'default', 'zip', or 'directory' | `string` | `"default"` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda function timeout in seconds | `number` | `30` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs in CloudWatch | `number` | `731` | no |
| <a name="input_opentelemetry_python_layer_arns"></a> [opentelemetry\_python\_layer\_arns](#input\_opentelemetry\_python\_layer\_arns) | Map of AWS region to OpenTelemetry Lambda Layer ARN for Python. | `map(string)` | <pre>{<br/>  "af-south-1": "arn:aws:lambda:af-south-1:904233096616:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ap-east-1": "arn:aws:lambda:ap-east-1:888577020596:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ap-northeast-1": "arn:aws:lambda:ap-northeast-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "ap-northeast-2": "arn:aws:lambda:ap-northeast-2:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "ap-northeast-3": "arn:aws:lambda:ap-northeast-3:615299751070:layer:AWSOpenTelemetryDistroPython:12",<br/>  "ap-south-1": "arn:aws:lambda:ap-south-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "ap-south-2": "arn:aws:lambda:ap-south-2:796973505492:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ap-southeast-1": "arn:aws:lambda:ap-southeast-1:615299751070:layer:AWSOpenTelemetryDistroPython:12",<br/>  "ap-southeast-2": "arn:aws:lambda:ap-southeast-2:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "ap-southeast-3": "arn:aws:lambda:ap-southeast-3:039612877180:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ap-southeast-4": "arn:aws:lambda:ap-southeast-4:713881805771:layer:AWSOpenTelemetryDistroPython:10",<br/>  "ca-central-1": "arn:aws:lambda:ca-central-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-central-1": "arn:aws:lambda:eu-central-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-central-2": "arn:aws:lambda:eu-central-2:156041407956:layer:AWSOpenTelemetryDistroPython:10",<br/>  "eu-north-1": "arn:aws:lambda:eu-north-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-south-1": "arn:aws:lambda:eu-south-1:257394471194:layer:AWSOpenTelemetryDistroPython:10",<br/>  "eu-south-2": "arn:aws:lambda:eu-south-2:490004653786:layer:AWSOpenTelemetryDistroPython:10",<br/>  "eu-west-1": "arn:aws:lambda:eu-west-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-west-2": "arn:aws:lambda:eu-west-2:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "eu-west-3": "arn:aws:lambda:eu-west-3:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "il-central-1": "arn:aws:lambda:il-central-1:746669239226:layer:AWSOpenTelemetryDistroPython:10",<br/>  "me-central-1": "arn:aws:lambda:me-central-1:739275441131:layer:AWSOpenTelemetryDistroPython:10",<br/>  "me-south-1": "arn:aws:lambda:me-south-1:980921751758:layer:AWSOpenTelemetryDistroPython:10",<br/>  "sa-east-1": "arn:aws:lambda:sa-east-1:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "us-east-1": "arn:aws:lambda:us-east-1:615299751070:layer:AWSOpenTelemetryDistroPython:16",<br/>  "us-east-2": "arn:aws:lambda:us-east-2:615299751070:layer:AWSOpenTelemetryDistroPython:13",<br/>  "us-west-1": "arn:aws:lambda:us-west-1:615299751070:layer:AWSOpenTelemetryDistroPython:20",<br/>  "us-west-2": "arn:aws:lambda:us-west-2:615299751070:layer:AWSOpenTelemetryDistroPython:20"<br/>}</pre> | no |
| <a name="input_provisioned_concurrency_count"></a> [provisioned\_concurrency\_count](#input\_provisioned\_concurrency\_count) | Enable provisioned concurrency for the Lambda to eliminate cold starts | `number` | `1` | no |
| <a name="input_python_version"></a> [python\_version](#input\_python\_version) | Python version for the Lambda layer | `string` | `"3.12"` | no |
| <a name="input_requirements_inline"></a> [requirements\_inline](#input\_requirements\_inline) | Inline list of Python dependency specifiers to render into a requirements.txt for the Lambda layer. Takes precedence over requirements\_txt\_override\_path when non-empty. | `list(string)` | `[]` | no |
| <a name="input_requirements_txt_override_path"></a> [requirements\_txt\_override\_path](#input\_requirements\_txt\_override\_path) | Path to a requirements.txt file to use for building the Lambda layer (takes precedence over the module's default when provided). | `string` | `""` | no |
| <a name="input_slack_app_description"></a> [slack\_app\_description](#input\_slack\_app\_description) | Description of the Slack app assistant | `string` | `"Hi, I am an assistant built using Bolt for Python. I am here to help you out!"` | no |
| <a name="input_slack_app_name"></a> [slack\_app\_name](#input\_slack\_app\_name) | Name of the Slack app in the manifest | `string` | `"Bolt Python Assistant"` | no |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | The Slack bot token for authentication | `string` | `"xoxb-"` | no |
| <a name="input_slack_signing_secret"></a> [slack\_signing\_secret](#input\_slack\_signing\_secret) | The Slack signing secret for verification | `string` | `"asigningsecret"` | no |
| <a name="input_slack_slash_command"></a> [slack\_slash\_command](#input\_slack\_slash\_command) | Slash command for the Slack app | `string` | `"/start-process"` | no |
| <a name="input_slack_slash_command_description"></a> [slack\_slash\_command\_description](#input\_slack\_slash\_command\_description) | The description for the slash command | `string` | `"Ask a question to the Bedrock bot"` | no |
| <a name="input_sqs_batch_size"></a> [sqs\_batch\_size](#input\_sqs\_batch\_size) | Maximum number of SQS messages to process in a single Lambda invocation | `number` | `10` | no |
| <a name="input_sqs_maximum_concurrency"></a> [sqs\_maximum\_concurrency](#input\_sqs\_maximum\_concurrency) | Maximum number of concurrent Lambda functions that can be invoked by SQS | `number` | `2` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_id"></a> [api\_gateway\_id](#output\_api\_gateway\_id) | The ID of the API Gateway (if created) |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | The ARN of the Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | The name of the Lambda function |
| <a name="output_lambda_layer_arn"></a> [lambda\_layer\_arn](#output\_lambda\_layer\_arn) | The ARN of the Lambda layer (if created) |
| <a name="output_lambda_layer_version"></a> [lambda\_layer\_version](#output\_lambda\_layer\_version) | The version of the Lambda layer (if created) |
| <a name="output_slack_app_manifest_content"></a> [slack\_app\_manifest\_content](#output\_slack\_app\_manifest\_content) | The content of the generated Slack app manifest |
| <a name="output_slack_app_manifest_file"></a> [slack\_app\_manifest\_file](#output\_slack\_app\_manifest\_file) | The path to the generated Slack app manifest file |
| <a name="output_slack_bot_endpoint_url"></a> [slack\_bot\_endpoint\_url](#output\_slack\_bot\_endpoint\_url) | The URL used to verify the Slack app (API Gateway or Lambda Function URL) |
| <a name="output_slack_bot_token_console_url"></a> [slack\_bot\_token\_console\_url](#output\_slack\_bot\_token\_console\_url) | The AWS console URL for the Slack bot token secret |
| <a name="output_slack_bot_token_secret_arn"></a> [slack\_bot\_token\_secret\_arn](#output\_slack\_bot\_token\_secret\_arn) | The ARN of the Secrets Manager secret containing the Slack bot token |
| <a name="output_slack_bot_token_secret_name"></a> [slack\_bot\_token\_secret\_name](#output\_slack\_bot\_token\_secret\_name) | The name of the Secrets Manager secret containing the Slack bot token |

## Resources

| Name | Type |
|------|------|
| [aws_apigatewayv2_api.slack_bot_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.slack_bot_integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.slack_bot_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.slack_bot_endpoint_default_stage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.slack_bot_api_access_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.slack_bot_lambda_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.slack_bot_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.slack_bot_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_application_signals](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_alias.slack_bot_lambda_live](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_alias) | resource |
| [aws_lambda_event_source_mapping.sqs_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.slack_bot_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function_url.slack_bot_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url) | resource |
| [aws_lambda_layer_version.dependencies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_layer_version) | resource |
| [aws_lambda_permission.api_gateway_lambda_permission](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.function_url_invoke_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.function_url_invoke_function_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_provisioned_concurrency_config.slack_bot_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_provisioned_concurrency_config) | resource |
| [aws_secretsmanager_secret.slack_bot_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.slack_signing_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.slack_bot_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.slack_signing_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_sqs_queue.slackbot](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_ssm_parameter.slack_app_manifest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [local_file.requirements_inline_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.slack_app_manifest](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [terraform_data.init_build_directories](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.lambda_build_init](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.lambda_code](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.lambda_code_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.lambda_layer_build](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [time_static.slack_bot_token_update](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [time_static.slack_signing_secret_update](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
</details>
<!-- END_TF_DOCS -->
