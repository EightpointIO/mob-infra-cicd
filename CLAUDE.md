# Mobile Infrastructure CI/CD - Technical Implementation Guide

## Overview

The Mobile Infrastructure CI/CD repository provides a centralized, standardized continuous integration and deployment pipeline for all mobile infrastructure repositories. This system ensures consistent deployment processes, security scanning, and quality gates across iOS and Android team infrastructure while maintaining team-specific configurations and environments.

## Architecture and Design Philosophy

### Centralized Workflow Pattern

The CI/CD system follows a centralized workflow pattern similar to `ios-api-cicd`, providing:

1. **Consistency**: Uniform deployment processes across all infrastructure repositories
2. **Maintainability**: Single source of truth for CI/CD logic and configurations
3. **Security**: Centralized security scanning and compliance checking
4. **Scalability**: Easy addition of new teams and repositories
5. **Automation**: Reduced manual intervention and human error

### Repository Structure and Components

```
cicd/
├── .github/workflows/
│   └── ci.yml                    # Main centralized workflow
├── scripts/
│   ├── core/                     # Core utility scripts
│   │   ├── compliance-checker.sh      # Security and compliance validation
│   │   ├── dependency-updater.sh      # Automated dependency management
│   │   ├── health-reporter.sh         # Infrastructure health monitoring
│   │   └── maintenance-check.sh       # Routine maintenance operations
│   ├── helpers/                  # Helper utility scripts
│   │   ├── aws-helpers.sh             # AWS-specific operations
│   │   ├── dynamic-repo-discovery.sh  # Repository discovery automation
│   │   ├── slack-notifications.sh     # Slack integration utilities
│   │   └── terraform-helpers.sh       # Terraform utility functions
│   ├── enhanced-workspace-setup.sh    # Workspace initialization
│   ├── infrastructure-manager.sh      # Main orchestration script
│   ├── bulk-operations.sh            # Bulk operations across repositories
│   └── logs/, reports/, temp/         # Runtime directories
├── policies/
│   └── checkov/                  # Custom security policies
│       └── custom_policies.py         # Security scanning rules
├── configs/
│   ├── team-mappings.json        # Team configuration mappings
│   ├── environment-configs.yaml  # Environment-specific settings
│   └── compliance-checker.config # Compliance checking configuration
└── README.md                     # User documentation
```

## Core Components Deep Dive

### 1. Main CI/CD Workflow (`.github/workflows/ci.yml`)

The central workflow orchestrates all deployment activities:

#### Workflow Triggers
- **Push to main**: Triggers development environment deployment
- **Tag creation (v*.*.*)**: Triggers production environment deployment  
- **Pull requests**: Triggers validation and security scanning

#### Key Workflow Steps
1. **Environment Setup**: AWS authentication, tool installation
2. **Validation**: Terraform format, validation, and security scanning
3. **Planning**: Terraform plan generation and review
4. **Deployment**: Conditional deployment based on environment
5. **Notifications**: Slack notifications for status updates

#### Workflow Inputs
```yaml
inputs:
  OUR_PROJECT_NAME:
    description: "Name of the infrastructure project"
    required: true
    type: string
  
  TEAM_NAME:
    description: "Team name (ios or android)"
    required: true
    type: string
  
  ENVIRONMENT:
    description: "Environment (dev, prod, global)"
    required: true
    type: string
  
  TERRAFORM_VERSION:
    description: "Terraform version to use"
    required: false
    type: string
    default: "1.6.0"
```

### 2. Core Utility Scripts

#### compliance-checker.sh
**Purpose**: Comprehensive security and compliance validation

**Key Features**:
- Terraform security scanning with Checkov
- IAM policy validation
- Security group rule analysis
- Compliance report generation
- Custom policy enforcement

**Usage**:
```bash
./scripts/core/compliance-checker.sh --environment prod --team ios
```

**Configuration**: `configs/compliance-checker.config`
```bash
# Compliance checking configuration
CHECKOV_FRAMEWORK="terraform"
CHECKOV_SEVERITY="MEDIUM,HIGH,CRITICAL"
COMPLIANCE_SKIP_CHECKS="CKV_AWS_79,CKV_AWS_80"
COMPLIANCE_REPORT_FORMAT="json,junit"
```

