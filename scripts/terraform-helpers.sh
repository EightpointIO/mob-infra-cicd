#!/bin/bash

# Terraform Helper Functions for Infrastructure CI/CD
# Used by mob-infra-cicd workflows

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Terraform is installed and get version
check_terraform_version() {
    local expected_version=${1:-"1.6.0"}
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed"
        return 1
    fi
    
    local current_version=$(terraform version -json | jq -r '.terraform_version')
    log_info "Terraform version: $current_version (expected: $expected_version)"
    
    if [[ "$current_version" != "$expected_version" ]]; then
        log_warning "Terraform version mismatch. Expected: $expected_version, Got: $current_version"
    fi
}

# Format check with detailed output
terraform_format_check() {
    local working_dir=${1:-.}
    
    log_info "Running Terraform format check in $working_dir"
    
    if terraform fmt -check -recursive -diff "$working_dir"; then
        log_success "All Terraform files are properly formatted"
        return 0
    else
        log_error "Terraform formatting issues found. Run 'terraform fmt -recursive' to fix."
        return 1
    fi
}

# Initialize Terraform with backend validation
terraform_init_with_validation() {
    local working_dir=${1:-.}
    
    log_info "Initializing Terraform in $working_dir"
    
    cd "$working_dir"
    
    # Check if backend configuration exists
    if [[ ! -f "main.tf" && ! -f "terraform.tf" && ! -f "*.tf" ]]; then
        log_error "No Terraform configuration files found in $working_dir"
        return 1
    fi
    
    # Initialize with backend validation
    if terraform init -backend-config-file=backend.tfvars 2>/dev/null || terraform init; then
        log_success "Terraform initialization successful"
        
        # Validate backend state
        if terraform state list &>/dev/null; then
            log_info "Backend state is accessible"
        else
            log_warning "Backend state is not accessible or empty"
        fi
        
        return 0
    else
        log_error "Terraform initialization failed"
        return 1
    fi
}

# Validate Terraform configuration
terraform_validate_with_details() {
    local working_dir=${1:-.}
    
    log_info "Validating Terraform configuration in $working_dir"
    
    cd "$working_dir"
    
    if terraform validate -json > validation_output.json; then
        log_success "Terraform validation passed"
        rm -f validation_output.json
        return 0
    else
        log_error "Terraform validation failed:"
        if [[ -f "validation_output.json" ]]; then
            jq -r '.diagnostics[]? | "- \(.severity | ascii_upcase): \(.summary) (\(.detail // "No details"))"' validation_output.json
            rm -f validation_output.json
        fi
        return 1
    fi
}

# Plan with enhanced output and analysis
terraform_plan_with_analysis() {
    local working_dir=${1:-.}
    local plan_file=${2:-"tfplan"}
    
    log_info "Creating Terraform plan in $working_dir"
    
    cd "$working_dir"
    
    # Create plan with detailed output
    if terraform plan -detailed-exitcode -out="$plan_file" -no-color > plan_output.txt 2>&1; then
        local exit_code=$?
        
        case $exit_code in
            0)
                log_success "No changes detected in Terraform plan"
                ;;
            2)
                log_info "Changes detected in Terraform plan"
                
                # Analyze the plan
                local resources_to_add=$(grep -c "will be created" plan_output.txt || echo "0")
                local resources_to_change=$(grep -c "will be updated" plan_output.txt || echo "0")
                local resources_to_destroy=$(grep -c "will be destroyed" plan_output.txt || echo "0")
                
                log_info "Plan summary: +$resources_to_add ~$resources_to_change -$resources_to_destroy"
                
                # Check for potentially dangerous operations
                if [[ $resources_to_destroy -gt 0 ]]; then
                    log_warning "$resources_to_destroy resource(s) will be destroyed"
                fi
                
                # Check for data source changes (usually indicates environment issues)
                if grep -q "data\." plan_output.txt; then
                    log_info "Data source changes detected - verify environment connectivity"
                fi
                ;;
            *)
                log_error "Terraform plan failed with exit code $exit_code"
                cat plan_output.txt
                return 1
                ;;
        esac
        
        return $exit_code
    else
        log_error "Terraform plan command failed"
        cat plan_output.txt || echo "No plan output available"
        return 1
    fi
}

