.PHONY: help init validate plan apply fmt docs test clean

.SHELLFLAGS := -e -c

help: ## Display this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

init: ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform init -backend=false
	terraform validate

plan: ## Generate Terraform plan
	terraform plan

apply: ## Apply Terraform configuration in all examples with auto-approve
	@for example in examples/*/; do \
		echo "Applying $$example" && \
		cd "$$example" && \
		terraform init && \
		terraform apply -auto-approve && \
		cd - > /dev/null || exit 1; \
	done
destroy: ## Apply Terraform configuration in all examples with auto-approve
	@for example in examples/*/; do \
		echo "Destroying $$example" && \
		cd "$$example" && \
		terraform init && \
		terraform destroy -auto-approve && \
		cd - > /dev/null || exit 1; \
	done

fmt: ## Format Terraform files
	terraform fmt -recursive

docs: ## Generate documentation
	terraform-docs . && \
	terraform-docs ./examples/basic && \
	terraform-docs ./examples/basic-inline-requirements && \
	terraform-docs ./examples/custom-lambda-zip && \
	terraform-docs ./examples/custom-lambda-directory && \
	terraform-docs ./examples/api-gateway

test: ## Run tests on all examples
	@for example in examples/*/; do \
		echo "Testing $$example" && \
		cd "$$example" && \
		terraform init && \
		terraform validate && \
		terraform plan -no-color && \
		cd - > /dev/null || exit 1; \
	done

clean: ## Clean up temporary files
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.tfstate*" -type f -exec rm -f {} + 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -type f -exec rm -f {} + 2>/dev/null || true
	rm -rf .artifacts/

security: ## Run security scan
	trivy config .

lint: ## Run linting
	tflint

pre-commit: ## Run pre-commit hooks
	pre-commit run --all-files

setup-dev: ## Setup development environment
	@echo "Installing development dependencies..."
	@command -v terraform >/dev/null 2>&1 || { echo "Please install Terraform"; exit 1; }
	@command -v terraform-docs >/dev/null 2>&1 || { echo "Please install terraform-docs"; exit 1; }
	@command -v tflint >/dev/null 2>&1 || { echo "Please install tflint"; exit 1; }
	@command -v trivy >/dev/null 2>&1 || { echo "Please install trivy"; exit 1; }
	@command -v pre-commit >/dev/null 2>&1 || { echo "Please install pre-commit"; exit 1; }
	pre-commit install