#### dependency-updater.sh
**Purpose**: Automated dependency management and updates

**Key Features**:
- Terraform provider version management
- Module reference updates
- Dependency conflict resolution
- Automated pull request creation
- Version compatibility checking

**Usage**:
```bash
./scripts/core/dependency-updater.sh --update-providers --create-pr
```

**Configuration**: `configs/dependency-updater.config`
```bash
# Dependency update configuration
UPDATE_PROVIDERS="true"
UPDATE_MODULES="true"
TERRAFORM_VERSION_CONSTRAINT="~> 1.6.0"
AWS_PROVIDER_VERSION="~> 5.0"
```

#### health-reporter.sh
**Purpose**: Infrastructure health monitoring and reporting

**Key Features**:
- Resource status validation
- Cost analysis and optimization
- Performance metrics collection
- Health score calculation
- Automated reporting

**Usage**:
```bash
./scripts/core/health-reporter.sh --full-report --team ios
```

#### maintenance-check.sh
**Purpose**: Routine maintenance operations

**Key Features**:
- Resource cleanup and optimization
- Backup verification
- Security patch checking
- Performance tuning recommendations
- Automated maintenance scheduling

### 3. Helper Scripts

#### aws-helpers.sh
**Purpose**: AWS-specific utility functions

**Key Functions**:
```bash
# AWS authentication and profile management
aws_authenticate() {
  local role_arn=$1
  local session_name=$2
  # OIDC authentication logic
}

# Resource querying and validation
aws_validate_resources() {
  local team=$1
  local environment=$2
  # Resource validation logic
}

# Cost analysis and optimization
aws_cost_analysis() {
  local team=$1
  local environment=$2
  # Cost analysis logic
}
```

#### terraform-helpers.sh
**Purpose**: Terraform utility functions

**Key Functions**:
```bash
# Terraform initialization and configuration
terraform_init() {
  local backend_config=$1
  # Terraform initialization logic
}

# Plan generation and validation
terraform_plan() {
  local plan_file=$1
  # Terraform planning logic
}

# Deployment execution
terraform_apply() {
  local plan_file=$1
  # Terraform apply logic
}
```

#### slack-notifications.sh
**Purpose**: Slack integration and notifications

**Key Functions**:
```bash
# Send deployment notifications
send_deployment_notification() {
  local status=$1
  local environment=$2
  local team=$3
  # Notification logic
}

# Send pull request notifications
send_pr_notification() {
  local pr_url=$1
  local team=$2
  # PR notification logic
}
```

### 4. Infrastructure Manager Orchestrator

#### infrastructure-manager.sh
**Purpose**: Main orchestration script for infrastructure operations

**Key Features**:
- Interactive menu system
- CLI automation support
- Multi-repository operations
- Health monitoring integration
- Automated workflow execution

**Usage Examples**:
```bash
# Interactive mode
./scripts/infrastructure-manager.sh

# CLI automation
./scripts/infrastructure-manager.sh --health
./scripts/infrastructure-manager.sh --deploy --team ios --env prod
./scripts/infrastructure-manager.sh --compliance --all-teams
```

**Menu Options**:
1. **Health Check**: Comprehensive infrastructure health validation
2. **Deploy**: Deploy infrastructure to specific environments
3. **Compliance**: Security and compliance validation
4. **Maintenance**: Routine maintenance operations
5. **Bulk Operations**: Operations across multiple repositories
6. **Reports**: Generate comprehensive reports
7. **Setup**: Initialize workspace and configurations

### 5. Configuration Management

#### team-mappings.json
**Purpose**: Team configuration and mappings

