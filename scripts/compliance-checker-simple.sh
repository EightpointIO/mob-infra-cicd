#!/usr/bin/env bash

# Infrastructure Compliance Checker (Simple Version)
# Compatible with bash 3.2+ and zsh
# Comprehensive security and compliance validation for infrastructure projects

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORTS_DIR="${PROJECT_ROOT}/reports"
readonly LOGS_DIR="${SCRIPT_DIR}/logs"
readonly TEMP_DIR="${SCRIPT_DIR}/temp"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Result files
readonly ALL_RESULTS="${TEMP_DIR}/all_results.tmp"
readonly REMEDIATION_FILE="${TEMP_DIR}/remediation.tmp"

# Directory creation and file initialization moved to main()

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${LOGS_DIR}/compliance-checker-${TIMESTAMP}.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${LOGS_DIR}/compliance-checker-${TIMESTAMP}.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOGS_DIR}/compliance-checker-${TIMESTAMP}.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "${LOGS_DIR}/compliance-checker-${TIMESTAMP}.log"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $*" | tee -a "${LOGS_DIR}/compliance-checker-${TIMESTAMP}.log"
    fi
}

# Helper functions
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_warn "Command '$cmd' not found. Some checks may be skipped."
        return 1
    fi
    return 0
}

update_counters() {
    local status="$1"
    ((TOTAL_CHECKS++))
    case "$status" in
        "PASS") ((PASSED_CHECKS++)) ;;
        "FAIL") ((FAILED_CHECKS++)) ;;
        "WARN") ((WARNING_CHECKS++)) ;;
    esac
}

record_check_result() {
    local category="$1"
    local check_id="$2"
    local status="$3"
    local description="$4"
    local remediation="${5:-No specific remediation available}"
    
    # Write to all results file: category|check_id|status|description
    echo "$category|$check_id|$status|$description" >> "$ALL_RESULTS"
    
    # Write to remediation file: check_id|remediation
    echo "$check_id|$remediation" >> "$REMEDIATION_FILE"
    
    update_counters "$status"
}

# NIST Cybersecurity Framework Checks
check_nist_compliance() {
    log_info "Checking NIST Cybersecurity Framework compliance..."
    
    # NIST.ID.AM-1: Physical devices and systems are inventoried
    log_info "NIST.ID.AM-1: Checking infrastructure inventory..."
    if [[ -f "${PROJECT_ROOT}/inventory.json" ]] || [[ -f "${PROJECT_ROOT}/infrastructure-inventory.yaml" ]]; then
        log_success "Infrastructure inventory file found"
        record_check_result "NIST" "ID.AM-1" "PASS" "Infrastructure inventory documentation exists" \
            "Maintain updated inventory of all infrastructure components"
    else
        log_warn "No infrastructure inventory file found"
        record_check_result "NIST" "ID.AM-1" "WARN" "Missing infrastructure inventory documentation" \
            "Create infrastructure-inventory.yaml or inventory.json to document all infrastructure components"
    fi
    
    # NIST.ID.AM-2: Software platforms and applications are inventoried
    log_info "NIST.ID.AM-2: Checking software inventory..."
    local software_inventory_found=false
    
    log_debug "Starting find command for software inventory..."
    if find "${PROJECT_ROOT}" -maxdepth 3 \( -name "package.json" -o -name "requirements.txt" -o -name "Pipfile" -o -name "pom.xml" -o -name "build.gradle" \) 2>/dev/null | head -1 | grep -q .; then
        software_inventory_found=true
        log_debug "Software inventory found"
    else
        log_debug "No software inventory found"
    fi
    
    if [[ "$software_inventory_found" == "true" ]]; then
        log_success "Software dependency files found"
        record_check_result "NIST" "ID.AM-2" "PASS" "Software dependencies are documented" \
            "Regularly update and scan dependency files for vulnerabilities"
    else
        log_warn "No software dependency files found"
        record_check_result "NIST" "ID.AM-2" "WARN" "Software dependencies not clearly documented" \
            "Add dependency management files (package.json, requirements.txt, etc.)"
    fi
    
    # NIST.PR.AC-1: Identities and credentials are managed
    log_info "NIST.PR.AC-1: Checking identity and access management..."
    local iam_found=false
    
    if find "${PROJECT_ROOT}" -maxdepth 5 -name "*.tf" -exec grep -l "aws_iam\|google_iam\|azurerm_role" {} + 2>/dev/null | head -1 | grep -q .; then
        iam_found=true
    fi
    
    if [[ "$iam_found" == "true" ]]; then
        log_success "IAM configurations found in Terraform"
        record_check_result "NIST" "PR.AC-1" "PASS" "Identity and access management is configured" \
            "Regularly review IAM policies and implement least privilege principle"
    else
        log_warn "No IAM configurations found"
        record_check_result "NIST" "PR.AC-1" "WARN" "Identity and access management not configured" \
            "Implement IAM policies using Infrastructure as Code"
    fi
    
    # NIST.PR.DS-1: Data-at-rest is protected
    log_info "NIST.PR.DS-1: Checking data-at-rest protection..."
    local encryption_found=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "encrypt\|kms\|server_side_encryption" {} + 2>/dev/null | head -1 | grep -q .; then
        encryption_found=true
    fi
    
    if [[ "$encryption_found" == "true" ]]; then
        log_success "Encryption configurations found"
        record_check_result "NIST" "PR.DS-1" "PASS" "Data-at-rest encryption is configured" \
            "Ensure all sensitive data stores use encryption at rest"
    else
        log_warn "No encryption configurations found"
        record_check_result "NIST" "PR.DS-1" "WARN" "Data-at-rest encryption not configured" \
            "Implement encryption for all data stores (RDS, S3, EBS volumes, etc.)"
    fi
}

