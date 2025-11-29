# Lambda Function URL Example

This example demonstrates how to deploy the Slack bot using an AWS Lambda Function URL (which is now the default behavior).

## Terraform Code

```hcl
module "slack_bot" {
  source = "../.."

  slack_bot_token      = var.slack_bot_token
  bedrock_model_id     = var.bedrock_model_id
  slack_signing_secret = var.slack_signing_secret
  tags                 = var.tags

  # Lambda Function URL is now the default
  # No need to set create_api_gateway (defaults to false)
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

<!-- BEGIN_TF_DOCS -->
<details>
<summary><strong>📋 Full Terraform Reference</strong></summary>



## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |

## Providers

No providers.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bedrock_model_id"></a> [bedrock\_model\_id](#input\_bedrock\_model\_id) | The Bedrock model ID to use for AI responses | `string` | `"anthropic.claude-3-5-sonnet-20241022-v2:0"` | no |
| <a name="input_function_url"></a> [function\_url](#input\_function\_url) | The Lambda Function URL to use in the Slack manifest (only used when create\_api\_gateway is false). | `string` | `""` | no |
| <a name="input_lambda_function_name"></a> [lambda\_function\_name](#input\_lambda\_function\_name) | Name of the Lambda function | `string` | `"lambda-function-url-terraform-aws-slackbot-lambdalith"` | no |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | The Slack bot token for authentication | `string` | n/a | yes |
| <a name="input_slack_signing_secret"></a> [slack\_signing\_secret](#input\_slack\_signing\_secret) | The Slack signing secret for verification | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | The ARN of the Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | The name of the Lambda function |
| <a name="output_slack_bot_endpoint_url"></a> [slack\_bot\_endpoint\_url](#output\_slack\_bot\_endpoint\_url) | The URL used to verify the Slack app (API Gateway or Lambda Function URL) |

## Resources

No resources.
</details>
<!-- END_TF_DOCS -->