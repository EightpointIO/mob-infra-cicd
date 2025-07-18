# Mobile Infrastructure CI/CD

Centralized CI/CD workflows for all mobile infrastructure repositories. This repository provides reusable GitHub Actions workflows that standardize deployment, security scanning, and quality gates across all infrastructure projects.

## Overview

This repository follows the same centralized pattern as `ios-api-cicd`, providing consistent CI/CD workflows for infrastructure repositories. Each infrastructure repository calls these centralized workflows with specific parameters.

## Repository Structure

```
mob-infra-cicd/
├── .github/
│   └── workflows/
│       └── ci.yml                   # Main centralized workflow
├── scripts/
│   ├── terraform-helpers.sh         # Terraform utility functions
│   ├── aws-helpers.sh              # AWS-specific utilities
│   └── slack-notifications.sh      # Slack integration helpers
├── policies/
│   ├── checkov/                    # Custom security policies
│   └── tfsec/                      # Custom tfsec rules
├── configs/
│   ├── team-mappings.json          # Internal team configurations
│   └── environment-configs.yaml   # Environment-specific settings
└── README.md
```

## Usage

Add this workflow to any infrastructure repository:

```yaml
# .github/workflows/ci.yml
name: Infrastructure CI/CD Pipeline

on:
  push:
    branches: [main]
    tags: ['v*.*.*']
  pull_request:
    
permissions:
  contents: read
  pull-requests: write
  id-token: write
  security-events: write

jobs:
  call_central_ci:
    uses: EightpointIO/mob-infra-cicd/.github/workflows/ci.yml@main
    with:
      OUR_PROJECT_NAME: "service-name"
      TEAM_NAME: "ios"  # or "android"
      ENVIRONMENT: "dev"  # or "prod"
      TERRAFORM_VERSION: "1.6.0"
      
    secrets: inherit
```

## Workflow Features

### Pull Request Validation
- Automatic reviewer assignment based on team membership
- Terraform format, validation, and planning
- Security scanning with Checkov
- Slack notifications for new PRs
- Detailed PR comments with results

### Development Deployment
- Automatic deployment on merge to main branch
- Quality gates ensure only validated code is deployed
- Slack notifications for deployment status

### Production Deployment
- Tag-based deployment (v*.*.*)
- Manual approval required via GitHub Environments
- Production-specific validations

## Required Secrets

Each infrastructure repository needs these secrets:

```
AWS_ROLE_ARN: arn:aws:iam::ACCOUNT:role/GitHubActions-TEAM-ENV
ACTION_API_TOKEN: GitHub token for API access
SLACK_INFRASTRUCTURE_PR_WEBHOOK_URL: Slack webhook for PR notifications
SLACK_INFRASTRUCTURE_WEBHOOK_URL: Slack webhook for deployment notifications
```

## Team Configuration

Supported teams:
- `ios` - iOS infrastructure team
- `android` - Android infrastructure team

Supported environments:
- `dev` - Development environment
- `prod` - Production environment
- `global` - Team-wide shared resources

## Security

- OIDC authentication with AWS (no long-lived credentials)
- Checkov security scanning with custom policies
- Terraform state encrypted in S3
- Least privilege access patterns

## Examples

### iOS Development Secrets
```yaml
uses: EightpointIO/mob-infra-cicd/.github/workflows/ci.yml@main
with:
  OUR_PROJECT_NAME: "secrets"
  TEAM_NAME: "ios"
  ENVIRONMENT: "dev"
```

### Android Production EKS
```yaml
uses: EightpointIO/mob-infra-cicd/.github/workflows/ci.yml@main
with:
  OUR_PROJECT_NAME: "eks"
  TEAM_NAME: "android"
  ENVIRONMENT: "prod"
  TERRAFORM_VERSION: "1.6.0"
```

## Contributing

When adding new features or policies:
1. Test changes on a development repository first
2. Use semantic versioning for releases
3. Update documentation for new parameters
4. Maintain backward compatibility

## Support

For CI/CD pipeline issues, infrastructure deployment problems, or workflow enhancement requests, contact the DevOps team.