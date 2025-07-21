#!/usr/bin/env bash

# Infrastructure Compliance Checker
# Comprehensive security and compliance validation for infrastructure projects
# Supports: NIST, CIS, SOC2 standards, Terraform, Git, and AWS best practices

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly REPORTS_DIR="${PROJECT_ROOT}/reports"
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

# Compliance tracking using files (compatible with bash 3.2+)
readonly NIST_RESULTS="${TEMP_DIR}/nist_results.tmp"
readonly CIS_RESULTS="${TEMP_DIR}/cis_results.tmp"
readonly SOC2_RESULTS="${TEMP_DIR}/soc2_results.tmp"
readonly TERRAFORM_RESULTS="${TEMP_DIR}/terraform_results.tmp"
readonly GIT_RESULTS="${TEMP_DIR}/git_results.tmp"
readonly AWS_RESULTS="${TEMP_DIR}/aws_results.tmp"
readonly REMEDIATION_RESULTS="${TEMP_DIR}/remediation_results.tmp"

# Global counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Ensure required directories exist
mkdir -p "${REPORTS_DIR}" "${LOGS_DIR}" "${TEMP_DIR}"

# Initialize result files
initialize_results() {
    > "$NIST_RESULTS"
    > "$CIS_RESULTS"
    > "$SOC2_RESULTS"
    > "$TERRAFORM_RESULTS"
    > "$GIT_RESULTS"
    > "$AWS_RESULTS"
    > "$REMEDIATION_RESULTS"
}

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
    
    # Write results to appropriate files
    case "$category" in
        "NIST") echo "$check_id|$status|$description" >> "$NIST_RESULTS" ;;
        "CIS") echo "$check_id|$status|$description" >> "$CIS_RESULTS" ;;
        "SOC2") echo "$check_id|$status|$description" >> "$SOC2_RESULTS" ;;
        "TERRAFORM") echo "$check_id|$status|$description" >> "$TERRAFORM_RESULTS" ;;
        "GIT") echo "$check_id|$status|$description" >> "$GIT_RESULTS" ;;
        "AWS") echo "$check_id|$status|$description" >> "$AWS_RESULTS" ;;
    esac
    
    # Store remediation guidance
    echo "$check_id|$remediation" >> "$REMEDIATION_RESULTS"
    update_counters "$status"
}