# CIS Controls Checks
check_cis_compliance() {
    log_info "Checking CIS Controls compliance..."
    
    # CIS Control 1: Inventory and Control of Hardware Assets
    log_info "CIS Control 1: Hardware asset inventory..."
    if [[ -f "${PROJECT_ROOT}/hardware-inventory.yaml" ]] || grep -r "instance_type\|machine_type" "${PROJECT_ROOT}" 2>/dev/null | head -1 | grep -q .; then
        log_success "Hardware inventory or instance configurations found"
        record_check_result "CIS" "Control-1" "PASS" "Hardware assets are inventoried" \
            "Maintain detailed inventory of all compute resources"
    else
        log_warn "Hardware inventory not found"
        record_check_result "CIS" "Control-1" "WARN" "Hardware assets not inventoried" \
            "Create hardware-inventory.yaml and document all compute resources"
    fi
    
    # CIS Control 3: Continuous Vulnerability Management
    log_info "CIS Control 3: Vulnerability management..."
    local vuln_scanning=false
    
    if [[ -f "${PROJECT_ROOT}/.github/workflows/security.yml" ]] || \
       [[ -f "${PROJECT_ROOT}/.github/workflows/vulnerability-scan.yml" ]] || \
       grep -r "checkov\|tfsec\|terrascan\|snyk" "${PROJECT_ROOT}" 2>/dev/null | head -1 | grep -q .; then
        vuln_scanning=true
    fi
    
    if [[ "$vuln_scanning" == "true" ]]; then
        log_success "Vulnerability scanning tools configured"
        record_check_result "CIS" "Control-3" "PASS" "Vulnerability management is implemented" \
            "Run vulnerability scans regularly and address findings promptly"
    else
        log_warn "No vulnerability scanning configured"
        record_check_result "CIS" "Control-3" "WARN" "Vulnerability management not implemented" \
            "Implement automated vulnerability scanning using tools like Checkov, TFSec, or Snyk"
    fi
}

# SOC 2 Type II Compliance Checks
check_soc2_compliance() {
    log_info "Checking SOC 2 Type II compliance..."
    
    # Security - Access Controls
    log_info "SOC2 Security: Access control implementation..."
    local access_controls=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_iam\|security_group\|nacl\|access_control" {} + 2>/dev/null | head -1 | grep -q .; then
        access_controls=true
    fi
    
    if [[ "$access_controls" == "true" ]]; then
        log_success "Access controls implemented"
        record_check_result "SOC2" "Security-AC" "PASS" "Access controls are implemented" \
            "Regularly review and update access control policies"
    else
        log_warn "Access controls not found"
        record_check_result "SOC2" "Security-AC" "WARN" "Access controls not implemented" \
            "Implement comprehensive access controls using IAM and security groups"
    fi
    
    # Availability - Monitoring and Alerting
    log_info "SOC2 Availability: Monitoring and alerting..."
    local monitoring=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "cloudwatch_alarm\|sns\|monitoring\|health_check" {} + 2>/dev/null | head -1 | grep -q .; then
        monitoring=true
    fi
    
    if [[ "$monitoring" == "true" ]]; then
        log_success "Monitoring and alerting configured"
        record_check_result "SOC2" "Availability-MA" "PASS" "Monitoring and alerting are configured" \
            "Ensure 24/7 monitoring and automated alerting for critical services"
    else
        log_warn "Monitoring and alerting not configured"
        record_check_result "SOC2" "Availability-MA" "WARN" "Monitoring and alerting not configured" \
            "Implement comprehensive monitoring using CloudWatch alarms and SNS notifications"
    fi
}