# Apply with confirmation and rollback capability
terraform_apply_with_safety() {
    local working_dir=${1:-.}
    local plan_file=${2:-"tfplan"}
    local auto_approve=${3:-false}
    
    log_info "Applying Terraform plan in $working_dir"
    
    cd "$working_dir"
    
    # Verify plan file exists
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file $plan_file not found. Run terraform plan first."
        return 1
    fi
    
    # Create backup of current state
    if terraform state pull > "state_backup_$(date +%Y%m%d_%H%M%S).json" 2>/dev/null; then
        log_info "State backup created"
    else
        log_warning "Could not create state backup"
    fi
    
    # Apply the plan
    local apply_cmd="terraform apply"
    if [[ "$auto_approve" == "true" ]]; then
        apply_cmd="$apply_cmd -auto-approve"
    fi
    apply_cmd="$apply_cmd $plan_file"
    
    if eval "$apply_cmd"; then
        log_success "Terraform apply completed successfully"
        
        # Cleanup old backups (keep last 5)
        find . -name "state_backup_*.json" -type f | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
        
        return 0
    else
        log_error "Terraform apply failed"
        
        # Offer rollback information
        local latest_backup=$(find . -name "state_backup_*.json" -type f | sort -r | head -n 1)
        if [[ -n "$latest_backup" ]]; then
            log_info "State backup available: $latest_backup"
            log_info "To rollback: terraform state push $latest_backup"
        fi
        
        return 1
    fi
}

# Destroy with safety checks
terraform_destroy_with_safety() {
    local working_dir=${1:-.}
    local auto_approve=${2:-false}
    
    log_warning "Preparing to destroy Terraform-managed infrastructure in $working_dir"
    
    cd "$working_dir"
    
    # Create state backup before destruction
    if terraform state pull > "state_backup_before_destroy_$(date +%Y%m%d_%H%M%S).json" 2>/dev/null; then
        log_info "State backup created before destruction"
    fi
    
    # Show what will be destroyed
    log_info "Resources that will be destroyed:"
    terraform plan -destroy -no-color | grep -E "(will be destroyed|Plan:)" || true
    
    if [[ "$auto_approve" != "true" ]]; then
        read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Destruction cancelled by user"
            return 1
        fi
    fi
    
    # Perform destruction
    local destroy_cmd="terraform destroy"
    if [[ "$auto_approve" == "true" ]]; then
        destroy_cmd="$destroy_cmd -auto-approve"
    fi
    
    if eval "$destroy_cmd"; then
        log_success "Terraform destroy completed successfully"
        return 0
    else
        log_error "Terraform destroy failed"
        return 1
    fi
}

# Check for drift by comparing plan to empty changes
check_terraform_drift() {
    local working_dir=${1:-.}
    
    log_info "Checking for infrastructure drift in $working_dir"
    
    cd "$working_dir"
    
    if terraform plan -detailed-exitcode -no-color > drift_check.txt 2>&1; then
        local exit_code=$?
        
        case $exit_code in
            0)
                log_success "No drift detected - infrastructure matches configuration"
                return 0
                ;;
            2)
                log_warning "Infrastructure drift detected:"
                grep -E "(will be created|will be updated|will be destroyed)" drift_check.txt || echo "Changes detected but details unclear"
                return 2
                ;;
            *)
                log_error "Drift check failed with exit code $exit_code"
                cat drift_check.txt
                return 1
                ;;
        esac
    else
        log_error "Drift check command failed"
        return 1
    fi
}

# Cleanup temporary files
cleanup_terraform_files() {
    local working_dir=${1:-.}
    
    log_info "Cleaning up temporary Terraform files in $working_dir"
    
    cd "$working_dir"
    
    # Remove temporary files
    rm -f tfplan plan_output.txt validation_output.json drift_check.txt
    
    # Remove old state backups (keep last 3)
    find . -name "state_backup_*.json" -type f | sort -r | tail -n +4 | xargs rm -f 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Main execution check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_error "This script should be sourced, not executed directly"
    log_info "Usage: source terraform-helpers.sh"
    exit 1
fi

log_info "Terraform helper functions loaded successfully"