```json
{
  "teams": {
    "ios": {
      "aws_role_arn": "arn:aws:iam::ACCOUNT:role/GitHubActions-ios-{environment}",
      "slack_channel": "#ios-infrastructure",
      "reviewers": ["ios-team-lead", "ios-senior-dev"],
      "environments": ["dev", "prod", "global"]
    },
    "android": {
      "aws_role_arn": "arn:aws:iam::ACCOUNT:role/GitHubActions-android-{environment}",
      "slack_channel": "#android-infrastructure",
      "reviewers": ["android-team-lead", "android-senior-dev"],
      "environments": ["dev", "prod", "global"]
    }
  },
  "environments": {
    "dev": {
      "auto_deploy": true,
      "require_approval": false,
      "notification_level": "basic"
    },
    "prod": {
      "auto_deploy": false,
      "require_approval": true,
      "notification_level": "detailed"
    },
    "global": {
      "auto_deploy": true,
      "require_approval": false,
      "notification_level": "summary"
    }
  }
}
```

#### environment-configs.yaml
**Purpose**: Environment-specific configurations

```yaml
environments:
  dev:
    terraform_version: "1.6.0"
    aws_region: "us-east-1"
    checkov_severity: "MEDIUM,HIGH,CRITICAL"
    backup_retention: "7d"
    monitoring_level: "basic"
  
  prod:
    terraform_version: "1.6.0"
    aws_region: "us-east-1"
    checkov_severity: "HIGH,CRITICAL"
    backup_retention: "30d"
    monitoring_level: "comprehensive"
  
  global:
    terraform_version: "1.6.0"
    aws_region: "us-east-1"
    checkov_severity: "MEDIUM,HIGH,CRITICAL"
    backup_retention: "14d"
    monitoring_level: "standard"
```

## Workflow Integration Patterns

### 1. Repository Integration

To integrate with the centralized CI/CD system, add this workflow to any infrastructure repository:

```yaml
# .github/workflows/ci.yml
name: Infrastructure CI/CD Pipeline

on:
  push:
    branches: [main]
    tags: ['v*.*.*']
  pull_request:
    branches: [main]
    
permissions:
  contents: read
  pull-requests: write
  id-token: write
  security-events: write

jobs:
  call_central_ci:
    uses: EightpointIO/mob-infra-cicd/.github/workflows/ci.yml@main
    with:
      OUR_PROJECT_NAME: "eks"
      TEAM_NAME: "ios"
      ENVIRONMENT: "prod"
      TERRAFORM_VERSION: "1.6.0"
      
    secrets: inherit
```

### 2. Pull Request Workflow

**Trigger**: Pull request creation or updates

**Actions**:
1. **Reviewer Assignment**: Automatic assignment based on team membership
2. **Format Validation**: Terraform format checking
3. **Security Scanning**: Checkov security policy validation
4. **Plan Generation**: Terraform plan creation and review
5. **Notification**: Slack notification to team channel
6. **PR Comments**: Detailed results posted as PR comments

**Example PR Comment**:
```markdown
## Infrastructure CI/CD Results

### ✅ Format Check
All Terraform files are properly formatted.

### ✅ Security Scan
No security issues found. Scanned with Checkov.

### 📋 Terraform Plan
```
Plan: 3 to add, 2 to change, 0 to destroy.
```

### 📊 Cost Impact
Estimated monthly cost change: +$45.67

### 🔗 Detailed Reports
- [Full Security Report](link-to-report)
- [Terraform Plan Details](link-to-plan)
```

### 3. Development Deployment

**Trigger**: Push to main branch

**Actions**:
1. **Validation**: Complete validation pipeline
2. **Deployment**: Automated deployment to development environment
3. **Health Check**: Post-deployment health validation
4. **Notification**: Success/failure notification to team

**Deployment Steps**:
```bash
# 1. Initialize Terraform
terraform init -backend-config="bucket=dev-terraform-state"

# 2. Plan deployment
terraform plan -out=plan.out -var-file="dev.tfvars"

# 3. Apply changes
terraform apply plan.out

# 4. Validate deployment
./scripts/core/health-reporter.sh --validate-deployment
```

### 4. Production Deployment

**Trigger**: Git tag creation (v*.*.*)

**Actions**:
1. **Enhanced Validation**: Comprehensive security and compliance checking
2. **Manual Approval**: GitHub Environment approval requirement
3. **Staged Deployment**: Careful deployment with rollback capability
4. **Monitoring**: Enhanced monitoring and alerting
5. **Notification**: Detailed notifications to stakeholders