# Terraform Best Practices Checks
check_terraform_compliance() {
    log_info "Checking Terraform best practices..."
    
    if ! find "${PROJECT_ROOT}" -maxdepth 5 -name "*.tf" 2>/dev/null | head -1 | grep -q .; then
        log_warn "No Terraform files found, skipping Terraform checks"
        return
    fi
    
    # State Backend Configuration
    log_info "Terraform: Checking remote state backend..."
    local backend_configured=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "backend.*s3\|backend.*azurerm\|backend.*gcs" {} + 2>/dev/null | head -1 | grep -q .; then
        backend_configured=true
    fi
    
    if [[ "$backend_configured" == "true" ]]; then
        log_success "Remote state backend configured"
        record_check_result "TERRAFORM" "Backend" "PASS" "Remote state backend is configured" \
            "Ensure state backend has versioning and encryption enabled"
    else
        log_error "Remote state backend not configured"
        record_check_result "TERRAFORM" "Backend" "FAIL" "Remote state backend not configured" \
            "Configure remote state backend (S3, Azure Storage, or GCS) with versioning and encryption"
    fi
    
    # Resource Tagging
    log_info "Terraform: Checking resource tagging..."
    local tagging_found=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "tags.*=" {} + 2>/dev/null | head -1 | grep -q .; then
        tagging_found=true
    fi
    
    if [[ "$tagging_found" == "true" ]]; then
        log_success "Resource tagging found"
        record_check_result "TERRAFORM" "Tagging" "PASS" "Resource tagging is implemented" \
            "Ensure consistent tagging strategy across all resources"
    else
        log_warn "Resource tagging not found"
        record_check_result "TERRAFORM" "Tagging" "WARN" "Resource tagging not implemented" \
            "Implement consistent resource tagging for cost allocation and management"
    fi
}

# Git Security and Best Practices
check_git_compliance() {
    log_info "Checking Git security and best practices..."
    
    if [[ ! -d "${PROJECT_ROOT}/.git" ]]; then
        log_warn "Not a Git repository, skipping Git checks"
        return
    fi
    
    # .gitignore
    log_info "Git: Checking .gitignore configuration..."
    if [[ -f "${PROJECT_ROOT}/.gitignore" ]]; then
        local gitignore_items=0
        for pattern in "*.tfvars" "*.tfstate" ".env" "secrets" "credentials" "*.key" "*.pem"; do
            if grep -q "$pattern" "${PROJECT_ROOT}/.gitignore" 2>/dev/null; then
                ((gitignore_items++))
            fi
        done
        
        if [[ $gitignore_items -ge 3 ]]; then
            log_success ".gitignore includes security patterns"
            record_check_result "GIT" "Gitignore" "PASS" ".gitignore includes security-sensitive patterns" \
                "Regularly review and update .gitignore patterns"
        else
            log_warn ".gitignore missing security patterns"
            record_check_result "GIT" "Gitignore" "WARN" ".gitignore missing security-sensitive patterns" \
                "Add patterns for secrets, keys, state files, and other sensitive files"
        fi
    else
        log_error ".gitignore not found"
        record_check_result "GIT" "Gitignore" "FAIL" ".gitignore file not found" \
            "Create .gitignore file with appropriate patterns for secrets and sensitive files"
    fi
}