# NIST Cybersecurity Framework Checks
check_nist_compliance() {
    log_info "Checking NIST Cybersecurity Framework compliance..."
    
    # NIST.ID.AM-1: Physical devices and systems within the organization are inventoried
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
    
    if find "${PROJECT_ROOT}" -name "package.json" -o -name "requirements.txt" -o -name "Pipfile" -o -name "pom.xml" -o -name "build.gradle" | head -1 | grep -q .; then
        software_inventory_found=true
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
    
    # NIST.PR.AC-1: Identities and credentials are issued, managed, verified, revoked, and audited
    log_info "NIST.PR.AC-1: Checking identity and access management..."
    local iam_found=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_iam\|google_iam\|azurerm_role" {} + 2>/dev/null | head -1 | grep -q .; then
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
    
    # NIST.PR.DS-2: Data-in-transit is protected
    log_info "NIST.PR.DS-2: Checking data-in-transit protection..."
    local tls_found=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "ssl\|tls\|https\|certificate" {} + 2>/dev/null | head -1 | grep -q .; then
        tls_found=true
    fi
    
    if [[ "$tls_found" == "true" ]]; then
        log_success "TLS/SSL configurations found"
        record_check_result "NIST" "PR.DS-2" "PASS" "Data-in-transit encryption is configured" \
            "Ensure all communications use TLS 1.2 or higher"
    else
        log_warn "No TLS/SSL configurations found"
        record_check_result "NIST" "PR.DS-2" "WARN" "Data-in-transit encryption not configured" \
            "Implement TLS encryption for all network communications"
    fi
    
    # NIST.DE.CM-1: Networks are monitored to detect potential cybersecurity events
    log_info "NIST.DE.CM-1: Checking network monitoring..."
    local monitoring_found=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "cloudwatch\|monitoring\|logging\|vpc_flow_log" {} + 2>/dev/null | head -1 | grep -q .; then
        monitoring_found=true
    fi
    
    if [[ "$monitoring_found" == "true" ]]; then
        log_success "Network monitoring configurations found"
        record_check_result "NIST" "DE.CM-1" "PASS" "Network monitoring is configured" \
            "Ensure comprehensive logging and monitoring of all network traffic"
    else
        log_warn "No network monitoring configurations found"
        record_check_result "NIST" "DE.CM-1" "WARN" "Network monitoring not configured" \
            "Implement VPC Flow Logs, CloudTrail, and other network monitoring tools"
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
    
    # CIS Control 2: Inventory and Control of Software Assets
    log_info "CIS Control 2: Software asset inventory..."
    local software_files=0
    for file in package.json requirements.txt Pipfile pom.xml build.gradle Dockerfile; do
        if find "${PROJECT_ROOT}" -name "$file" | head -1 | grep -q .; then
            ((software_files++))
        fi
    done
    
    if [[ $software_files -gt 0 ]]; then
        log_success "Software inventory files found ($software_files different types)"
        record_check_result "CIS" "Control-2" "PASS" "Software assets are inventoried" \
            "Regularly update and audit all software dependencies"
    else
        log_warn "No software inventory files found"
        record_check_result "CIS" "Control-2" "WARN" "Software assets not inventoried" \
            "Add dependency management files and maintain software inventory"
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
    
    # CIS Control 4: Controlled Use of Administrative Privileges
    log_info "CIS Control 4: Administrative privileges control..."
    local admin_control=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "role.*admin\|policy.*admin\|assume_role" {} + 2>/dev/null | head -1 | grep -q .; then
        admin_control=true
    fi
    
    if [[ "$admin_control" == "true" ]]; then
        log_success "Administrative role configurations found"
        record_check_result "CIS" "Control-4" "PASS" "Administrative privileges are controlled" \
            "Implement least privilege access and regular access reviews"
    else
        log_warn "No administrative privilege controls found"
        record_check_result "CIS" "Control-4" "WARN" "Administrative privileges not controlled" \
            "Implement role-based access control with least privilege principle"
    fi
    
    # CIS Control 6: Maintenance, Monitoring, and Analysis of Audit Logs
    log_info "CIS Control 6: Audit logging..."
    local audit_logging=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "cloudtrail\|audit\|logging\|log_group" {} + 2>/dev/null | head -1 | grep -q .; then
        audit_logging=true
    fi
    
    if [[ "$audit_logging" == "true" ]]; then
        log_success "Audit logging configurations found"
        record_check_result "CIS" "Control-6" "PASS" "Audit logging is configured" \
            "Ensure comprehensive audit logging and regular log analysis"
    else
        log_warn "No audit logging configurations found"
        record_check_result "CIS" "Control-6" "WARN" "Audit logging not configured" \
            "Implement CloudTrail, CloudWatch Logs, and other audit logging mechanisms"
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
    
    # Processing Integrity - Data Validation
    log_info "SOC2 Processing Integrity: Data validation..."
    local data_validation=false
    
    if grep -r "validation\|constraint\|check_constraint" "${PROJECT_ROOT}" 2>/dev/null | head -1 | grep -q .; then
        data_validation=true
    fi
    
    if [[ "$data_validation" == "true" ]]; then
        log_success "Data validation mechanisms found"
        record_check_result "SOC2" "ProcessingIntegrity-DV" "PASS" "Data validation is implemented" \
            "Ensure all data inputs are validated and sanitized"
    else
        log_warn "Data validation mechanisms not found"
        record_check_result "SOC2" "ProcessingIntegrity-DV" "WARN" "Data validation not implemented" \
            "Implement data validation rules and constraints"
    fi
    
    # Confidentiality - Encryption
    log_info "SOC2 Confidentiality: Encryption implementation..."
    local encryption=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "encrypt\|kms\|ssl\|tls" {} + 2>/dev/null | head -1 | grep -q .; then
        encryption=true
    fi
    
    if [[ "$encryption" == "true" ]]; then
        log_success "Encryption configurations found"
        record_check_result "SOC2" "Confidentiality-E" "PASS" "Encryption is implemented" \
            "Ensure all sensitive data is encrypted at rest and in transit"
    else
        log_warn "Encryption configurations not found"
        record_check_result "SOC2" "Confidentiality-E" "WARN" "Encryption not implemented" \
            "Implement encryption for all sensitive data and communications"
    fi
    
    # Privacy - Data Classification
    log_info "SOC2 Privacy: Data classification..."
    if [[ -f "${PROJECT_ROOT}/data-classification.yaml" ]] || grep -r "sensitive\|pii\|classification" "${PROJECT_ROOT}" 2>/dev/null | head -1 | grep -q .; then
        log_success "Data classification evidence found"
        record_check_result "SOC2" "Privacy-DC" "PASS" "Data classification is implemented" \
            "Maintain updated data classification and handling procedures"
    else
        log_warn "Data classification not found"
        record_check_result "SOC2" "Privacy-DC" "WARN" "Data classification not implemented" \
            "Create data-classification.yaml and implement data handling procedures"
    fi
}

