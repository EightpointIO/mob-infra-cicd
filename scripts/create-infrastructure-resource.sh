#!/bin/bash

# Infrastructure Resource Creation Script
# Interactive script for creating new infrastructure resources
# Creates GitHub repository, sets up local directory structure, and adds initial Terraform files

set -euo pipefail

# Color definitions for beautiful CLI
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Unicode symbols for beautiful UI
readonly CHECKMARK="✓"
readonly CROSSMARK="✗"
readonly ARROW="→"
readonly BULLET="•"
readonly STAR="★"

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="${SCRIPT_DIR}/logs/create-resource-$(date +%Y%m%d-%H%M%S).log"

# Default configuration
readonly DEFAULT_ORG="your-github-org"
readonly SUPPORTED_TEAMS=("ios" "android")
readonly SUPPORTED_ENVIRONMENTS=("dev" "prod" "global")

# Template directories
readonly TEMPLATES_DIR="${SCRIPT_DIR}/templates"
readonly TERRAFORM_TEMPLATE_DIR="${TEMPLATES_DIR}/terraform"

# Usage information
usage() {
    cat << EOF
${WHITE}Infrastructure Resource Creation Tool${NC}

${CYAN}DESCRIPTION:${NC}
    Interactive script for creating new infrastructure resources following the
    naming convention: {team}-infra-{environment}-{resource}

    This tool will:
    ${BULLET} Create GitHub repository with proper naming
    ${BULLET} Set up local directory structure
    ${BULLET} Generate initial Terraform files
    ${BULLET} Configure repository settings and protections
    ${BULLET} Add initial documentation

${CYAN}USAGE:${NC}
    $SCRIPT_NAME [OPTIONS]

${CYAN}OPTIONS:${NC}
    -o, --org ORG              GitHub organization (default: $DEFAULT_ORG)
    -t, --team TEAM            Team name (ios, android)
    -e, --env ENVIRONMENT      Environment (dev, prod, global)
    -r, --resource RESOURCE    Resource name (e.g., network, storage, compute)
    -d, --description DESC     Repository description
    -p, --private              Create as private repository [default: true]
    --public                   Create as public repository
    -T, --template TEMPLATE    Use custom Terraform template
    -n, --dry-run              Show what would be created without executing
    -i, --interactive          Force interactive mode (default when no args)
    -v, --verbose              Verbose output
    -h, --help                 Show this help message

${CYAN}EXAMPLES:${NC}
    $SCRIPT_NAME                                           # Interactive mode
    $SCRIPT_NAME -t ios -e dev -r network                  # Create ios-infra-dev-network
    $SCRIPT_NAME --team android --env prod --resource s3   # Create android-infra-prod-s3
    $SCRIPT_NAME --dry-run --verbose                       # Preview with verbose output

${CYAN}AUTHENTICATION:${NC}
    Set GITHUB_TOKEN environment variable with a GitHub personal access token.
    Required scopes: repo, admin:repo_hook

EOF
}

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR")   echo -e "${RED}${CROSSMARK} $message${NC}" >&2 ;;
        "WARN")    echo -e "${YELLOW}⚠ $message${NC}" >&2 ;;
        "INFO")    [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${BLUE}ℹ $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}${CHECKMARK} $message${NC}" ;;
        "DEBUG")   [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${PURPLE}🔍 $message${NC}" ;;
        "DRY_RUN") echo -e "${CYAN}[DRY RUN] $message${NC}" ;;
        "PROMPT")  echo -e "${CYAN}${ARROW} $message${NC}" ;;
    esac
}

# Beautiful prompts
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local validation_regex="${3:-.*}"
    local input=""
    
    while true; do
        if [[ -n "$default" ]]; then
            echo -ne "${CYAN}${prompt} ${WHITE}[${default}]:${NC} "
        else
            echo -ne "${CYAN}${prompt}:${NC} "
        fi
        
        read -r input
        
        # Use default if empty
        if [[ -z "$input" && -n "$default" ]]; then
            input="$default"
        fi
        
        # Validate input
        if [[ "$input" =~ $validation_regex ]]; then
            echo "$input"
            return 0
        else
            echo -e "${RED}Invalid input. Please try again.${NC}"
        fi
    done
}

