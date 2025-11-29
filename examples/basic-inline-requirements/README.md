# Basic Example with Inline Requirements

This example is identical to `examples/basic` but demonstrates how to override the module's default dependencies using `requirements_inline` in default mode.

## Terraform Code

```hcl
module "slack_bot" {
  source = "../.."

  # Inline dependency overrides for the Lambda layer
  requirements_inline = [
    "boto3==1.39.4",
    "urllib3==2.0.7",
    "slack-bolt>=1.21,<2",
    "slack-sdk>=3.33.1,<4",
    "openai>=1.95.1",
    "backoff==2.2.1",
  ]

  lambda_function_name = "my-slack-bot-inline"
  slack_bot_token      = "xoxb-your-token"       # Your bot's OAuth token
  slack_signing_secret = "your-signing-secret"   # Your app's signing secret
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

- `main.tf`: Main Terraform configuration.
- `variables.tf`: Input variables for the module.
- `outputs.tf`: Output values from the module.
- `terraform.tfvars.example`: Example variable values.
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
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Name of the Lambda function | `string` | `"my-slack-bot-inline"` | no |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | The Slack bot token for authentication | `string` | n/a | yes |
| <a name="input_slack_signing_secret"></a> [slack\_signing\_secret](#input\_slack\_signing\_secret) | Slack signing secret for the app | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | <pre>{<br/>  "Environment": "example",<br/>  "Project": "slack-bot"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the created Lambda function |
| <a name="output_lambda_layer_info"></a> [lambda\_layer\_info](#output\_lambda\_layer\_info) | Information about the Lambda layer |
| <a name="output_secret_manager_console_url"></a> [secret\_manager\_console\_url](#output\_secret\_manager\_console\_url) | AWS console URL to manage the Slack bot token |
| <a name="output_slack_webhook_url"></a> [slack\_webhook\_url](#output\_slack\_webhook\_url) | URL to configure in your Slack app for event subscriptions |
<!-- END_TF_DOCS -->