# Terraform Best Practices Checks
check_terraform_compliance() {
    log_info "Checking Terraform best practices..."
    
    if ! find "${PROJECT_ROOT}" -name "*.tf" | head -1 | grep -q .; then
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
    
    # Variable Validation
    log_info "Terraform: Checking variable validation..."
    local validation_found=false
    
    if find "${PROJECT_ROOT}" -name "variables.tf" -exec grep -l "validation" {} + 2>/dev/null | head -1 | grep -q .; then
        validation_found=true
    fi
    
    if [[ "$validation_found" == "true" ]]; then
        log_success "Variable validation found"
        record_check_result "TERRAFORM" "Validation" "PASS" "Variable validation is implemented" \
            "Continue using variable validation for all input variables"
    else
        log_warn "Variable validation not found"
        record_check_result "TERRAFORM" "Validation" "WARN" "Variable validation not implemented" \
            "Add validation blocks to variables.tf files for input validation"
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
    
    # Provider Version Constraints
    log_info "Terraform: Checking provider version constraints..."
    local version_constraints=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "required_providers\|version.*=" {} + 2>/dev/null | head -1 | grep -q .; then
        version_constraints=true
    fi
    
    if [[ "$version_constraints" == "true" ]]; then
        log_success "Provider version constraints found"
        record_check_result "TERRAFORM" "Versions" "PASS" "Provider version constraints are defined" \
            "Keep provider versions up to date and use specific version constraints"
    else
        log_error "Provider version constraints not found"
        record_check_result "TERRAFORM" "Versions" "FAIL" "Provider version constraints not defined" \
            "Add required_providers block with specific version constraints"
    fi
    
    # Security Scanning Integration
    log_info "Terraform: Checking security scanning..."
    local security_scanning=false
    
    if check_command "checkov" || check_command "tfsec" || check_command "terrascan"; then
        security_scanning=true
    elif [[ -f "${PROJECT_ROOT}/.github/workflows/terraform-security.yml" ]] || \
         grep -r "checkov\|tfsec\|terrascan" "${PROJECT_ROOT}/.github" 2>/dev/null | head -1 | grep -q .; then
        security_scanning=true
    fi
    
    if [[ "$security_scanning" == "true" ]]; then
        log_success "Security scanning tools available"
        record_check_result "TERRAFORM" "Security" "PASS" "Security scanning is configured" \
            "Run security scans regularly and address findings"
    else
        log_warn "Security scanning not configured"
        record_check_result "TERRAFORM" "Security" "WARN" "Security scanning not configured" \
            "Install and configure security scanning tools (Checkov, TFSec, Terrascan)"
    fi
    
    # Module Structure
    log_info "Terraform: Checking module structure..."
    local module_structure=false
    
    if find "${PROJECT_ROOT}" -type d -name "modules" | head -1 | grep -q . || \
       find "${PROJECT_ROOT}" -name "main.tf" -exec dirname {} \; | sort | uniq | wc -l | grep -v '^1$' | grep -q .; then
        module_structure=true
    fi
    
    if [[ "$module_structure" == "true" ]]; then
        log_success "Modular structure detected"
        record_check_result "TERRAFORM" "Modules" "PASS" "Modular structure is implemented" \
            "Continue using modular structure for reusability and maintainability"
    else
        log_warn "Modular structure not detected"
        record_check_result "TERRAFORM" "Modules" "WARN" "Modular structure not implemented" \
            "Organize Terraform code into reusable modules"
    fi
}

# Git Security and Best Practices
check_git_compliance() {
    log_info "Checking Git security and best practices..."
    
    if [[ ! -d "${PROJECT_ROOT}/.git" ]]; then
        log_warn "Not a Git repository, skipping Git checks"
        return
    fi
    
    # Git Hooks
    log_info "Git: Checking pre-commit hooks..."
    if [[ -f "${PROJECT_ROOT}/.pre-commit-config.yaml" ]] || [[ -d "${PROJECT_ROOT}/.git/hooks" ]] && ls "${PROJECT_ROOT}/.git/hooks/"* 2>/dev/null | grep -q .; then
        log_success "Git hooks configured"
        record_check_result "GIT" "Hooks" "PASS" "Git hooks are configured" \
            "Ensure hooks include security scanning and code quality checks"
    else
        log_warn "Git hooks not configured"
        record_check_result "GIT" "Hooks" "WARN" "Git hooks not configured" \
            "Configure pre-commit hooks for automated security and quality checks"
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
    
    # Secrets Scanning
    log_info "Git: Checking for secrets in repository..."
    local secrets_found=false
    
    # Simple pattern matching for common secrets
    if git log --all --grep="password\|secret\|key\|token" --oneline 2>/dev/null | head -1 | grep -q . || \
       git log --all -p | grep -E "(password|secret|key|token).*=" | head -1 | grep -q .; then
        secrets_found=true
    fi
    
    if [[ "$secrets_found" == "true" ]]; then
        log_error "Potential secrets found in Git history"
        record_check_result "GIT" "Secrets" "FAIL" "Potential secrets found in Git history" \
            "Use git-secrets or similar tools to scan and remove secrets from Git history"
    else
        log_success "No obvious secrets found in Git history"
        record_check_result "GIT" "Secrets" "PASS" "No obvious secrets found in Git history" \
            "Continue using secret scanning tools and avoid committing sensitive data"
    fi
    
    # Branch Protection (for GitHub)
    log_info "Git: Checking branch protection..."
    if [[ -f "${PROJECT_ROOT}/.github/workflows"/*.yml ]] && grep -l "pull_request" "${PROJECT_ROOT}/.github/workflows"/*.yml 2>/dev/null | head -1 | grep -q .; then
        log_success "CI/CD workflows with PR checks found"
        record_check_result "GIT" "BranchProtection" "PASS" "CI/CD workflows with PR checks configured" \
            "Ensure branch protection rules are enabled on the main branch"
    else
        log_warn "No CI/CD workflows with PR checks found"
        record_check_result "GIT" "BranchProtection" "WARN" "No CI/CD workflows with PR checks found" \
            "Configure GitHub Actions workflows with pull request checks"
    fi
    
    # Commit Signing
    log_info "Git: Checking commit signing configuration..."
    if git config --get user.signingkey &>/dev/null && git config --get commit.gpgsign &>/dev/null; then
        log_success "Commit signing configured"
        record_check_result "GIT" "CommitSigning" "PASS" "Commit signing is configured" \
            "Ensure all team members use commit signing"
    else
        log_warn "Commit signing not configured"
        record_check_result "GIT" "CommitSigning" "WARN" "Commit signing not configured" \
            "Configure GPG key signing for commit authenticity"
    fi
}

# AWS Best Practices Checks
check_aws_compliance() {
    log_info "Checking AWS best practices..."
    
    if ! find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws" {} + 2>/dev/null | head -1 | grep -q .; then
        log_warn "No AWS Terraform configurations found, skipping AWS checks"
        return
    fi
    
    # CloudTrail Configuration
    log_info "AWS: Checking CloudTrail configuration..."
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_cloudtrail" {} + 2>/dev/null | head -1 | grep -q .; then
        log_success "CloudTrail configuration found"
        record_check_result "AWS" "CloudTrail" "PASS" "CloudTrail is configured" \
            "Ensure CloudTrail logs are encrypted and stored securely"
    else
        log_error "CloudTrail not configured"
        record_check_result "AWS" "CloudTrail" "FAIL" "CloudTrail not configured" \
            "Configure AWS CloudTrail for comprehensive API logging"
    fi
    
    # VPC Configuration
    log_info "AWS: Checking VPC security configuration..."
    local vpc_security=0
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_vpc" {} + 2>/dev/null | head -1 | grep -q .; then
        ((vpc_security++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_security_group" {} + 2>/dev/null | head -1 | grep -q .; then
        ((vpc_security++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_network_acl" {} + 2>/dev/null | head -1 | grep -q .; then
        ((vpc_security++))
    fi
    
    if [[ $vpc_security -ge 2 ]]; then
        log_success "VPC security configurations found"
        record_check_result "AWS" "VPCSecurity" "PASS" "VPC security is configured" \
            "Review security group rules and ensure least privilege access"
    else
        log_warn "Incomplete VPC security configuration"
        record_check_result "AWS" "VPCSecurity" "WARN" "Incomplete VPC security configuration" \
            "Implement comprehensive VPC security with security groups and NACLs"
    fi
    
    # S3 Security
    log_info "AWS: Checking S3 security configuration..."
    local s3_security=0
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_s3_bucket_encryption" {} + 2>/dev/null | head -1 | grep -q .; then
        ((s3_security++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_s3_bucket_versioning" {} + 2>/dev/null | head -1 | grep -q .; then
        ((s3_security++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_s3_bucket_public_access_block" {} + 2>/dev/null | head -1 | grep -q .; then
        ((s3_security++))
    fi
    
    if [[ $s3_security -ge 2 ]]; then
        log_success "S3 security configurations found"
        record_check_result "AWS" "S3Security" "PASS" "S3 security is configured" \
            "Ensure all S3 buckets have encryption, versioning, and access controls"
    else
        log_warn "Incomplete S3 security configuration"
        record_check_result "AWS" "S3Security" "WARN" "Incomplete S3 security configuration" \
            "Implement S3 encryption, versioning, and public access blocks"
    fi
    
    # IAM Best Practices
    log_info "AWS: Checking IAM best practices..."
    local iam_practices=0
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_iam_role" {} + 2>/dev/null | head -1 | grep -q .; then
        ((iam_practices++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_iam_policy" {} + 2>/dev/null | head -1 | grep -q .; then
        ((iam_practices++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -A5 -B5 "assume_role_policy" {} + 2>/dev/null | grep -q "Principal"; then
        ((iam_practices++))
    fi
    
    if [[ $iam_practices -ge 2 ]]; then
        log_success "IAM best practices implemented"
        record_check_result "AWS" "IAMPractices" "PASS" "IAM best practices are implemented" \
            "Regularly review IAM policies and implement least privilege access"
    else
        log_warn "IAM best practices not fully implemented"
        record_check_result "AWS" "IAMPractices" "WARN" "IAM best practices not fully implemented" \
            "Implement comprehensive IAM roles and policies with least privilege"
    fi
    
    # Monitoring and Alerting
    log_info "AWS: Checking monitoring and alerting..."
    local monitoring=0
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_cloudwatch_alarm" {} + 2>/dev/null | head -1 | grep -q .; then
        ((monitoring++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_sns_topic" {} + 2>/dev/null | head -1 | grep -q .; then
        ((monitoring++))
    fi
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_cloudwatch_log_group" {} + 2>/dev/null | head -1 | grep -q .; then
        ((monitoring++))
    fi
    
    if [[ $monitoring -ge 2 ]]; then
        log_success "Monitoring and alerting configured"
        record_check_result "AWS" "Monitoring" "PASS" "Monitoring and alerting are configured" \
            "Ensure comprehensive monitoring covers all critical resources"
    else
        log_warn "Monitoring and alerting not fully configured"
        record_check_result "AWS" "Monitoring" "WARN" "Monitoring and alerting not fully configured" \
            "Implement CloudWatch alarms, SNS notifications, and comprehensive logging"
    fi
}

# Policy Violation Checks
check_policy_violations() {
    log_info "Checking for policy violations..."
    
    # Check for hardcoded secrets
    log_info "Policy: Checking for hardcoded secrets..."
    local secrets_patterns=("password.*=" "secret.*=" "key.*=" "token.*=" "api_key.*=")
    local violations_found=false
    
    for pattern in "${secrets_patterns[@]}"; do
        if find "${PROJECT_ROOT}" -name "*.tf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" | \
           xargs grep -l "$pattern" 2>/dev/null | head -1 | grep -q .; then
            violations_found=true
            break
        fi
    done
    
    if [[ "$violations_found" == "true" ]]; then
        log_error "Hardcoded secrets found in configuration files"
        record_check_result "POLICY" "HardcodedSecrets" "FAIL" "Hardcoded secrets found in configuration files" \
            "Move all secrets to secure parameter stores or environment variables"
    else
        log_success "No hardcoded secrets found"
        record_check_result "POLICY" "HardcodedSecrets" "PASS" "No hardcoded secrets found" \
            "Continue using secure secret management practices"
    fi
    
    # Check for overly permissive policies
    log_info "Policy: Checking for overly permissive IAM policies..."
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l '"*"' {} + 2>/dev/null | head -1 | grep -q . || \
       find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l 'Effect.*Allow.*Resource.*\*' {} + 2>/dev/null | head -1 | grep -q .; then
        log_warn "Potentially overly permissive IAM policies found"
        record_check_result "POLICY" "PermissivePolicies" "WARN" "Potentially overly permissive IAM policies found" \
            "Review and restrict IAM policies to follow least privilege principle"
    else
        log_success "No overly permissive policies detected"
        record_check_result "POLICY" "PermissivePolicies" "PASS" "No overly permissive policies detected" \
            "Continue following least privilege access principles"
    fi
    
    # Check for unencrypted storage
    log_info "Policy: Checking for unencrypted storage resources..."
    local unencrypted_found=false
    
    if find "${PROJECT_ROOT}" -name "*.tf" -exec grep -l "aws_db_instance\|aws_rds_cluster" {} + | \
       xargs grep -L "encrypted.*true" 2>/dev/null | head -1 | grep -q .; then
        unencrypted_found=true
    fi
    
    if [[ "$unencrypted_found" == "true" ]]; then
        log_error "Unencrypted storage resources found"
        record_check_result "POLICY" "UnencryptedStorage" "FAIL" "Unencrypted storage resources found" \
            "Enable encryption for all storage resources (RDS, EBS, S3, etc.)"
    else
        log_success "No unencrypted storage resources found"
        record_check_result "POLICY" "UnencryptedStorage" "PASS" "No unencrypted storage resources found" \
            "Continue using encryption for all storage resources"
    fi
}

# Helper function to process results from files
process_results_from_file() {
    local file="$1"
    local format="$2"  # "md", "json", or "csv"
    local output_file="$3"
    
    if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
        return
    fi
    
    while IFS='|' read -r check_id status description; do
        case "$format" in
            "md")
                echo "- **$check_id:** $status - $description" >> "$output_file"
                ;;
            "csv")
                echo "$check_id,$status,\"$description\"" >> "$output_file"
                ;;
        esac
    done < "$file"
}

# Generate compliance reports
generate_compliance_report() {
    log_info "Generating compliance reports..."
    
    local report_file="${REPORTS_DIR}/compliance-report-${TIMESTAMP}.md"
    local json_report="${REPORTS_DIR}/compliance-report-${TIMESTAMP}.json"
    local csv_report="${REPORTS_DIR}/compliance-report-${TIMESTAMP}.csv"
    
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

- **Overall Compliance Score:** $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%
- **Risk Level:** $(if [[ $FAILED_CHECKS -gt 5 ]]; then echo "HIGH"; elif [[ $FAILED_CHECKS -gt 2 ]]; then echo "MEDIUM"; else echo "LOW"; fi)

## NIST Cybersecurity Framework Results

EOF
    
    process_results_from_file "$NIST_RESULTS" "md" "$report_file"
    
    cat >> "$report_file" << EOF

## CIS Controls Results

EOF
    
    process_results_from_file "$CIS_RESULTS" "md" "$report_file"
    
    cat >> "$report_file" << EOF

## SOC 2 Type II Results

EOF
    
    process_results_from_file "$SOC2_RESULTS" "md" "$report_file"
    
    cat >> "$report_file" << EOF

## Terraform Best Practices Results

EOF
    
    process_results_from_file "$TERRAFORM_RESULTS" "md" "$report_file"
    
    cat >> "$report_file" << EOF

## Git Security Results

EOF
    
    process_results_from_file "$GIT_RESULTS" "md" "$report_file"
    
    cat >> "$report_file" << EOF

## AWS Best Practices Results

EOF
    
    process_results_from_file "$AWS_RESULTS" "md" "$report_file"
    
    cat >> "$report_file" << EOF

## Remediation Guide

### High Priority (Failed Checks)

EOF
    
    for check_id in "${!REMEDIATION_GUIDE[@]}"; do
        local status
        for category_checks in "${NIST_CHECKS[@]}" "${CIS_CHECKS[@]}" "${SOC2_CHECKS[@]}" "${TERRAFORM_CHECKS[@]}" "${GIT_CHECKS[@]}" "${AWS_CHECKS[@]}"; do
            if [[ "$category_checks" == *"$check_id"* ]]; then
                IFS='|' read -r status _ <<< "$category_checks"
                if [[ "$status" == "FAIL" ]]; then
                    echo "- **$check_id:** ${REMEDIATION_GUIDE[$check_id]}" >> "$report_file"
                fi
                break
            fi
        done
    done
    
    cat >> "$report_file" << EOF

### Medium Priority (Warnings)

EOF
    
    for check_id in "${!REMEDIATION_GUIDE[@]}"; do
        local status
        for category_checks in "${NIST_CHECKS[@]}" "${CIS_CHECKS[@]}" "${SOC2_CHECKS[@]}" "${TERRAFORM_CHECKS[@]}" "${GIT_CHECKS[@]}" "${AWS_CHECKS[@]}"; do
            if [[ "$category_checks" == *"$check_id"* ]]; then
                IFS='|' read -r status _ <<< "$category_checks"
                if [[ "$status" == "WARN" ]]; then
                    echo "- **$check_id:** ${REMEDIATION_GUIDE[$check_id]}" >> "$report_file"
                fi
                break
            fi
        done
    done
    
    # JSON Report
    cat > "$json_report" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "project": "$(basename "$PROJECT_ROOT")",
  "summary": {
    "total_checks": $TOTAL_CHECKS,
    "passed": $PASSED_CHECKS,
    "failed": $FAILED_CHECKS,
    "warnings": $WARNING_CHECKS,
    "compliance_score": $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
  },
  "results": {
EOF
    
    # Add JSON data for each category
    echo '    "nist": [' >> "$json_report"
    local first=true
    for check_id in "${!NIST_CHECKS[@]}"; do
        IFS='|' read -r status description <<< "${NIST_CHECKS[$check_id]}"
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ',' >> "$json_report"
        fi
        echo "      {\"id\": \"$check_id\", \"status\": \"$status\", \"description\": \"$description\", \"remediation\": \"${REMEDIATION_GUIDE[$check_id]}\"}" >> "$json_report"
    done
    echo '    ]' >> "$json_report"
    
    echo '  }' >> "$json_report"
    echo '}' >> "$json_report"
    
    # CSV Report
    echo "Category,Check ID,Status,Description,Remediation" > "$csv_report"
    
    for check_id in "${!NIST_CHECKS[@]}"; do
        IFS='|' read -r status description <<< "${NIST_CHECKS[$check_id]}"
        echo "NIST,$check_id,$status,\"$description\",\"${REMEDIATION_GUIDE[$check_id]}\"" >> "$csv_report"
    done
    
    for check_id in "${!CIS_CHECKS[@]}"; do
        IFS='|' read -r status description <<< "${CIS_CHECKS[$check_id]}"
        echo "CIS,$check_id,$status,\"$description\",\"${REMEDIATION_GUIDE[$check_id]}\"" >> "$csv_report"
    done
    
    for check_id in "${!SOC2_CHECKS[@]}"; do
        IFS='|' read -r status description <<< "${SOC2_CHECKS[$check_id]}"
        echo "SOC2,$check_id,$status,\"$description\",\"${REMEDIATION_GUIDE[$check_id]}\"" >> "$csv_report"
    done
    
    for check_id in "${!TERRAFORM_CHECKS[@]}"; do
        IFS='|' read -r status description <<< "${TERRAFORM_CHECKS[$check_id]}"
        echo "TERRAFORM,$check_id,$status,\"$description\",\"${REMEDIATION_GUIDE[$check_id]}\"" >> "$csv_report"
    done
    
    for check_id in "${!GIT_CHECKS[@]}"; do
        IFS='|' read -r status description <<< "${GIT_CHECKS[$check_id]}"
        echo "GIT,$check_id,$status,\"$description\",\"${REMEDIATION_GUIDE[$check_id]}\"" >> "$csv_report"
    done
    
    for check_id in "${!AWS_CHECKS[@]}"; do
        IFS='|' read -r status description <<< "${AWS_CHECKS[$check_id]}"
        echo "AWS,$check_id,$status,\"$description\",\"${REMEDIATION_GUIDE[$check_id]}\"" >> "$csv_report"
    done
    
    log_success "Reports generated:"
    log_info "  - Markdown: $report_file"
    log_info "  - JSON: $json_report"
    log_info "  - CSV: $csv_report"
}

# Track compliance over time
track_compliance_trends() {
    log_info "Tracking compliance trends..."
    
    local trends_file="${REPORTS_DIR}/compliance-trends.json"
    local current_data
    
    current_data=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "total_checks": $TOTAL_CHECKS,
  "passed": $PASSED_CHECKS,
  "failed": $FAILED_CHECKS,
  "warnings": $WARNING_CHECKS,
  "compliance_score": $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
}
EOF
)
    
    if [[ -f "$trends_file" ]]; then
        # Add to existing trends
        local temp_file="${TEMP_DIR}/trends.tmp"
        jq --argjson new_data "$current_data" '. += [$new_data]' "$trends_file" > "$temp_file"
        mv "$temp_file" "$trends_file"
    else
        # Create new trends file
        echo "[$current_data]" > "$trends_file"
    fi
    
    log_success "Compliance trends updated: $trends_file"
}

# Generate executive summary
generate_executive_summary() {
    log_info "Generating executive summary..."
    
    local exec_summary="${REPORTS_DIR}/compliance-executive-summary-${TIMESTAMP}.md"
    local compliance_score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    local risk_level
    
    if [[ $FAILED_CHECKS -gt 5 ]]; then
        risk_level="HIGH RISK"
    elif [[ $FAILED_CHECKS -gt 2 ]]; then
        risk_level="MEDIUM RISK"
    else
        risk_level="LOW RISK"
    fi
    
    cat > "$exec_summary" << EOF
# Compliance Executive Summary

## Key Metrics

- **Overall Compliance Score:** ${compliance_score}%
- **Risk Assessment:** ${risk_level}
- **Total Security Checks:** ${TOTAL_CHECKS}
- **Successful Checks:** ${PASSED_CHECKS}
- **Failed Checks:** ${FAILED_CHECKS}
- **Warnings:** ${WARNING_CHECKS}

## Compliance Framework Status

### NIST Cybersecurity Framework
$(( $(echo "${!NIST_CHECKS[@]}" | wc -w) )) checks performed across Identity, Protect, Detect domains

### CIS Controls
$(( $(echo "${!CIS_CHECKS[@]}" | wc -w) )) critical security controls evaluated

### SOC 2 Type II
$(( $(echo "${!SOC2_CHECKS[@]}" | wc -w) )) trust service criteria assessed

## Infrastructure Assessment

### Terraform Infrastructure as Code
$(( $(echo "${!TERRAFORM_CHECKS[@]}" | wc -w) )) best practice checks completed

### Git Security Posture
$(( $(echo "${!GIT_CHECKS[@]}" | wc -w) )) version control security checks performed

### AWS Cloud Security
$(( $(echo "${!AWS_CHECKS[@]}" | wc -w) )) cloud-specific security controls evaluated

## Recommendations

### Immediate Actions Required (Failed Checks: ${FAILED_CHECKS})
EOF
    
    local high_priority_count=0
    for check_id in "${!REMEDIATION_GUIDE[@]}"; do
        local found_fail=false
        for category in NIST CIS SOC2 TERRAFORM GIT AWS; do
            local -n category_ref="${category}_CHECKS"
            for category_check_id in "${!category_ref[@]}"; do
                if [[ "$category_check_id" == "$check_id" ]]; then
                    IFS='|' read -r status _ <<< "${category_ref[$category_check_id]}"
                    if [[ "$status" == "FAIL" ]]; then
                        echo "- ${REMEDIATION_GUIDE[$check_id]}" >> "$exec_summary"
                        ((high_priority_count++))
                        found_fail=true
                        break
                    fi
                fi
            done
            [[ "$found_fail" == "true" ]] && break
        done
    done
    
    if [[ $high_priority_count -eq 0 ]]; then
        echo "- No immediate actions required" >> "$exec_summary"
    fi
    
    cat >> "$exec_summary" << EOF

### Medium Priority Actions (Warnings: ${WARNING_CHECKS})
EOF
    
    local med_priority_count=0
    for check_id in "${!REMEDIATION_GUIDE[@]}"; do
        local found_warn=false
        for category in NIST CIS SOC2 TERRAFORM GIT AWS; do
            local -n category_ref="${category}_CHECKS"
            for category_check_id in "${!category_ref[@]}"; do
                if [[ "$category_check_id" == "$check_id" ]]; then
                    IFS='|' read -r status _ <<< "${category_ref[$category_check_id]}"
                    if [[ "$status" == "WARN" ]]; then
                        echo "- ${REMEDIATION_GUIDE[$check_id]}" >> "$exec_summary"
                        ((med_priority_count++))
                        found_warn=true
                        break
                    fi
                fi
            done
            [[ "$found_warn" == "true" ]] && break
        done
    done
    
    if [[ $med_priority_count -eq 0 ]]; then
        echo "- No medium priority actions identified" >> "$exec_summary"
    fi
    
    cat >> "$exec_summary" << EOF

## Next Steps

1. **Address Critical Failures:** Focus on the ${FAILED_CHECKS} failed security checks
2. **Implement Monitoring:** Set up continuous compliance monitoring
3. **Regular Reviews:** Schedule monthly compliance assessments
4. **Team Training:** Ensure team is aware of security best practices
5. **Automation:** Implement automated compliance checking in CI/CD pipelines

---
*Report generated on $(date) by Infrastructure Compliance Checker*
EOF
    
    log_success "Executive summary generated: $exec_summary"
}

# Main execution function
main() {
    log_info "Starting Infrastructure Compliance Checker..."
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
    generate_executive_summary
    
    # Final summary
    echo
    log_info "=== COMPLIANCE CHECK SUMMARY ==="
    log_info "Total Checks: $TOTAL_CHECKS"
    log_success "Passed: $PASSED_CHECKS"
    log_warn "Warnings: $WARNING_CHECKS"
    log_error "Failed: $FAILED_CHECKS"
    log_info "Compliance Score: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%"
    
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
Infrastructure Compliance Checker

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose logging
    -d, --debug         Enable debug logging
    --project-root DIR  Override project root directory

DESCRIPTION:
    Comprehensive compliance checker for infrastructure projects.
    
    Supports the following compliance frameworks and standards:
    - NIST Cybersecurity Framework
    - CIS Controls
    - SOC 2 Type II
    - Terraform Best Practices
    - Git Security Best Practices
    - AWS Well-Architected Framework
    
    The script generates detailed reports in multiple formats:
    - Markdown report for human reading
    - JSON report for automation integration
    - CSV report for spreadsheet analysis
    - Executive summary for management
    
EXAMPLES:
    # Run basic compliance check
    ./compliance-checker.sh
    
    # Run with verbose output
    ./compliance-checker.sh --verbose
    
    # Run with custom project root
    ./compliance-checker.sh --project-root /path/to/project

REPORTS:
    All reports are saved to: ${REPORTS_DIR}/
    
    - compliance-report-TIMESTAMP.md
    - compliance-report-TIMESTAMP.json  
    - compliance-report-TIMESTAMP.csv
    - compliance-executive-summary-TIMESTAMP.md
    - compliance-trends.json

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