prompt_choice() {
    local prompt="$1"
    shift
    local choices=("$@")
    local input=""
    
    echo -e "${CYAN}${prompt}${NC}"
    for i in "${!choices[@]}"; do
        echo -e "  ${WHITE}$((i+1)).${NC} ${choices[$i]}"
    done
    
    while true; do
        echo -ne "${CYAN}Choose (1-${#choices[@]}):${NC} "
        read -r input
        
        if [[ "$input" =~ ^[0-9]+$ ]] && [[ $input -ge 1 && $input -le ${#choices[@]} ]]; then
            echo "${choices[$((input-1))]}"
            return 0
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#choices[@]}.${NC}"
        fi
    done
}

prompt_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local input=""
    
    while true; do
        if [[ "$default" == "y" ]]; then
            echo -ne "${CYAN}${prompt} ${WHITE}[Y/n]:${NC} "
        else
            echo -ne "${CYAN}${prompt} ${WHITE}[y/N]:${NC} "
        fi
        
        read -r input
        
        # Use default if empty
        if [[ -z "$input" ]]; then
            input="$default"
        fi
        
        case "${input,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     echo -e "${RED}Please answer yes or no.${NC}" ;;
        esac
    done
}

# Initialize environment
init_environment() {
    mkdir -p "$(dirname "$LOG_FILE")" "$TEMPLATES_DIR"
    touch "$LOG_FILE"
    log "INFO" "Initialized environment"
}

# Check GitHub authentication
check_github_auth() {
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log "ERROR" "GITHUB_TOKEN environment variable is not set"
        echo -e "${RED}GitHub authentication required!${NC}"
        echo -e "Please set GITHUB_TOKEN environment variable:"
        echo -e "${YELLOW}export GITHUB_TOKEN='your_github_token'${NC}"
        exit 1
    fi
    
    # Test GitHub API access with required scopes
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3+json" \
                   "https://api.github.com/user" 2>/dev/null || echo "error")
    
    if [[ "$response" == "error" ]] || echo "$response" | grep -q '"message".*"Bad credentials"'; then
        log "ERROR" "Invalid GitHub token or API access failed"
        echo -e "${RED}GitHub authentication failed!${NC}"
        exit 1
    fi
    
    # Check token scopes
    local scopes_response
    scopes_response=$(curl -s -I -H "Authorization: token $GITHUB_TOKEN" \
                          "https://api.github.com/user" 2>/dev/null || echo "")
    
    local scopes
    scopes=$(echo "$scopes_response" | grep -i "x-oauth-scopes:" | cut -d':' -f2 | tr -d ' \r\n' || echo "")
    
    if [[ ! "$scopes" =~ repo ]]; then
        log "WARN" "GitHub token may not have sufficient scopes. Required: repo"
    fi
    
    local username
    username=$(echo "$response" | grep -o '"login":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
    log "SUCCESS" "GitHub authentication successful for user: $username"
}

# Validate inputs
validate_inputs() {
    local team="$1"
    local environment="$2"
    local resource="$3"
    local org="$4"
    
    # Validate team
    if [[ ! " ${SUPPORTED_TEAMS[*]} " =~ " ${team} " ]]; then
        log "ERROR" "Unsupported team: $team. Supported teams: ${SUPPORTED_TEAMS[*]}"
        return 1
    fi
    
    # Validate environment
    if [[ ! " ${SUPPORTED_ENVIRONMENTS[*]} " =~ " ${environment} " ]]; then
        log "ERROR" "Unsupported environment: $environment. Supported environments: ${SUPPORTED_ENVIRONMENTS[*]}"
        return 1
    fi
    
    # Validate resource name (alphanumeric, hyphens, underscores)
    if [[ ! "$resource" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log "ERROR" "Invalid resource name: $resource. Use only alphanumeric characters, hyphens, and underscores"
        return 1
    fi
    
    # Validate organization
    if [[ ! "$org" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log "ERROR" "Invalid organization name: $org"
        return 1
    fi
    
    log "SUCCESS" "Input validation passed"
    return 0
}

# Check if repository exists
check_repo_exists() {
    local org="$1"
    local repo_name="$2"
    
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3+json" \
                   "https://api.github.com/repos/$org/$repo_name" 2>/dev/null)
    
    if echo "$response" | grep -q '"name"'; then
        return 0  # Repository exists
    else
        return 1  # Repository doesn't exist
    fi
}

# Create GitHub repository
create_github_repo() {
    local org="$1"
    local repo_name="$2"
    local description="$3"
    local private="$4"
    local dry_run="${5:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY_RUN" "Would create GitHub repository: $org/$repo_name"
        log "DRY_RUN" "Description: $description"
        log "DRY_RUN" "Private: $private"
        return 0
    fi
    
    log "INFO" "Creating GitHub repository: $org/$repo_name"
    
    local repo_data
    repo_data=$(cat << EOF
{
    "name": "$repo_name",
    "description": "$description",
    "private": $private,
    "has_issues": true,
    "has_projects": false,
    "has_wiki": false,
    "auto_init": true,
    "gitignore_template": "Terraform",
    "license_template": "mit"
}
EOF
)
    
    local response
    response=$(curl -s -X POST \
                   -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3+json" \
                   -H "Content-Type: application/json" \
                   -d "$repo_data" \
                   "https://api.github.com/orgs/$org/repos")
    
    if echo "$response" | grep -q '"name"'; then
        log "SUCCESS" "Created GitHub repository: $org/$repo_name"
        return 0
    else
        local error_msg
        error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 || echo "Unknown error")
        log "ERROR" "Failed to create repository: $error_msg"
        return 1
    fi
}

# Setup branch protection
setup_branch_protection() {
    local org="$1"
    local repo_name="$2"
    local dry_run="${3:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY_RUN" "Would setup branch protection for: $org/$repo_name"
        return 0
    fi
    
    log "INFO" "Setting up branch protection for: $org/$repo_name"
    
    local protection_data
    protection_data=$(cat << EOF
{
    "required_status_checks": {
        "strict": true,
        "contexts": ["terraform-validate", "terraform-plan"]
    },
    "enforce_admins": false,
    "required_pull_request_reviews": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews": true,
        "require_code_owner_reviews": true
    },
    "restrictions": null
}
EOF
)
    
    local response
    response=$(curl -s -X PUT \
                   -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github.v3+json" \
                   -H "Content-Type: application/json" \
                   -d "$protection_data" \
                   "https://api.github.com/repos/$org/$repo_name/branches/main/protection")
    
    if echo "$response" | grep -q '"url"'; then
        log "SUCCESS" "Branch protection configured for: $org/$repo_name"
    else
        log "WARN" "Failed to configure branch protection (this is optional)"
    fi
}

# Create local directory structure
create_local_structure() {
    local team="$1"
    local environment="$2"
    local resource="$3"
    local dry_run="${4:-false}"
    
    local local_path="${WORKSPACE_DIR}/teams/${team}/${environment}/${resource}"
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY_RUN" "Would create local directory: $local_path"
        return 0
    fi
    
    log "INFO" "Creating local directory structure: $local_path"
    
    mkdir -p "$local_path"
    
    log "SUCCESS" "Created local directory: $local_path"
    echo "$local_path"
}

# Generate Terraform template
generate_terraform_files() {
    local local_path="$1"
    local team="$2"
    local environment="$3"
    local resource="$4"
    local repo_name="$5"
    local dry_run="${6:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY_RUN" "Would generate Terraform files in: $local_path"
        return 0
    fi
    
    log "INFO" "Generating Terraform files"
    
    # main.tf
    cat > "$local_path/main.tf" << EOF
# $repo_name
# Terraform configuration for $team team's $resource in $environment environment

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Backend configuration will be provided during terraform init
    # Example:
    # bucket = "${team}-terraform-state-${environment}"
    # key    = "${resource}/terraform.tfstate"
    # region = "us-west-2"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  common_tags = {
    Team        = "$team"
    Environment = "$environment"
    Resource    = "$resource"
    ManagedBy   = "terraform"
    Repository  = "$repo_name"
  }
  
  name_prefix = "\${var.team}-\${var.environment}-\${var.resource}"
}

# Example resource - replace with actual infrastructure
resource "aws_s3_bucket" "example" {
  bucket = "\${local.name_prefix}-\${random_string.suffix.result}"
  
  tags = merge(local.common_tags, {
    Name = "\${local.name_prefix}-bucket"
  })
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
EOF
    
    # variables.tf
    cat > "$local_path/variables.tf" << EOF
# Variables for $repo_name

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "team" {
  description = "Team name"
  type        = string
  default     = "$team"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "$environment"
}

variable "resource" {
  description = "Resource type"
  type        = string
  default     = "$resource"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
EOF
    
    # outputs.tf
    cat > "$local_path/outputs.tf" << EOF
# Outputs for $repo_name

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.example.bucket
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.example.arn
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}
EOF
    
    # terraform.tfvars.example
    cat > "$local_path/terraform.tfvars.example" << EOF
# Example Terraform variables for $repo_name
# Copy this file to terraform.tfvars and customize as needed

aws_region = "us-west-2"
team       = "$team"
environment = "$environment"
resource    = "$resource"

# Additional tags
tags = {
  Owner   = "infrastructure-team"
  Project = "mobile-platform"
}
EOF
    
    # README.md
    cat > "$local_path/README.md" << EOF
# $repo_name

Infrastructure as Code for $team team's $resource resources in $environment environment.

## Overview

This Terraform configuration manages the $resource infrastructure for the $team team in the $environment environment.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate permissions
- Access to the Terraform state backend

## Usage

1. **Initialize Terraform:**
   \`\`\`bash
   terraform init
   \`\`\`

2. **Create terraform.tfvars:**
   \`\`\`bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   \`\`\`

3. **Plan the deployment:**
   \`\`\`bash
   terraform plan
   \`\`\`

4. **Apply the configuration:**
   \`\`\`bash
   terraform apply
   \`\`\`

## Files

- \`main.tf\` - Main Terraform configuration
- \`variables.tf\` - Variable definitions
- \`outputs.tf\` - Output definitions
- \`terraform.tfvars.example\` - Example variables file

## Resources Created

- S3 Bucket (example resource - customize as needed)

## Tags

All resources are tagged with:
- Team: $team
- Environment: $environment
- Resource: $resource
- ManagedBy: terraform
- Repository: $repo_name

## Contributing

1. Create a feature branch
2. Make your changes
3. Run \`terraform fmt\` and \`terraform validate\`
4. Create a pull request

## Support

For issues and questions, please contact the infrastructure team.
EOF
    
    # .gitignore
    cat > "$local_path/.gitignore" << EOF
# Terraform files
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.tfplan

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Logs
*.log
EOF
    
    log "SUCCESS" "Generated Terraform files in: $local_path"
}

# Clone and setup repository
clone_and_setup_repo() {
    local org="$1"
    local repo_name="$2"
    local local_path="$3"
    local dry_run="${4:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY_RUN" "Would clone repository: $org/$repo_name to $local_path"
        return 0
    fi
    
    log "INFO" "Cloning repository: $org/$repo_name"
    
    # Remove existing directory if it exists
    if [[ -d "$local_path" ]]; then
        rm -rf "$local_path"
    fi
    
    # Clone repository
    git clone "git@github.com:$org/$repo_name.git" "$local_path" >/dev/null 2>&1 || {
        log "ERROR" "Failed to clone repository. Check your SSH keys and permissions."
        return 1
    }
    
    log "SUCCESS" "Cloned repository to: $local_path"
}

# Commit and push initial files
commit_and_push() {
    local local_path="$1"
    local repo_name="$2"
    local dry_run="${3:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY_RUN" "Would commit and push initial files"
        return 0
    fi
    
    log "INFO" "Committing and pushing initial Terraform files"
    
    cd "$local_path"
    
    # Add all files
    git add .
    
    # Commit
    git commit -m "Initial Terraform configuration for $repo_name

- Added main.tf with basic infrastructure setup
- Added variables.tf with common variables
- Added outputs.tf with resource outputs  
- Added README.md with usage instructions
- Added .gitignore for Terraform files

🤖 Generated with Infrastructure Resource Creation Tool" >/dev/null 2>&1
    
    # Push to main branch
    git push origin main >/dev/null 2>&1 || {
        log "ERROR" "Failed to push to repository"
        return 1
    }
    
    log "SUCCESS" "Committed and pushed initial files"
}

# Interactive mode
interactive_mode() {
    local org="$1"
    
    echo
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                    INFRASTRUCTURE RESOURCE CREATOR${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Gather inputs
    local team
    team=$(prompt_choice "Select team" "${SUPPORTED_TEAMS[@]}")
    
    local environment
    environment=$(prompt_choice "Select environment" "${SUPPORTED_ENVIRONMENTS[@]}")
    
    local resource
    resource=$(prompt_input "Enter resource name" "" "^[a-zA-Z0-9_-]+$")
    
    local description
    description=$(prompt_input "Enter repository description" "Infrastructure for $team $resource in $environment")
    
    local private="true"
    if ! prompt_confirm "Create as private repository" "y"; then
        private="false"
    fi
    
    local repo_name="${team}-infra-${environment}-${resource}"
    
    echo
    echo -e "${WHITE}SUMMARY:${NC}"
    echo -e "${CYAN}Repository:${NC} $org/$repo_name"
    echo -e "${CYAN}Team:${NC} $team"
    echo -e "${CYAN}Environment:${NC} $environment"
    echo -e "${CYAN}Resource:${NC} $resource"
    echo -e "${CYAN}Description:${NC} $description"
    echo -e "${CYAN}Private:${NC} $private"
    echo
    
    if ! prompt_confirm "Proceed with creation" "y"; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
    
    echo "$team|$environment|$resource|$description|$private"
}

# Display creation summary
display_creation_summary() {
    local org="$1"
    local repo_name="$2"
    local local_path="$3"
    local dry_run="${4:-false}"
    
    echo
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                           CREATION SUMMARY${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo
    
    if [[ "$dry_run" == "false" ]]; then
        echo -e "${GREEN}${CHECKMARK} Repository created successfully!${NC}"
        echo
        echo -e "${CYAN}GitHub Repository:${NC} https://github.com/$org/$repo_name"
        echo -e "${CYAN}Local Path:${NC} $local_path"
        echo
        echo -e "${WHITE}Next Steps:${NC}"
        echo -e "  1. ${BULLET} Review the generated Terraform files"
        echo -e "  2. ${BULLET} Customize the infrastructure as needed"
        echo -e "  3. ${BULLET} Copy terraform.tfvars.example to terraform.tfvars"
        echo -e "  4. ${BULLET} Configure your Terraform backend"
        echo -e "  5. ${BULLET} Run 'terraform init' and 'terraform plan'"
        echo
        echo -e "${WHITE}Useful Commands:${NC}"
        echo -e "  ${CYAN}cd $local_path${NC}"
        echo -e "  ${CYAN}cp terraform.tfvars.example terraform.tfvars${NC}"
        echo -e "  ${CYAN}terraform init${NC}"
        echo -e "  ${CYAN}terraform plan${NC}"
    else
        echo -e "${YELLOW}This was a dry run. No resources were created.${NC}"
        echo -e "Run without --dry-run to create the actual resources."
    fi
    
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

# Main function
main() {
    local org="$DEFAULT_ORG"
    local team=""
    local environment=""
    local resource=""
    local description=""
    local private="true"
    local dry_run=false
    local interactive=false
    local custom_template=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--org)
                org="$2"
                shift 2
                ;;
            -t|--team)
                team="$2"
                shift 2
                ;;
            -e|--env)
                environment="$2"
                shift 2
                ;;
            -r|--resource)
                resource="$2"
                shift 2
                ;;
            -d|--description)
                description="$2"
                shift 2
                ;;
            -p|--private)
                private="true"
                shift
                ;;
            --public)
                private="false"
                shift
                ;;
            -T|--template)
                custom_template="$2"
                shift 2
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    # Initialize
    init_environment
    check_github_auth
    
    # Interactive mode if no arguments provided
    if [[ -z "$team" && -z "$environment" && -z "$resource" ]] || [[ "$interactive" == "true" ]]; then
        local interactive_result
        interactive_result=$(interactive_mode "$org")
        IFS='|' read -r team environment resource description private <<< "$interactive_result"
    fi
    
    # Set default description if not provided
    if [[ -z "$description" ]]; then
        description="Infrastructure for $team $resource in $environment environment"
    fi
    
    # Validate inputs
    validate_inputs "$team" "$environment" "$resource" "$org" || exit 1
    
    local repo_name="${team}-infra-${environment}-${resource}"
    
    # Check if repository already exists
    if check_repo_exists "$org" "$repo_name"; then
        log "ERROR" "Repository already exists: $org/$repo_name"
        echo -e "${RED}Repository $org/$repo_name already exists!${NC}"
        exit 1
    fi
    
    log "INFO" "Creating infrastructure resource: $repo_name"
    
    # Create GitHub repository
    create_github_repo "$org" "$repo_name" "$description" "$private" "$dry_run" || exit 1
    
    # Setup branch protection (optional, continue if it fails)
    setup_branch_protection "$org" "$repo_name" "$dry_run"
    
    # Create local directory structure
    local local_path
    local_path=$(create_local_structure "$team" "$environment" "$resource" "$dry_run") || exit 1
    
    if [[ "$dry_run" == "false" ]]; then
        # Clone repository
        clone_and_setup_repo "$org" "$repo_name" "$local_path" "$dry_run" || exit 1
        
        # Generate Terraform files
        generate_terraform_files "$local_path" "$team" "$environment" "$resource" "$repo_name" "$dry_run" || exit 1
        
        # Commit and push
        commit_and_push "$local_path" "$repo_name" "$dry_run" || exit 1
    fi
    
    # Display summary
    display_creation_summary "$org" "$repo_name" "$local_path" "$dry_run"
    
    log "SUCCESS" "Infrastructure resource creation completed"
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted${NC}"; exit 130' INT TERM

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi