# Terraform AWS VPC Module - Development Guide

## Commands

- **Lint**: `pre-commit run -a` (runs all pre-commit hooks)
- **Format**: `terraform fmt` (formats Terraform code)
- **Validate**: `terraform validate` (validates Terraform configuration)
- **Security Check**: `checkov -d .` (scans for security issues)
- **Documentation**: `terraform-docs markdown . > README.md` (generates documentation)
- **Test**: `pytest -v` (runs Python tests)
- **Single Test**: `pytest -v tests/test_file.py::test_function` (run specific test)

## Code Style Guidelines

- **Terraform**: Use HCL syntax with consistent 2-space indentation
- **Naming**: Use snake_case for resources and variables
- **Documentation**: All modules must have README.md with inputs/outputs
- **Variables**: Include type, description, and default where appropriate
- **Commits**: Follow semantic commit format (feat/fix/docs/test/chore)
- **Security**: No hardcoded credentials, use variables for sensitive data
- **Versioning**: Specify provider versions in versions.tf
- **Error Handling**: Use conditionals for potential errors
- **Markdown**: Follow markdownlint rules

## PR Process

Before submitting, run `pre-commit run -a` to ensure code quality and update README.md with any changes to variables or outputs.