**Production Deployment Pipeline**:
```yaml
production_deploy:
  environment: production
  needs: [validation, security_scan]
  steps:
    - name: Enhanced Security Scan
      run: |
        ./scripts/core/compliance-checker.sh --strict --team ${{ inputs.TEAM_NAME }}
    
    - name: Manual Approval Gate
      uses: actions/github-script@v6
      # Manual approval logic
    
    - name: Production Deployment
      run: |
        terraform apply -auto-approve -var-file="prod.tfvars"
        ./scripts/core/health-reporter.sh --production-validation
```

## Security and Compliance Framework

### 1. Security Scanning Integration

#### Checkov Integration
The system integrates Checkov for comprehensive security scanning:

**Custom Policies** (`policies/checkov/custom_policies.py`):
```python
from checkov.common.models.enums import TRUE_VALUES
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class CustomSecurityGroupCheck(BaseResourceCheck):
    def __init__(self):
        name = "Ensure security groups don't allow unrestricted access"
        id = "CKV_CUSTOM_1"
        supported_resources = ['aws_security_group']
        super().__init__(name=name, id=id, categories=['networking'], supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        # Custom security validation logic
        return CheckResult.PASSED
```

#### Security Compliance Checks
- **IAM Policy Validation**: Least privilege principle enforcement
- **Network Security**: Security group and NACL validation
- **Encryption**: At-rest and in-transit encryption verification
- **Access Control**: Resource access pattern validation
- **Compliance**: SOC2, HIPAA, and other compliance framework checks

### 2. Authentication and Authorization

#### OIDC Authentication
```yaml
permissions:
  id-token: write
  contents: read
  
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
```

#### Role-Based Access Control
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:sub": "repo:EightpointIO/mob-infra-ios-dev:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## Monitoring and Observability

### 1. Health Monitoring

#### Infrastructure Health Checks
```bash
# Comprehensive health validation
./scripts/core/health-reporter.sh --full-report --team ios

# Output format:
# ✅ Network: VPC and subnets healthy
# ✅ EKS: Cluster nodes ready, pods running
# ⚠️  Database: High connection count
# ✅ Lambda: Functions responding normally
# ✅ S3: Buckets accessible, lifecycle policies active
```

#### Performance Metrics
- **Deployment Duration**: Track deployment time trends
- **Success Rate**: Monitor deployment success/failure rates
- **Resource Utilization**: Track AWS resource usage patterns
- **Cost Optimization**: Monitor cost trends and optimization opportunities

### 2. Alerting and Notifications

#### Slack Integration
```bash
# Send deployment notification
./scripts/helpers/slack-notifications.sh \
  --webhook "$SLACK_WEBHOOK_URL" \
  --message "iOS production deployment completed successfully" \
  --team "ios" \
  --environment "prod" \
  --status "success"
```

#### Alert Categories
- **Deployment Status**: Success/failure notifications
- **Security Issues**: Security scan failures and vulnerabilities
- **Health Degradation**: Infrastructure health issues
- **Cost Alerts**: Unusual cost increases or budget thresholds

## Troubleshooting and Operations

### 1. Common Issues and Solutions

#### Deployment Failures
**Issue**: Terraform apply fails with resource conflicts

**Solution**:
```bash
# Check resource state
terraform state list | grep conflicted_resource

# Import existing resource if needed
terraform import aws_instance.example i-1234567890abcdef0

# Refresh state
terraform refresh

# Retry deployment
terraform apply
```

#### Security Scan Failures
**Issue**: Checkov security scan fails with policy violations

**Solution**:
```bash
# Run detailed security scan
./scripts/core/compliance-checker.sh --detailed --team ios

# Review specific failures
cat reports/security-scan-results.json | jq '.failed_checks[]'

# Apply fixes or add skip annotations
# skip_check = "CKV_AWS_79"
```

#### Authentication Issues
**Issue**: OIDC authentication fails

**Solution**:
```bash
# Verify role ARN and trust policy
aws sts get-caller-identity

# Check GitHub token permissions
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user

# Validate OIDC provider configuration
aws iam get-openid-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com
```

