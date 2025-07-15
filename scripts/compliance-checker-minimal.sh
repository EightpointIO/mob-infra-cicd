#!/usr/bin/env bash

# Minimal Infrastructure Compliance Checker
# Quick compliance validation for infrastructure projects

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

update_counters() {
    local status="$1"
    ((TOTAL_CHECKS++))
    case "$status" in
        "PASS") ((PASSED_CHECKS++)) ;;
        "FAIL") ((FAILED_CHECKS++)) ;;
        "WARN") ((WARNING_CHECKS++)) ;;
    esac
}

check_result() {
    local name="$1" status="$2" message="$3"
    echo "- **$name:** $status - $message"
    update_counters "$status"
}

# Basic compliance checks
run_basic_checks() {
    log_info "Running basic compliance checks..."
    
    # Check 1: Git repository
    if [[ -d "${PROJECT_ROOT}/.git" ]]; then
        log_success "Git repository found"
        check_result "Git-Repo" "PASS" "Project is under version control"
    else
        log_warn "No Git repository found"
        check_result "Git-Repo" "WARN" "Project should be under version control"
    fi
    
    echo "DEBUG: About to check .gitignore"
    
    # Check 2: .gitignore file
    if [[ -f "${PROJECT_ROOT}/.gitignore" ]]; then
        log_success ".gitignore file found"
        check_result "Git-Ignore" "PASS" ".gitignore file exists"
        
        # Check for security patterns
        local patterns=0
        for pattern in "*.tfvars" "*.tfstate" ".env" "secrets" "*.key"; do
            if grep -q "$pattern" "${PROJECT_ROOT}/.gitignore" 2>/dev/null; then
                ((patterns++))
            fi
        done
        
        if [[ $patterns -ge 3 ]]; then
            log_success "Security patterns in .gitignore"
            check_result "Git-Security" "PASS" ".gitignore includes security patterns"
        else
            log_warn "Few security patterns in .gitignore"
            check_result "Git-Security" "WARN" ".gitignore should include more security patterns"
        fi
    else
        log_error ".gitignore file not found"
        check_result "Git-Ignore" "FAIL" ".gitignore file missing"
    fi
    
    # Check 3: Terraform files
    local tf_count
    tf_count=$(find "${PROJECT_ROOT}" -maxdepth 3 -name "*.tf" 2>/dev/null | wc -l)
    
    if [[ $tf_count -gt 0 ]]; then
        log_success "Found $tf_count Terraform files"
        check_result "Terraform-Files" "PASS" "Terraform infrastructure files found"
        
        # Check for remote state backend
        if grep -r "backend.*s3\|backend.*azurerm\|backend.*gcs" "${PROJECT_ROOT}"/*.tf 2>/dev/null | head -1 | grep -q .; then
            log_success "Remote state backend configured"
            check_result "Terraform-Backend" "PASS" "Remote state backend configured"
        else
            log_error "Remote state backend not configured"
            check_result "Terraform-Backend" "FAIL" "Remote state backend required"
        fi
        
        # Check for resource tagging
        if grep -r "tags.*=" "${PROJECT_ROOT}"/*.tf 2>/dev/null | head -1 | grep -q .; then
            log_success "Resource tagging found"
            check_result "Terraform-Tags" "PASS" "Resource tagging implemented"
        else
            log_warn "Resource tagging not found"
            check_result "Terraform-Tags" "WARN" "Resource tagging recommended"
        fi
        
        # Check for encryption
        if grep -r "encrypt\|kms" "${PROJECT_ROOT}"/*.tf 2>/dev/null | head -1 | grep -q .; then
            log_success "Encryption configurations found"
            check_result "Security-Encryption" "PASS" "Encryption configured"
        else
            log_warn "No encryption configurations found"
            check_result "Security-Encryption" "WARN" "Encryption should be configured"
        fi
        
    else
        log_warn "No Terraform files found"
        check_result "Terraform-Files" "WARN" "No infrastructure as code files found"
    fi
    
    # Check 4: Security scanning files
    local security_files=0
    for file in ".github/workflows/security.yml" ".pre-commit-config.yaml" "checkov.yml"; do
        if [[ -f "${PROJECT_ROOT}/$file" ]]; then
            ((security_files++))
        fi
    done
    
    if [[ $security_files -gt 0 ]]; then
        log_success "Security automation files found"
        check_result "Security-Automation" "PASS" "Security automation configured"
    else
        log_warn "No security automation files found"
        check_result "Security-Automation" "WARN" "Security automation recommended"
    fi
}

# Generate simple report
generate_report() {
    local report_file="${PROJECT_ROOT}/reports/compliance-report-${TIMESTAMP}.md"
    mkdir -p "${PROJECT_ROOT}/reports"
    
    local compliance_score=0
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        compliance_score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    fi
    
    cat > "$report_file" << EOF
# Infrastructure Compliance Report (Minimal)

**Generated:** $(date)
**Project:** $(basename "$PROJECT_ROOT")

## Summary

- **Total Checks:** $TOTAL_CHECKS
- **Passed:** $PASSED_CHECKS
- **Failed:** $FAILED_CHECKS
- **Warnings:** $WARNING_CHECKS
- **Compliance Score:** ${compliance_score}%
- **Risk Level:** $(if [[ $FAILED_CHECKS -gt 2 ]]; then echo "HIGH"; elif [[ $FAILED_CHECKS -gt 0 ]]; then echo "MEDIUM"; else echo "LOW"; fi)

## Detailed Results

Check results are displayed above during execution.

## Recommendations

### High Priority
$(if [[ $FAILED_CHECKS -gt 0 ]]; then echo "- Address failed checks immediately"; else echo "- No high priority issues"; fi)

### Medium Priority  
$(if [[ $WARNING_CHECKS -gt 0 ]]; then echo "- Review and address warnings"; else echo "- No medium priority issues"; fi)

---
*Generated by Infrastructure Compliance Checker*
EOF

    log_success "Report generated: $report_file"
}

# Main function
main() {
    # Parse arguments first
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-root)
                PROJECT_ROOT="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [--project-root PATH]"
                echo "Minimal compliance checker for infrastructure projects"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    log_info "Starting Minimal Infrastructure Compliance Checker..."
    log_info "Project Root: $PROJECT_ROOT"
    
    # Run checks
    run_basic_checks
    
    # Generate report
    generate_report
    
    # Summary
    echo
    log_info "=== COMPLIANCE SUMMARY ==="
    log_info "Total Checks: $TOTAL_CHECKS"
    log_success "Passed: $PASSED_CHECKS"
    log_warn "Warnings: $WARNING_CHECKS"
    log_error "Failed: $FAILED_CHECKS"
    
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        log_info "Compliance Score: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%"
    fi
    
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        log_error "Critical issues found! Please review and address."
        exit 1
    else
        log_success "Basic compliance requirements met!"
        exit 0
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi