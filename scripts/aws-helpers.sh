#!/bin/bash

# AWS Helper Functions for Infrastructure CI/CD
# Used by mob-infrastructure-cicd workflows

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[AWS-INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[AWS-SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[AWS-WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[AWS-ERROR]${NC} $1"
}

# Check AWS CLI installation and version
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        return 1
    fi
    
    local aws_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    log_info "AWS CLI version: $aws_version"
    
    # Check if version is 2.x (recommended)
    if [[ ! "$aws_version" =~ ^2\. ]]; then
        log_warning "AWS CLI v2 is recommended. Current version: $aws_version"
    fi
}

# Verify AWS credentials and permissions
verify_aws_credentials() {
    local required_permissions=("sts:GetCallerIdentity" "s3:ListBucket" "dynamodb:DescribeTable")
    
    log_info "Verifying AWS credentials and permissions"
    
    # Test basic connectivity
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials are not configured or invalid"
        return 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text)
    
    log_success "AWS credentials verified"
    log_info "Account ID: $account_id"
    log_info "User/Role: $user_arn"
    
    # Check if we're using assumed role (OIDC)
    if [[ "$user_arn" == *"assumed-role"* ]]; then
        log_info "Using assumed role (OIDC authentication detected)"
        
        # Extract role name from ARN
        local role_name=$(echo "$user_arn" | cut -d'/' -f2)
        log_info "Role name: $role_name"
    fi
}

# Verify S3 backend accessibility
verify_s3_backend() {
    local bucket_name=${1}
    local region=${2:-"us-east-1"}
    
    if [[ -z "$bucket_name" ]]; then
        log_error "S3 bucket name is required"
        return 1
    fi
    
    log_info "Verifying S3 backend: s3://$bucket_name"
    
    # Check if bucket exists and is accessible
    if aws s3api head-bucket --bucket "$bucket_name" --region "$region" 2>/dev/null; then
        log_success "S3 bucket $bucket_name is accessible"
        
        # Check bucket versioning
        local versioning=$(aws s3api get-bucket-versioning --bucket "$bucket_name" --region "$region" --query Status --output text 2>/dev/null || echo "None")
        log_info "Bucket versioning: $versioning"
        
        if [[ "$versioning" != "Enabled" ]]; then
            log_warning "S3 bucket versioning is not enabled. Consider enabling for state history."
        fi
        
        # Check encryption
        if aws s3api get-bucket-encryption --bucket "$bucket_name" --region "$region" &>/dev/null; then
            log_success "S3 bucket encryption is enabled"
        else
            log_warning "S3 bucket encryption is not enabled"
        fi
        
        return 0
    else
        log_error "S3 bucket $bucket_name is not accessible or does not exist"
        return 1
    fi
}

# Verify DynamoDB lock table
verify_dynamodb_lock_table() {
    local table_name=${1}
    local region=${2:-"us-east-1"}
    
    if [[ -z "$table_name" ]]; then
        log_error "DynamoDB table name is required"
        return 1
    fi
    
    log_info "Verifying DynamoDB lock table: $table_name"
    
    # Check if table exists and get details
    if aws dynamodb describe-table --table-name "$table_name" --region "$region" &>/dev/null; then
        local table_status=$(aws dynamodb describe-table --table-name "$table_name" --region "$region" --query Table.TableStatus --output text)
        log_success "DynamoDB table $table_name exists with status: $table_status"
        
        # Check if table has the required key schema for Terraform locking
        local key_schema=$(aws dynamodb describe-table --table-name "$table_name" --region "$region" --query 'Table.KeySchema[0].AttributeName' --output text)
        
        if [[ "$key_schema" == "LockID" ]]; then
            log_success "DynamoDB table has correct key schema for Terraform locking"
        else
            log_warning "DynamoDB table key schema might not be correct for Terraform locking. Expected: LockID, Got: $key_schema"
        fi
        
        return 0
    else
        log_error "DynamoDB table $table_name is not accessible or does not exist"
        return 1
    fi
}

# Check AWS resource limits and quotas
check_aws_limits() {
    local region=${1:-"us-east-1"}
    
    log_info "Checking AWS service limits in region $region"
    
    # Check EC2 limits
    if command -v aws &> /dev/null; then
        # VPC limit
        local vpcs_used=$(aws ec2 describe-vpcs --region "$region" --query 'length(Vpcs)' --output text 2>/dev/null || echo "unknown")
        log_info "VPCs in use: $vpcs_used (default limit: 5)"
        
        # Security Groups limit  
        local sgs_used=$(aws ec2 describe-security-groups --region "$region" --query 'length(SecurityGroups)' --output text 2>/dev/null || echo "unknown")
        log_info "Security Groups in use: $sgs_used (default limit: 2500 per VPC)"
        
        # EIP limit
        local eips_used=$(aws ec2 describe-addresses --region "$region" --query 'length(Addresses)' --output text 2>/dev/null || echo "unknown")
        log_info "Elastic IPs in use: $eips_used (default limit: 5)"
    fi
}

# Validate IAM permissions for Terraform operations
validate_terraform_permissions() {
    local team_name=${1:-""}
    local environment=${2:-""}
    
    log_info "Validating IAM permissions for Terraform operations"
    
    # List of essential permissions for Terraform
    local essential_actions=(
        "ec2:Describe*"
        "s3:GetObject"
        "s3:PutObject"
        "dynamodb:GetItem"
        "dynamodb:PutItem"
        "dynamodb:DeleteItem"
        "sts:GetCallerIdentity"
    )
    
    # Test basic permissions by attempting to describe resources
    local permissions_ok=true
    
    # Test EC2 permissions
    if aws ec2 describe-regions --region us-east-1 &>/dev/null; then
        log_success "EC2 describe permissions verified"
    else
        log_error "EC2 describe permissions missing"
        permissions_ok=false
    fi
    
    # Test S3 permissions (if bucket name provided)
    if [[ -n "$team_name" && -n "$environment" ]]; then
        local bucket_name="$team_name-$environment-terraform-state"
        if aws s3 ls "s3://$bucket_name" &>/dev/null; then
            log_success "S3 permissions verified for $bucket_name"
        else
            log_warning "S3 permissions could not be verified for $bucket_name"
        fi
    fi
    
    if [[ "$permissions_ok" == "true" ]]; then
        log_success "Basic IAM permissions validated"
        return 0
    else
        log_error "Some IAM permissions are missing"
        return 1
    fi
}

# Get AWS account information
get_aws_account_info() {
    log_info "Retrieving AWS account information"
    
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "Cannot retrieve AWS account information"
        return 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text)
    local user_id=$(aws sts get-caller-identity --query UserId --output text)
    
    # Determine account alias if available
    local account_alias=""
    if aws iam list-account-aliases &>/dev/null; then
        account_alias=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null || echo "")
    fi
    
    echo "AWS_ACCOUNT_ID=$account_id"
    echo "AWS_USER_ARN=$user_arn"
    echo "AWS_USER_ID=$user_id"
    if [[ -n "$account_alias" && "$account_alias" != "None" ]]; then
        echo "AWS_ACCOUNT_ALIAS=$account_alias"
    fi
    
    # Export for use in other scripts
    export AWS_ACCOUNT_ID="$account_id"
    export AWS_USER_ARN="$user_arn"
    export AWS_USER_ID="$user_id"
    if [[ -n "$account_alias" && "$account_alias" != "None" ]]; then
        export AWS_ACCOUNT_ALIAS="$account_alias"
    fi
    
    log_success "AWS account information exported"
}

# Check if running in AWS environment (EC2, ECS, Lambda, etc.)
check_aws_environment() {
    log_info "Checking AWS execution environment"
    
    # Check for EC2 instance metadata
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-id &>/dev/null; then
        local instance_id=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-id)
        local instance_type=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/instance-type)
        log_info "Running on EC2 instance: $instance_id ($instance_type)"
        export AWS_EXECUTION_ENV="EC2"
        return 0
    fi
    
    # Check for ECS task metadata
    if [[ -n "${ECS_CONTAINER_METADATA_URI_V4:-}" ]]; then
        log_info "Running in ECS container"
        export AWS_EXECUTION_ENV="ECS"
        return 0
    fi
    
    # Check for Lambda environment
    if [[ -n "${AWS_LAMBDA_FUNCTION_NAME:-}" ]]; then
        log_info "Running in Lambda function: ${AWS_LAMBDA_FUNCTION_NAME}"
        export AWS_EXECUTION_ENV="Lambda"
        return 0
    fi
    
    # Check for GitHub Actions
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        log_info "Running in GitHub Actions"
        export AWS_EXECUTION_ENV="GitHub_Actions"
        return 0
    fi
    
    log_info "Running in local/unknown environment"
    export AWS_EXECUTION_ENV="Local"
}

# Setup AWS CLI configuration for CI/CD
setup_aws_cli_config() {
    local region=${1:-"us-east-1"}
    local output_format=${2:-"json"}
    
    log_info "Setting up AWS CLI configuration"
    
    # Create config directory if it doesn't exist
    mkdir -p ~/.aws
    
    # Set default region and output format
    aws configure set default.region "$region"
    aws configure set default.output "$output_format"
    
    # Set CLI settings optimized for CI/CD
    aws configure set default.cli_pager ""  # Disable pager
    aws configure set default.max_attempts 3
    aws configure set default.retry_mode adaptive
    
    log_success "AWS CLI configuration completed"
    log_info "Default region: $region"
    log_info "Default output: $output_format"
}

# Main execution check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_error "This script should be sourced, not executed directly"
    log_info "Usage: source aws-helpers.sh"
    exit 1
fi

log_info "AWS helper functions loaded successfully"