### 2. Debug and Diagnostic Tools

#### Debug Mode
```bash
# Enable debug logging
export CI_DEBUG=true
export TF_LOG=DEBUG

# Run workflow with debug output
./scripts/infrastructure-manager.sh --debug --health
```

#### Log Analysis
```bash
# View deployment logs
cat logs/deployment-$(date +%Y%m%d).log

# Analyze error patterns
grep -E "(ERROR|FAILED)" logs/*.log | sort | uniq -c
```

## Best Practices and Recommendations

### 1. Development Workflow

#### For Team Developers
1. **Branch Strategy**: Use feature branches for infrastructure changes
2. **PR Reviews**: Always require peer review for infrastructure changes
3. **Testing**: Test changes in development environment first
4. **Documentation**: Update documentation with infrastructure changes

#### For Infrastructure Administrators
1. **Version Management**: Use semantic versioning for CI/CD updates
2. **Monitoring**: Regular health checks and performance monitoring
3. **Security**: Regular security audits and policy updates
4. **Backup**: Maintain backup strategies for critical infrastructure

### 2. Security Best Practices

#### Access Control
- Use least privilege IAM policies
- Implement multi-factor authentication
- Regular access reviews and cleanup
- Use temporary credentials (OIDC)

#### Code Security
- No hardcoded secrets in code
- Use AWS Secrets Manager for sensitive data
- Implement code scanning in CI/CD
- Regular dependency updates

### 3. Operational Excellence

#### Monitoring
- Implement comprehensive monitoring
- Set up proactive alerting
- Regular performance reviews
- Cost optimization monitoring

#### Automation
- Automate routine operations
- Implement self-healing mechanisms
- Use infrastructure as code principles
- Continuous integration and deployment

## Advanced Features

### 1. Bulk Operations

#### Multi-Repository Operations
```bash
# Bulk format across all repositories
./scripts/bulk-operations.sh --format --all-teams

# Bulk security scan
./scripts/bulk-operations.sh --security-scan --team ios

# Bulk dependency updates
./scripts/bulk-operations.sh --update-dependencies --create-prs
```

### 2. Dynamic Repository Discovery

#### Automated Repository Detection
```bash
# Discover all team repositories
./scripts/helpers/dynamic-repo-discovery.sh --team ios

# Generate configuration for new repositories
./scripts/helpers/dynamic-repo-discovery.sh --generate-config --team android
```

### 3. Advanced Reporting

#### Comprehensive Reports
```bash
# Generate weekly infrastructure report
./scripts/core/health-reporter.sh --weekly-report --all-teams

# Cost analysis report
./scripts/core/health-reporter.sh --cost-analysis --team ios --environment prod

# Security compliance report
./scripts/core/compliance-checker.sh --compliance-report --format pdf
```

## Integration with Infrastructure Manager

### 1. Orchestrator Integration

The CI/CD system integrates seamlessly with the Infrastructure Manager orchestrator:

```bash
# CI/CD pipeline triggers orchestrator
./scripts/infrastructure-manager.sh --ci-mode --team ios --environment prod

# Orchestrator provides enhanced capabilities
./scripts/infrastructure-manager.sh --health --report --compliance
```

### 2. Workflow Automation

#### Automated Workflows
- **Daily Health Checks**: Automated infrastructure health validation
- **Weekly Reports**: Comprehensive infrastructure status reports
- **Monthly Compliance**: Security and compliance validation
- **Quarterly Reviews**: Performance and cost optimization reviews

## Conclusion

The Mobile Infrastructure CI/CD system provides a robust, secure, and scalable foundation for infrastructure deployment and management. With comprehensive security scanning, automated deployment pipelines, and extensive monitoring capabilities, teams can efficiently manage their infrastructure while maintaining the highest standards of security and operational excellence.

The system's modular design allows for easy extension and customization while maintaining consistency across teams and environments. The integration with the Infrastructure Manager orchestrator provides unprecedented visibility and control over the entire infrastructure ecosystem.

For additional support, refer to the individual script documentation, use the Infrastructure Manager's interactive help system, or create issues in the repository for specific questions or enhancement requests.