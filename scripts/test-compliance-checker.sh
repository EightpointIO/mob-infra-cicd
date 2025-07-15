#!/bin/bash

# Test script for the Infrastructure Compliance Checker
# This script validates that the compliance checker runs correctly

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMPLIANCE_CHECKER="${SCRIPT_DIR}/compliance-checker.sh"
readonly TEST_PROJECT_ROOT="${SCRIPT_DIR}/test-workspace"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test 1: Check if compliance checker script exists and is executable
test_script_exists() {
    log_test "Checking if compliance checker script exists..."
    
    if [[ -f "$COMPLIANCE_CHECKER" ]]; then
        log_pass "Compliance checker script found"
    else
        log_fail "Compliance checker script not found at: $COMPLIANCE_CHECKER"
        return 1
    fi
    
    if [[ -x "$COMPLIANCE_CHECKER" ]]; then
        log_pass "Compliance checker script is executable"
    else
        log_fail "Compliance checker script is not executable"
        return 1
    fi
}

# Test 2: Check if help option works
test_help_option() {
    log_test "Testing help option..."
    
    if "$COMPLIANCE_CHECKER" --help > /dev/null 2>&1; then
        log_pass "Help option works correctly"
    else
        log_fail "Help option failed"
        return 1
    fi
}

# Test 3: Create test workspace and run compliance checker
test_basic_functionality() {
    log_test "Testing basic compliance checker functionality..."
    
    # Create test workspace if it doesn't exist
    if [[ ! -d "$TEST_PROJECT_ROOT" ]]; then
        mkdir -p "$TEST_PROJECT_ROOT"
        log_test "Created test workspace: $TEST_PROJECT_ROOT"
    fi
    
    # Create minimal test files
    cat > "${TEST_PROJECT_ROOT}/main.tf" << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "terraform.tfstate"
    region = "us-west-2"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "my-example-bucket"
  
  tags = {
    Name        = "Example"
    Environment = "Test"
  }
}

resource "aws_s3_bucket_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
EOF
    
    cat > "${TEST_PROJECT_ROOT}/variables.tf" << 'EOF'
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
  
  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}
EOF
    
    cat > "${TEST_PROJECT_ROOT}/.gitignore" << 'EOF'
*.tfvars
*.tfstate
*.tfstate.backup
.env
secrets/
*.key
*.pem
.terraform/
EOF
    
    # Run compliance checker on test workspace
    log_test "Running compliance checker on test workspace..."
    
    # Capture output and exit code
    local output
    local exit_code=0
    
    output=$("$COMPLIANCE_CHECKER" --project-root "$TEST_PROJECT_ROOT" 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
        log_pass "Compliance checker executed successfully (exit code: $exit_code)"
        
        # Check if reports were generated
        if [[ -d "${SCRIPT_DIR}/../reports" ]] && ls "${SCRIPT_DIR}/../reports"/compliance-report-*.md &>/dev/null; then
            log_pass "Compliance reports generated"
        else
            log_warn "No compliance reports found (may be expected for test run)"
        fi
        
    else
        log_fail "Compliance checker failed with exit code: $exit_code"
        echo "Output: $output"
        return 1
    fi
}

# Test 4: Validate configuration file
test_configuration_file() {
    log_test "Testing configuration file..."
    
    local config_file="${SCRIPT_DIR}/compliance-checker.config"
    
    if [[ -f "$config_file" ]]; then
        log_pass "Configuration file exists"
        
        # Basic validation of config file structure
        if grep -q "\[frameworks\]" "$config_file" && \
           grep -q "\[severity\]" "$config_file" && \
           grep -q "\[reports\]" "$config_file"; then
            log_pass "Configuration file has expected structure"
        else
            log_warn "Configuration file may be missing expected sections"
        fi
    else
        log_warn "Configuration file not found (optional)"
    fi
}

# Test 5: Check for required dependencies
test_dependencies() {
    log_test "Checking for optional dependencies..."
    
    local deps=("git" "terraform" "jq")
    local found_deps=0
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_pass "$dep is available"
            ((found_deps++))
        else
            log_warn "$dep is not available (optional)"
        fi
    done
    
    if [[ $found_deps -gt 0 ]]; then
        log_pass "Some optional dependencies are available"
    else
        log_warn "No optional dependencies found - some checks may be skipped"
    fi
}

# Test 6: Validate script syntax
test_script_syntax() {
    log_test "Validating script syntax..."
    
    if bash -n "$COMPLIANCE_CHECKER"; then
        log_pass "Script syntax is valid"
    else
        log_fail "Script syntax errors found"
        return 1
    fi
}

# Test 7: Check README documentation
test_documentation() {
    log_test "Checking documentation..."
    
    local readme_file="${SCRIPT_DIR}/COMPLIANCE_CHECKER_README.md"
    
    if [[ -f "$readme_file" ]]; then
        log_pass "README documentation exists"
        
        # Check for key sections
        if grep -q "## Overview" "$readme_file" && \
           grep -q "## Usage" "$readme_file" && \
           grep -q "## Configuration" "$readme_file"; then
            log_pass "README has expected structure"
        else
            log_warn "README may be missing some sections"
        fi
    else
        log_warn "README documentation not found"
    fi
}

# Main test runner
main() {
    echo
    log_test "Starting Infrastructure Compliance Checker Tests..."
    echo
    
    local tests_passed=0
    local tests_failed=0
    local tests_warned=0
    
    # Run all tests
    local test_functions=(
        "test_script_exists"
        "test_script_syntax"
        "test_help_option"
        "test_configuration_file"
        "test_dependencies"
        "test_documentation"
        "test_basic_functionality"
    )
    
    for test_func in "${test_functions[@]}"; do
        echo
        if $test_func; then
            ((tests_passed++))
        else
            ((tests_failed++))
        fi
    done
    
    # Summary
    echo
    echo "=========================="
    log_test "TEST SUMMARY"
    echo "=========================="
    log_pass "Tests Passed: $tests_passed"
    log_fail "Tests Failed: $tests_failed"
    
    if [[ $tests_failed -eq 0 ]]; then
        echo
        log_pass "All tests completed successfully!"
        log_pass "Infrastructure Compliance Checker is ready to use."
        exit 0
    else
        echo
        log_fail "Some tests failed. Please review the output above."
        exit 1
    fi
}

# Cleanup function
cleanup() {
    log_test "Cleaning up test files..."
    
    # Remove test workspace if it was created by this script
    if [[ -d "$TEST_PROJECT_ROOT" ]] && [[ "$TEST_PROJECT_ROOT" == *"test-workspace"* ]]; then
        rm -rf "$TEST_PROJECT_ROOT"
        log_test "Removed test workspace"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi