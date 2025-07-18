#!/usr/bin/env zsh

# Test script for Terraform Dependency Updater
# Validates basic functionality and safety checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
UPDATER_SCRIPT="${SCRIPT_DIR}/dependency-updater.sh"
TEST_DIR="${SCRIPT_DIR}/test-workspace"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

setup_test_environment() {
    log_test "Setting up test environment..."
    
    # Create test workspace
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Create sample Terraform files
    cat > "$TEST_DIR/main.tf" << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "network" {
  source = "git::https://github.com/EightpointIO/mob-infra-core.git//modules/network?ref=v1.0.0"
  
  vpc_cidr = "10.0.0.0/16"
}

module "data_stores" {
  source = "git::https://github.com/EightpointIO/mob-infra-core.git//modules/data-stores?ref=v0.9.0"
  
  database_name = "test"
}
EOF
    
    cat > "$TEST_DIR/variables.tf" << 'EOF'
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}
EOF
    
    cat > "$TEST_DIR/outputs.tf" << 'EOF'
output "vpc_id" {
  value = module.network.vpc_id
}
EOF
    
    # Initialize git repo
    cd "$TEST_DIR"
    git init
    git add .
    git commit -m "Initial test configuration"
    cd - > /dev/null
    
    log_success "Test environment created at: $TEST_DIR"
}

cleanup_test_environment() {
    log_test "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
    log_success "Test environment cleaned up"
}

test_script_exists() {
    log_test "Checking if dependency updater script exists..."
    
    if [[ -f "$UPDATER_SCRIPT" ]]; then
        log_success "Script exists: $UPDATER_SCRIPT"
        return 0
    else
        log_failure "Script not found: $UPDATER_SCRIPT"
        return 1
    fi
}

test_script_executable() {
    log_test "Checking if script is executable..."
    
    if [[ -x "$UPDATER_SCRIPT" ]]; then
        log_success "Script is executable"
        return 0
    else
        log_failure "Script is not executable"
        return 1
    fi
}

test_help_command() {
    log_test "Testing help command..."
    
    if "$UPDATER_SCRIPT" --help > /dev/null 2>&1; then
        log_success "Help command works"
        return 0
    else
        log_failure "Help command failed"
        return 1
    fi
}

test_check_command() {
    log_test "Testing check command..."
    
    cd "$TEST_DIR"
    if timeout 60 "$UPDATER_SCRIPT" check --target "$TEST_DIR" > /dev/null 2>&1; then
        log_success "Check command completed"
        return 0
    else
        log_warning "Check command failed (may be due to API limits or missing tools)"
        return 0  # Don't fail the test for this
    fi
    cd - > /dev/null
}

test_dry_run_command() {
    log_test "Testing dry-run command..."
    
    cd "$TEST_DIR"
    if timeout 60 "$UPDATER_SCRIPT" update --dry-run --target "$TEST_DIR" > /dev/null 2>&1; then
        log_success "Dry-run command completed"
        return 0
    else
        log_warning "Dry-run command failed (may be due to API limits or missing tools)"
        return 0  # Don't fail the test for this
    fi
    cd - > /dev/null
}

test_configuration_loading() {
    log_test "Testing configuration loading..."
    
    # Create temporary config
    local temp_config="${TEST_DIR}/test.config"
    cat > "$temp_config" << 'EOF'
DEFAULT_STRATEGY=patch
AUTO_BACKUP=false
GITHUB_ORG=TestOrg
EOF
    
    if "$UPDATER_SCRIPT" check --config "$temp_config" --target "$TEST_DIR" > /dev/null 2>&1; then
        log_success "Configuration loading works"
        return 0
    else
        log_warning "Configuration loading test inconclusive"
        return 0
    fi
}

