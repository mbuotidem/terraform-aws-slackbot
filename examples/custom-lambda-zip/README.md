# Custom Lambda (ZIP) Example

This example demonstrates how to deploy the Slack bot when you provide a pre-packaged ZIP file for your Lambda function.

## Terraform Code

```hcl
module "slack_bot" {
  source = "../.."

  lambda_function_name = "my-slack-bot"
  slack_bot_token      = "xoxb-your-token"       # Your bot's OAuth token
  slack_signing_secret = "your-signing-secret" # Your app's signing secret
  lambda_source_type   = "zip"
  lambda_source_path   = "./lambda_function.zip"

  tags = {
    Environment = "production"
    Project     = "slack-bot"
  }
}
```

## How to Deploy

First, initialize Terraform:

```bash
terraform init
```

Next, create a `terraform.tfvars` file with your Slack credentials:

```hcl
# terraform.tfvars
slack_bot_token      = "xoxb-your-token-here"
slack_signing_secret = "your-signing-secret"
```

Finally, apply the configuration:

```bash
terraform apply
```

## Additional Information

- **`main.tf`**: Main Terraform configuration.
- **`variables.tf`**: Input variables for the module.
- **`outputs.tf`**: Output values from the module.
- **`terraform.tfvars.example`**: Example variable values.
- **`lambda_function.zip`**: Pre-packaged ZIP file for the Lambda function.
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_slack_bot"></a> [slack\_bot](#module\_slack\_bot) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bedrock_model_id"></a> [bedrock\_model\_id](#input\_bedrock\_model\_id) | The Bedrock model ID to use for AI responses | `string` | `"anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Name of the Lambda function | `string` | `"custom-lambda-zip-terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | The Slack bot token for authentication | `string` | n/a | yes |
| <a name="input_slack_signing_secret"></a> [slack\_signing\_secret](#input\_slack\_signing\_secret) | The Slack signing secret for verification | `string` | `"00000000000000000000000000000000"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | <pre>{<br/>  "Environment": "example",<br/>  "Project": "slack-bot"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the created Lambda function |
| <a name="output_lambda_layer_info"></a> [lambda\_layer\_info](#output\_lambda\_layer\_info) | Information about the Lambda layer |
| <a name="output_secret_manager_console_url"></a> [secret\_manager\_console\_url](#output\_secret\_manager\_console\_url) | AWS console URL to manage the Slack bot token |
| <a name="output_slack_webhook_url"></a> [slack\_webhook\_url](#output\_slack\_webhook\_url) | URL to configure in your Slack app for event subscriptions |
<!-- END_TF_DOCS -->