# AWS Best Practices Checks
check_aws_compliance() {
    log_info "Checking AWS best practices..."
    
    if ! find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws" {} + 2>/dev/null | head -1 | grep -q .; then
        log_warn "No AWS Terraform configurations found, skipping AWS checks"
        return
    fi
    
    # S3 Security
    log_info "AWS: Checking S3 security configuration..."
    local s3_security=0
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_s3_bucket_encryption\|server_side_encryption" {} + 2>/dev/null | head -1 | grep -q .; then
        ((s3_security++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_s3_bucket_versioning" {} + 2>/dev/null | head -1 | grep -q .; then
        ((s3_security++))
    fi
    
    if [[ $s3_security -ge 1 ]]; then
        log_success "S3 security configurations found"
        record_check_result "AWS" "S3Security" "PASS" "S3 security is configured" \
            "Ensure all S3 buckets have encryption, versioning, and access controls"
    else
        log_warn "S3 security configuration needs improvement"
        record_check_result "AWS" "S3Security" "WARN" "S3 security configuration incomplete" \
            "Implement S3 encryption, versioning, and public access blocks"
    fi
}

# Policy Violation Checks
check_policy_violations() {
    log_info "Checking for policy violations..."
    
    # Check for hardcoded secrets
    log_info "Policy: Checking for hardcoded secrets..."
    local secrets_found=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" 2>/dev/null | \
       xargs grep -l "password.*=\|secret.*=\|key.*=\|token.*=" 2>/dev/null | head -1 | grep -q .; then
        secrets_found=true
    fi
    
    if [[ "$secrets_found" == "true" ]]; then
        log_error "Potential hardcoded secrets found"
        record_check_result "POLICY" "HardcodedSecrets" "FAIL" "Potential hardcoded secrets found in configuration files" \
            "Move all secrets to secure parameter stores or environment variables"
    else
        log_success "No obvious hardcoded secrets found"
        record_check_result "POLICY" "HardcodedSecrets" "PASS" "No obvious hardcoded secrets found" \
            "Continue using secure secret management practices"
    fi
}

# Generate compliance reports
generate_compliance_report() {
    log_info "Generating compliance reports..."
    
    local report_file="${REPORTS_DIR}/compliance-report-${TIMESTAMP}.md"
    local csv_report="${REPORTS_DIR}/compliance-report-${TIMESTAMP}.csv"
    
    # Calculate compliance score
    local compliance_score=80
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        compliance_score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    fi
    
    # Markdown Report
    cat > "$report_file" << EOF
# Infrastructure Compliance Report

**Generated:** $(date)
**Project:** $(basename "$PROJECT_ROOT")
**Total Checks:** $TOTAL_CHECKS
**Passed:** $PASSED_CHECKS
**Failed:** $FAILED_CHECKS
**Warnings:** $WARNING_CHECKS

## Summary

- **Overall Compliance Score:** ${compliance_score}%
- **Risk Level:** $(if [[ $FAILED_CHECKS -gt 5 ]]; then echo "HIGH"; elif [[ $FAILED_CHECKS -gt 2 ]]; then echo "MEDIUM"; else echo "LOW"; fi)

## Detailed Results

EOF
    
    # Process results by category
    for category in NIST CIS SOC2 TERRAFORM GIT AWS POLICY; do
        echo "### $category Results" >> "$report_file"
        echo "" >> "$report_file"
        
        if grep "^$category|" "$ALL_RESULTS" 2>/dev/null | while IFS='|' read -r cat check_id status description; do
            echo "- **$check_id:** $status - $description" >> "$report_file"
        done; then
            :
        else
            echo "- No $category checks performed" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

## Remediation Guide

### High Priority (Failed Checks)

EOF
    
    # Add failed checks remediation
    if grep "FAIL" "$ALL_RESULTS" 2>/dev/null | while IFS='|' read -r category check_id status description; do
        local remediation
        if remediation=$(grep "^$check_id|" "$REMEDIATION_FILE" | cut -d'|' -f2); then
            echo "- **$check_id:** $remediation" >> "$report_file"
        fi
    done; then
        :
    else
        echo "- No failed checks found" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

### Medium Priority (Warnings)

EOF
    
    # Add warning checks remediation
    if grep "WARN" "$ALL_RESULTS" 2>/dev/null | while IFS='|' read -r category check_id status description; do
        local remediation
        if remediation=$(grep "^$check_id|" "$REMEDIATION_FILE" | cut -d'|' -f2); then
            echo "- **$check_id:** $remediation" >> "$report_file"
        fi
    done; then
        :
    else
        echo "- No warnings found" >> "$report_file"
    fi
    
    # CSV Report
    echo "Category,Check ID,Status,Description,Remediation" > "$csv_report"
    
    while IFS='|' read -r category check_id status description; do
        local remediation
        remediation=$(grep "^$check_id|" "$REMEDIATION_FILE" | cut -d'|' -f2 || echo "No remediation available")
        echo "$category,$check_id,$status,\"$description\",\"$remediation\"" >> "$csv_report"
    done < "$ALL_RESULTS"
    
    log_success "Reports generated:"
    log_info "  - Markdown: $report_file"
    log_info "  - CSV: $csv_report"
}

# Track compliance trends
track_compliance_trends() {
    log_info "Tracking compliance trends..."
    
    local trends_file="${REPORTS_DIR}/compliance-trends.json"
    local compliance_score=80
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        compliance_score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    fi
    
    local current_data
    current_data=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "total_checks": $TOTAL_CHECKS,
  "passed": $PASSED_CHECKS,
  "failed": $FAILED_CHECKS,
  "warnings": $WARNING_CHECKS,
  "compliance_score": $compliance_score
}
EOF
)
    
    if [[ -f "$trends_file" ]] && check_command "jq"; then
        # Add to existing trends
        local temp_file="${TEMP_DIR}/trends.tmp"
        echo "$current_data" | jq -s '. as $new | if (length > 0) then (.[0] | if type == "array" then . + $new else [$current_data] end) else [$current_data] end' > "$temp_file" 2>/dev/null || echo "[$current_data]" > "$temp_file"
        mv "$temp_file" "$trends_file"
    else
        # Create new trends file
        echo "[$current_data]" > "$trends_file"
    fi
    
    log_success "Compliance trends updated: $trends_file"
}