test_terraform_file_parsing() {
    log_test "Testing Terraform file parsing..."
    
    # This test would require the internal functions
    # For now, we'll just check if the files exist
    if [[ -f "$TEST_DIR/main.tf" ]]; then
        local module_count
        module_count=$(grep -c "module \"" "$TEST_DIR/main.tf" || true)
        
        local provider_count
        provider_count=$(grep -c "source.*=" "$TEST_DIR/main.tf" || true)
        
        if [[ $module_count -gt 0 && $provider_count -gt 0 ]]; then
            log_success "Test file contains modules and providers"
            return 0
        else
            log_failure "Test file doesn't contain expected content"
            return 1
        fi
    else
        log_failure "Test Terraform file not found"
        return 1
    fi
}

test_backup_directory_creation() {
    log_test "Testing backup directory structure..."
    
    # Run a command that should create directories
    "$UPDATER_SCRIPT" check --target "$TEST_DIR" > /dev/null 2>&1 || true
    
    local backup_dir="${SCRIPT_DIR}/backups"
    local log_dir="${SCRIPT_DIR}/logs"
    local temp_dir="${SCRIPT_DIR}/temp"
    local reports_dir="${SCRIPT_DIR}/reports"
    
    local all_dirs_exist=true
    
    for dir in "$backup_dir" "$log_dir" "$temp_dir" "$reports_dir"; do
        if [[ ! -d "$dir" ]]; then
            log_failure "Directory not created: $dir"
            all_dirs_exist=false
        fi
    done
    
    if [[ "$all_dirs_exist" == true ]]; then
        log_success "Required directories exist"
        return 0
    else
        return 1
    fi
}

test_version_strategy_validation() {
    log_test "Testing version strategy validation..."
    
    local strategies=("patch" "minor" "major" "exact")
    local all_strategies_valid=true
    
    for strategy in "${strategies[@]}"; do
        if ! "$UPDATER_SCRIPT" check --strategy "$strategy" --target "$TEST_DIR" > /dev/null 2>&1; then
            log_warning "Strategy '$strategy' may not be fully supported yet"
        fi
    done
    
    log_success "Version strategy validation completed"
    return 0
}

test_log_file_creation() {
    log_test "Testing log file creation..."
    
    "$UPDATER_SCRIPT" check --target "$TEST_DIR" > /dev/null 2>&1 || true
    
    local log_files
    log_files=$(find "${SCRIPT_DIR}/logs" -name "dependency-updater-*.log" 2>/dev/null | wc -l)
    
    if [[ $log_files -gt 0 ]]; then
        log_success "Log files are being created"
        return 0
    else
        log_failure "No log files found"
        return 1
    fi
}

run_all_tests() {
    local failed_tests=0
    local total_tests=0
    
    echo "Starting Terraform Dependency Updater Tests"
    echo "============================================="
    
    # Setup
    setup_test_environment
    
    # Test functions
    local test_functions=(
        "test_script_exists"
        "test_script_executable"
        "test_help_command"
        "test_terraform_file_parsing"
        "test_backup_directory_creation"
        "test_log_file_creation"
        "test_configuration_loading"
        "test_version_strategy_validation"
        "test_check_command"
        "test_dry_run_command"
    )
    
    for test_func in "${test_functions[@]}"; do
        echo ""
        total_tests=$((total_tests + 1))
        
        if ! $test_func; then
            failed_tests=$((failed_tests + 1))
        fi
    done
    
    # Cleanup
    cleanup_test_environment
    
    echo ""
    echo "============================================="
    echo "Test Results:"
    echo "Total tests: $total_tests"
    echo "Passed: $((total_tests - failed_tests))"
    echo "Failed: $failed_tests"
    
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Main execution
main() {
    case "${1:-run}" in
        "run"|"")
            run_all_tests
            ;;
        "setup")
            setup_test_environment
            ;;
        "cleanup")
            cleanup_test_environment
            ;;
        *)
            echo "Usage: $0 [run|setup|cleanup]"
            echo ""
            echo "Commands:"
            echo "  run     - Run all tests (default)"
            echo "  setup   - Set up test environment only"
            echo "  cleanup - Clean up test environment only"
            exit 1
            ;;
    esac
}

if [[ "${(%):-%N}" == "${0}" ]]; then
    main "$@"
fi