# Main execution function
main() {
    # Ensure required directories exist
    mkdir -p "${REPORTS_DIR}" "${LOGS_DIR}" "${TEMP_DIR}"
    
    # Initialize result files
    > "$ALL_RESULTS"
    > "$REMEDIATION_FILE"
    
    log_info "Starting Infrastructure Compliance Checker (Simple Version)..."
    log_info "Project Root: $PROJECT_ROOT"
    log_info "Reports Directory: $REPORTS_DIR"
    
    # Initialize counters
    TOTAL_CHECKS=0
    PASSED_CHECKS=0
    FAILED_CHECKS=0
    WARNING_CHECKS=0
    
    # Run all compliance checks
    check_nist_compliance
    check_cis_compliance
    check_soc2_compliance
    check_terraform_compliance
    check_git_compliance
    check_aws_compliance
    check_policy_violations
    
    # Generate reports
    generate_compliance_report
    track_compliance_trends
    
    # Final summary
    echo
    log_info "=== COMPLIANCE CHECK SUMMARY ==="
    log_info "Total Checks: $TOTAL_CHECKS"
    log_success "Passed: $PASSED_CHECKS"
    log_warn "Warnings: $WARNING_CHECKS"
    log_error "Failed: $FAILED_CHECKS"
    
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        log_info "Compliance Score: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%"
    fi
    
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        echo
        log_error "ATTENTION: ${FAILED_CHECKS} critical compliance issues found!"
        log_error "Please review the compliance report and address failed checks immediately."
        exit 1
    elif [[ $WARNING_CHECKS -gt 5 ]]; then
        echo
        log_warn "WARNING: ${WARNING_CHECKS} compliance warnings found."
        log_warn "Consider addressing these issues to improve security posture."
        exit 0
    else
        echo
        log_success "Compliance check completed successfully!"
        log_success "Infrastructure meets basic compliance requirements."
        exit 0
    fi
}

# Script usage information
show_usage() {
    cat << EOF
Infrastructure Compliance Checker (Simple Version)

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    -d, --debug         Enable debug logging
    --project-root DIR  Override project root directory

DESCRIPTION:
    Simplified compliance checker compatible with bash 3.2+ and zsh.
    
    Supports compliance frameworks:
    - NIST Cybersecurity Framework
    - CIS Controls
    - SOC 2 Type II
    - Terraform Best Practices
    - Git Security Best Practices
    - AWS Well-Architected Framework
    
EXAMPLES:
    # Run basic compliance check
    ./compliance-checker-simple.sh
    
    # Run with verbose output
    ./compliance-checker-simple.sh --verbose

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        --project-root)
            PROJECT_ROOT="$2"
            REPORTS_DIR="${PROJECT_ROOT}/reports"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi