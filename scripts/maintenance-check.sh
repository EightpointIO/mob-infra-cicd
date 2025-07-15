#!/bin/bash

# Infrastructure Maintenance and Health Check Script
# Created: $(date +%Y-%m-%d)
# Description: Comprehensive health check for Terraform infrastructure repositories

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="${SCRIPT_DIR}/maintenance-check.log"
readonly REPORT_FILE="${SCRIPT_DIR}/maintenance-report-$(date +%Y%m%d-%H%M%S).txt"

# Counters for summary
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Arrays to store results
FAILED_ITEMS=()
WARNING_ITEMS=()
RECOMMENDATIONS=()

# Helper functions
print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_section() {
    echo -e "\n${CYAN}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNING_ITEMS+=("$1")
    ((WARNING_CHECKS++))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    FAILED_ITEMS+=("$1")
    ((FAILED_CHECKS++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_recommendation() {
    echo -e "${PURPLE}💡${NC} $1"
    RECOMMENDATIONS+=("$1")
}

progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r${BLUE}Progress: [${NC}"
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $((width - completed)) | tr ' ' '-'
    printf "${BLUE}] %d%% (%d/%d)${NC}" $percentage $current $total
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Initialize log file
init_logging() {
    echo "Infrastructure Maintenance Check - $(date)" > "$LOG_FILE"
    echo "Project Root: $PROJECT_ROOT" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
}

# 1. Infrastructure Health Checking
check_infrastructure_health() {
    print_section "Infrastructure Health Check"
    local check_count=0
    
    # Check for large .terraform directories
    print_info "Checking for large .terraform directories..."
    ((TOTAL_CHECKS++))
    local terraform_dirs=$(find "$PROJECT_ROOT" -type d -name ".terraform" 2>/dev/null)
    
    if [[ -n "$terraform_dirs" ]]; then
        while IFS= read -r dir; do
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local size_mb=$(du -sm "$dir" 2>/dev/null | cut -f1)
            
            if [[ $size_mb -gt 100 ]]; then
                print_warning "Large .terraform directory found: $dir ($size)"
                print_recommendation "Consider running 'terraform init -upgrade' or cleaning up unused providers"
            else
                print_success ".terraform directory size acceptable: $dir ($size)"
            fi
        done <<< "$terraform_dirs"
    else
        print_success "No .terraform directories found"
    fi
    
    # Check for exposed state files
    print_info "Checking for exposed Terraform state files..."
    ((TOTAL_CHECKS++))
    local state_files=$(find "$PROJECT_ROOT" -name "terraform.tfstate*" -not -path "*/.terraform/*" 2>/dev/null)
    
    if [[ -n "$state_files" ]]; then
        while IFS= read -r file; do
            print_error "Exposed state file found: $file"
            print_recommendation "Move state files to secure backend (S3, Terraform Cloud, etc.)"
        done <<< "$state_files"
    else
        print_success "No exposed state files found"
    fi
    
    # Check for backend configuration
    print_info "Checking backend configurations..."
    ((TOTAL_CHECKS++))
    local tf_files=$(find "$PROJECT_ROOT" -name "*.tf" -type f 2>/dev/null)
    local has_backend=false
    
    if [[ -n "$tf_files" ]]; then
        while IFS= read -r file; do
            if grep -q "backend\s*\"" "$file" 2>/dev/null; then
                has_backend=true
                print_success "Backend configuration found in: $(basename "$file")"
                break
            fi
        done <<< "$tf_files"
        
        if [[ "$has_backend" == false ]]; then
            print_warning "No remote backend configuration found"
            print_recommendation "Configure remote backend for state management"
        fi
    fi
    
    # Check for provider version constraints
    print_info "Checking provider version constraints..."
    ((TOTAL_CHECKS++))
    local unconstrained_providers=0
    
    if [[ -n "$tf_files" ]]; then
        while IFS= read -r file; do
            if grep -E "^\s*provider\s+\"[^\"]+\"\s*{" "$file" > /dev/null 2>&1; then
                local provider_name=$(grep -E "^\s*provider\s+\"[^\"]+\"" "$file" | sed 's/.*"\([^"]*\)".*/\1/')
                if ! grep -A 10 "provider.*\"$provider_name\"" "$file" | grep -E "(version\s*=|required_version)" > /dev/null 2>&1; then
                    ((unconstrained_providers++))
                fi
            fi
        done <<< "$tf_files"
        
        if [[ $unconstrained_providers -gt 0 ]]; then
            print_warning "$unconstrained_providers provider(s) without version constraints"
            print_recommendation "Add version constraints to all providers for reproducible builds"
        else
            print_success "All providers have version constraints"
        fi
    fi
}

# 2. Security Scanning
check_security() {
    print_section "Security Scanning"
    
    # Check for hardcoded secrets/passwords
    print_info "Scanning for hardcoded secrets and passwords..."
    ((TOTAL_CHECKS++))
    
    local secret_patterns=(
        "password\s*=\s*[\"'][^\"']{8,}"
        "secret\s*=\s*[\"'][^\"']{8,}"
        "api[_-]?key\s*=\s*[\"'][^\"']{8,}"
        "access[_-]?key\s*=\s*[\"'][^\"']{16,}"
        "private[_-]?key\s*=\s*[\"'][^\"']{20,}"
        "token\s*=\s*[\"'][^\"']{8,}"
        "aws_access_key_id\s*=\s*[\"']AKIA[0-9A-Z]{16}[\"']"
        "aws_secret_access_key\s*=\s*[\"'][A-Za-z0-9/+=]{40}[\"']"
    )
    
    local secrets_found=false
    for pattern in "${secret_patterns[@]}"; do
        local matches=$(grep -r -E -i "$pattern" "$PROJECT_ROOT" \
            --include="*.tf" --include="*.tfvars" --include="*.yaml" --include="*.yml" \
            --include="*.json" --include="*.sh" --include="*.py" \
            --exclude-dir=".git" --exclude-dir=".terraform" 2>/dev/null || true)
        
        if [[ -n "$matches" ]]; then
            secrets_found=true
            while IFS= read -r match; do
                local file=$(echo "$match" | cut -d: -f1)
                print_error "Potential hardcoded secret in: $(basename "$file")"
            done <<< "$matches"
        fi
    done
    
    if [[ "$secrets_found" == false ]]; then
        print_success "No hardcoded secrets detected"
    else
        print_recommendation "Use environment variables, AWS Secrets Manager, or HashiCorp Vault for secrets"
    fi
    
    # Check for insecure configurations
    print_info "Checking for insecure configurations..."
    ((TOTAL_CHECKS++))
    
    local insecure_patterns=(
        "publicly_accessible\s*=\s*true"
        "skip_final_snapshot\s*=\s*true"
        "encryption\s*=\s*false"
        "enforce_ssl\s*=\s*false"
        "enable_logging\s*=\s*false"
    )
    
    local insecure_found=false
    for pattern in "${insecure_patterns[@]}"; do
        local matches=$(grep -r -E -i "$pattern" "$PROJECT_ROOT" \
            --include="*.tf" --exclude-dir=".git" --exclude-dir=".terraform" 2>/dev/null || true)
        
        if [[ -n "$matches" ]]; then
            insecure_found=true
            while IFS= read -r match; do
                local file=$(echo "$match" | cut -d: -f1)
                print_warning "Potentially insecure configuration in: $(basename "$file")"
            done <<< "$matches"
        fi
    done
    
    if [[ "$insecure_found" == false ]]; then
        print_success "No obviously insecure configurations found"
    else
        print_recommendation "Review flagged configurations for security best practices"
    fi
    
    # Check file permissions
    print_info "Checking sensitive file permissions..."
    ((TOTAL_CHECKS++))
    
    local sensitive_files=$(find "$PROJECT_ROOT" -name "*.tfvars" -o -name "*.pem" -o -name "*.key" 2>/dev/null)
    local permission_issues=false
    
    if [[ -n "$sensitive_files" ]]; then
        while IFS= read -r file; do
            local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
            if [[ ${perms: -1} -gt 0 ]] || [[ ${perms: -2:1} -gt 0 ]]; then
                permission_issues=true
                print_warning "Sensitive file has permissive permissions: $file ($perms)"
            fi
        done <<< "$sensitive_files"
        
        if [[ "$permission_issues" == false ]]; then
            print_success "Sensitive file permissions are secure"
        else
            print_recommendation "Restrict permissions on sensitive files (chmod 600)"
        fi
    else
        print_success "No sensitive files with permission issues found"
    fi
}

# 3. Module Version Consistency
check_module_versions() {
    print_section "Module Version Consistency Check"
    
    print_info "Analyzing module version consistency..."
    ((TOTAL_CHECKS++))
    
    # Extract module sources and versions
    local modules_info=$(find "$PROJECT_ROOT" -name "*.tf" -type f -exec grep -H -E "^\s*module\s+\"[^\"]+\"\s*{" {} \; 2>/dev/null)
    
    if [[ -n "$modules_info" ]]; then
        local inconsistent_found=false
        declare -A module_versions
        
        while IFS= read -r line; do
            local file=$(echo "$line" | cut -d: -f1)
            local module_block_start=$(echo "$line" | cut -d: -f2-)
            
            # Extract module name
            local module_name=$(echo "$module_block_start" | sed -E 's/.*module[[:space:]]*"([^"]+)".*/\1/')
            
            # Look for source and version in the next few lines
            local line_num=$(grep -n "$module_block_start" "$file" | cut -d: -f1)
            local source_line=$(sed -n "${line_num},+20p" "$file" | grep -E "source\s*=" | head -1)
            local version_line=$(sed -n "${line_num},+20p" "$file" | grep -E "version\s*=" | head -1)
            
            if [[ -n "$source_line" ]]; then
                local source=$(echo "$source_line" | sed -E 's/.*source[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/')
                local version="unspecified"
                
                if [[ -n "$version_line" ]]; then
                    version=$(echo "$version_line" | sed -E 's/.*version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/')
                fi
                
                local key="${source}"
                if [[ -n "${module_versions[$key]:-}" ]] && [[ "${module_versions[$key]}" != "$version" ]]; then
                    inconsistent_found=true
                    print_warning "Module version inconsistency: $source (versions: ${module_versions[$key]}, $version)"
                else
                    module_versions[$key]="$version"
                fi
            fi
        done <<< "$modules_info"
        
        if [[ "$inconsistent_found" == false ]]; then
            print_success "Module versions are consistent"
        else
            print_recommendation "Standardize module versions across all configurations"
        fi
        
        # Check for unversioned modules
        local unversioned_count=0
        for key in "${!module_versions[@]}"; do
            if [[ "${module_versions[$key]}" == "unspecified" ]]; then
                ((unversioned_count++))
            fi
        done
        
        if [[ $unversioned_count -gt 0 ]]; then
            print_warning "$unversioned_count module(s) without version specification"
            print_recommendation "Add version constraints to all external modules"
        else
            print_success "All modules have version specifications"
        fi
    else
        print_info "No module declarations found"
    fi
}

# 4. .gitignore Completeness
check_gitignore() {
    print_section ".gitignore Completeness Check"
    
    print_info "Verifying .gitignore completeness..."
    ((TOTAL_CHECKS++))
    
    local gitignore_file="$PROJECT_ROOT/.gitignore"
    local required_patterns=(
        "*.tfstate"
        "*.tfstate.*"
        "*.tfvars"
        ".terraform/"
        ".terraform.lock.hcl"
        "*.log"
        "*.backup"
        ".DS_Store"
        "Thumbs.db"
        "*.tmp"
        "*.temp"
        ".env"
        ".env.*"
    )
    
    if [[ -f "$gitignore_file" ]]; then
        local missing_patterns=()
        
        for pattern in "${required_patterns[@]}"; do
            if ! grep -Fxq "$pattern" "$gitignore_file"; then
                missing_patterns+=("$pattern")
            fi
        done
        
        if [[ ${#missing_patterns[@]} -eq 0 ]]; then
            print_success ".gitignore contains all recommended patterns"
        else
            print_warning ".gitignore missing ${#missing_patterns[@]} recommended pattern(s)"
            for pattern in "${missing_patterns[@]}"; do
                print_info "  Missing: $pattern"
            done
            print_recommendation "Add missing patterns to .gitignore"
        fi
        
        # Check for tracked files that should be ignored
        if command -v git > /dev/null && [[ -d "$PROJECT_ROOT/.git" ]]; then
            local tracked_sensitive=$(git -C "$PROJECT_ROOT" ls-files | grep -E "\.(tfstate|tfvars|log|env)$" || true)
            if [[ -n "$tracked_sensitive" ]]; then
                print_error "Sensitive files are being tracked by git:"
                while IFS= read -r file; do
                    print_info "  $file"
                done <<< "$tracked_sensitive"
                print_recommendation "Remove sensitive files from git tracking: git rm --cached <file>"
            fi
        fi
    else
        print_error ".gitignore file not found"
        print_recommendation "Create .gitignore with Terraform-specific patterns"
    fi
}

# 5. Terraform Formatting
check_terraform_formatting() {
    print_section "Terraform Formatting Check"
    
    if ! command -v terraform > /dev/null; then
        print_warning "Terraform CLI not found, skipping formatting check"
        return
    fi
    
    print_info "Checking Terraform file formatting..."
    ((TOTAL_CHECKS++))
    
    local tf_dirs=$(find "$PROJECT_ROOT" -name "*.tf" -type f -exec dirname {} \; | sort -u)
    local formatting_issues=false
    
    if [[ -n "$tf_dirs" ]]; then
        while IFS= read -r dir; do
            # Skip .terraform directories
            if [[ "$dir" == *".terraform"* ]]; then
                continue
            fi
            
            local format_output=$(terraform -chdir="$dir" fmt -check -diff 2>/dev/null || true)
            if [[ -n "$format_output" ]]; then
                formatting_issues=true
                print_warning "Formatting issues in: $dir"
            fi
        done <<< "$tf_dirs"
        
        if [[ "$formatting_issues" == false ]]; then
            print_success "All Terraform files are properly formatted"
        else
            print_recommendation "Run 'terraform fmt -recursive' to fix formatting issues"
        fi
    else
        print_info "No Terraform files found"
    fi
    
    # Check for consistent indentation
    print_info "Checking indentation consistency..."
    ((TOTAL_CHECKS++))
    
    local tf_files=$(find "$PROJECT_ROOT" -name "*.tf" -type f 2>/dev/null)
    local mixed_indentation=false
    
    if [[ -n "$tf_files" ]]; then
        while IFS= read -r file; do
            local has_tabs=$(grep -P "^\t" "$file" 2>/dev/null || true)
            local has_spaces=$(grep -P "^  " "$file" 2>/dev/null || true)
            
            if [[ -n "$has_tabs" ]] && [[ -n "$has_spaces" ]]; then
                mixed_indentation=true
                print_warning "Mixed indentation in: $(basename "$file")"
            fi
        done <<< "$tf_files"
        
        if [[ "$mixed_indentation" == false ]]; then
            print_success "Indentation is consistent across files"
        else
            print_recommendation "Use consistent indentation (spaces recommended for Terraform)"
        fi
    fi
}

# 6. Repository Size Monitoring
check_repository_size() {
    print_section "Repository Size Monitoring"
    
    print_info "Analyzing repository size..."
    ((TOTAL_CHECKS++))
    
    local total_size=$(du -sh "$PROJECT_ROOT" 2>/dev/null | cut -f1)
    local total_size_mb=$(du -sm "$PROJECT_ROOT" 2>/dev/null | cut -f1)
    
    print_info "Total repository size: $total_size"
    
    if [[ $total_size_mb -gt 500 ]]; then
        print_warning "Repository size is large ($total_size)"
        print_recommendation "Consider using Git LFS for large files or cleaning up unnecessary files"
    elif [[ $total_size_mb -gt 1000 ]]; then
        print_error "Repository size is very large ($total_size)"
        print_recommendation "Immediate action needed: clean up large files and consider repository restructuring"
    else
        print_success "Repository size is reasonable ($total_size)"
    fi
    
    # Find largest files
    print_info "Finding largest files..."
    local large_files=$(find "$PROJECT_ROOT" -type f -size +10M 2>/dev/null | head -10)
    
    if [[ -n "$large_files" ]]; then
        print_warning "Large files found (>10MB):"
        while IFS= read -r file; do
            local size=$(du -sh "$file" 2>/dev/null | cut -f1)
            print_info "  $file ($size)"
        done <<< "$large_files"
        print_recommendation "Consider using Git LFS for large binary files"
    else
        print_success "No unusually large files found"
    fi
    
    # Check for large directories
    print_info "Checking directory sizes..."
    local dir_sizes=$(find "$PROJECT_ROOT" -type d -exec du -sm {} \; 2>/dev/null | sort -nr | head -5)
    
    if [[ -n "$dir_sizes" ]]; then
        print_info "Largest directories:"
        while IFS= read -r line; do
            local size=$(echo "$line" | cut -f1)
            local dir=$(echo "$line" | cut -f2-)
            if [[ $size -gt 50 ]]; then
                print_info "  $dir (${size}MB)"
            fi
        done <<< "$dir_sizes"
    fi
}

# 7. Performance Metrics
collect_performance_metrics() {
    print_section "Performance Metrics Collection"
    
    # Count resources
    print_info "Collecting resource statistics..."
    ((TOTAL_CHECKS++))
    
    local tf_files=$(find "$PROJECT_ROOT" -name "*.tf" -type f 2>/dev/null)
    
    if [[ -n "$tf_files" ]]; then
        local resource_count=0
        local data_source_count=0
        local module_count=0
        local variable_count=0
        local output_count=0
        local local_count=0
        
        while IFS= read -r file; do
            resource_count=$((resource_count + $(grep -c "^resource " "$file" 2>/dev/null || echo 0)))
            data_source_count=$((data_source_count + $(grep -c "^data " "$file" 2>/dev/null || echo 0)))
            module_count=$((module_count + $(grep -c "^module " "$file" 2>/dev/null || echo 0)))
            variable_count=$((variable_count + $(grep -c "^variable " "$file" 2>/dev/null || echo 0)))
            output_count=$((output_count + $(grep -c "^output " "$file" 2>/dev/null || echo 0)))
            local_count=$((local_count + $(grep -c "^locals " "$file" 2>/dev/null || echo 0)))
        done <<< "$tf_files"
        
        print_info "Resource statistics:"
        print_info "  Resources: $resource_count"
        print_info "  Data sources: $data_source_count"
        print_info "  Modules: $module_count"
        print_info "  Variables: $variable_count"
        print_info "  Outputs: $output_count"
        print_info "  Locals blocks: $local_count"
        
        local total_declarations=$((resource_count + data_source_count + module_count))
        
        if [[ $total_declarations -gt 200 ]]; then
            print_warning "High number of declarations ($total_declarations)"
            print_recommendation "Consider breaking down into smaller, focused modules"
        else
            print_success "Declaration count is manageable ($total_declarations)"
        fi
    else
        print_info "No Terraform files found for analysis"
    fi
    
    # Check complexity indicators
    print_info "Analyzing complexity indicators..."
    ((TOTAL_CHECKS++))
    
    if [[ -n "$tf_files" ]]; then
        local complex_expressions=0
        local long_files=0
        
        while IFS= read -r file; do
            local line_count=$(wc -l < "$file" 2>/dev/null || echo 0)
            if [[ $line_count -gt 500 ]]; then
                ((long_files++))
                print_warning "Large file: $(basename "$file") ($line_count lines)"
            fi
            
            # Count complex expressions (nested functions, conditionals)
            local nested_count=$(grep -E "(for_each|count|lookup|try|can|contains)" "$file" 2>/dev/null | wc -l)
            complex_expressions=$((complex_expressions + nested_count))
        done <<< "$tf_files"
        
        if [[ $long_files -gt 0 ]]; then
            print_recommendation "Consider splitting large files into smaller, focused modules"
        fi
        
        if [[ $complex_expressions -gt 50 ]]; then
            print_warning "High number of complex expressions ($complex_expressions)"
            print_recommendation "Review complex expressions for readability and maintainability"
        else
            print_success "Complexity metrics are within acceptable range"
        fi
    fi
}

# 8. Cleanup Recommendations
generate_cleanup_recommendations() {
    print_section "Cleanup Recommendations"
    
    print_info "Generating cleanup recommendations..."
    
    # Check for temporary files
    local temp_files=$(find "$PROJECT_ROOT" -name "*.tmp" -o -name "*.temp" -o -name "*.bak" -o -name "*~" 2>/dev/null)
    if [[ -n "$temp_files" ]]; then
        print_recommendation "Clean up temporary files:"
        while IFS= read -r file; do
            print_info "  $file"
        done <<< "$temp_files"
    fi
    
    # Check for old log files
    local old_logs=$(find "$PROJECT_ROOT" -name "*.log" -mtime +30 2>/dev/null)
    if [[ -n "$old_logs" ]]; then
        print_recommendation "Archive or remove old log files (>30 days):"
        while IFS= read -r file; do
            print_info "  $file"
        done <<< "$old_logs"
    fi
    
    # Check for unused variables
    print_info "Checking for potentially unused variables..."
    local tf_files=$(find "$PROJECT_ROOT" -name "*.tf" -type f 2>/dev/null)
    
    if [[ -n "$tf_files" ]]; then
        local all_content=$(cat $tf_files 2>/dev/null)
        local variables=$(grep -h "^variable " $tf_files 2>/dev/null | sed 's/variable "\([^"]*\)".*/\1/' | sort -u)
        
        if [[ -n "$variables" ]]; then
            local unused_vars=()
            while IFS= read -r var; do
                if ! echo "$all_content" | grep -q "var\.$var\b"; then
                    unused_vars+=("$var")
                fi
            done <<< "$variables"
            
            if [[ ${#unused_vars[@]} -gt 0 ]]; then
                print_recommendation "Review potentially unused variables:"
                for var in "${unused_vars[@]}"; do
                    print_info "  $var"
                done
            fi
        fi
    fi
    
    # Check for duplicate code patterns
    print_info "Checking for duplicate code patterns..."
    if [[ -n "$tf_files" ]] && command -v sort > /dev/null && command -v uniq > /dev/null; then
        local resource_types=$(grep -h "^resource " $tf_files 2>/dev/null | awk '{print $2}' | tr -d '"' | sort | uniq -c | sort -nr)
        
        if [[ -n "$resource_types" ]]; then
            local high_duplicates=$(echo "$resource_types" | awk '$1 > 5 {print $1, $2}')
            if [[ -n "$high_duplicates" ]]; then
                print_recommendation "Consider creating modules for frequently used resources:"
                while IFS= read -r line; do
                    print_info "  $line"
                done <<< "$high_duplicates"
            fi
        fi
    fi
}

# Summary Report Generation
generate_summary_report() {
    print_header "MAINTENANCE CHECK SUMMARY"
    
    local total_issues=$((FAILED_CHECKS + WARNING_CHECKS))
    
    echo -e "${WHITE}Check Statistics:${NC}"
    echo -e "  Total Checks: ${BLUE}$TOTAL_CHECKS${NC}"
    echo -e "  Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "  Warnings: ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "  Failed: ${RED}$FAILED_CHECKS${NC}"
    echo -e "  Success Rate: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%"
    
    if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
        echo -e "\n${RED}Failed Checks:${NC}"
        for item in "${FAILED_ITEMS[@]}"; do
            echo -e "  ${RED}✗${NC} $item"
        done
    fi
    
    if [[ ${#WARNING_ITEMS[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Warnings:${NC}"
        for item in "${WARNING_ITEMS[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} $item"
        done
    fi
    
    if [[ ${#RECOMMENDATIONS[@]} -gt 0 ]]; then
        echo -e "\n${PURPLE}Recommendations:${NC}"
        for item in "${RECOMMENDATIONS[@]}"; do
            echo -e "  ${PURPLE}💡${NC} $item"
        done
    fi
    
    # Overall health score
    local health_score=100
    health_score=$((health_score - (FAILED_CHECKS * 10)))
    health_score=$((health_score - (WARNING_CHECKS * 3)))
    
    echo -e "\n${WHITE}Overall Health Score: "
    if [[ $health_score -ge 90 ]]; then
        echo -e "${GREEN}$health_score/100 (Excellent)${NC}"
    elif [[ $health_score -ge 75 ]]; then
        echo -e "${YELLOW}$health_score/100 (Good)${NC}"
    elif [[ $health_score -ge 50 ]]; then
        echo -e "${YELLOW}$health_score/100 (Fair)${NC}"
    else
        echo -e "${RED}$health_score/100 (Needs Attention)${NC}"
    fi
    
    echo -e "\n${BLUE}Report saved to: $REPORT_FILE${NC}"
    echo -e "${BLUE}Detailed log: $LOG_FILE${NC}"
}

# Save report to file
save_report() {
    {
        echo "Infrastructure Maintenance Check Report"
        echo "Generated: $(date)"
        echo "Project: $PROJECT_ROOT"
        echo "========================================"
        echo
        echo "SUMMARY STATISTICS"
        echo "Total Checks: $TOTAL_CHECKS"
        echo "Passed: $PASSED_CHECKS"
        echo "Warnings: $WARNING_CHECKS"
        echo "Failed: $FAILED_CHECKS"
        echo "Success Rate: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%"
        echo
        
        if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
            echo "FAILED CHECKS:"
            for item in "${FAILED_ITEMS[@]}"; do
                echo "- $item"
            done
            echo
        fi
        
        if [[ ${#WARNING_ITEMS[@]} -gt 0 ]]; then
            echo "WARNINGS:"
            for item in "${WARNING_ITEMS[@]}"; do
                echo "- $item"
            done
            echo
        fi
        
        if [[ ${#RECOMMENDATIONS[@]} -gt 0 ]]; then
            echo "RECOMMENDATIONS:"
            for item in "${RECOMMENDATIONS[@]}"; do
                echo "- $item"
            done
            echo
        fi
        
        echo "========================================"
        echo "For detailed information, see: $LOG_FILE"
    } > "$REPORT_FILE"
}

# Main execution function
run_all_checks() {
    print_header "Infrastructure Maintenance & Health Check"
    echo -e "${WHITE}Starting comprehensive infrastructure analysis...${NC}\n"
    
    local total_sections=8
    local current_section=0
    
    progress_bar $current_section $total_sections
    check_infrastructure_health
    ((current_section++))
    
    progress_bar $current_section $total_sections
    check_security
    ((current_section++))
    
    progress_bar $current_section $total_sections
    check_module_versions
    ((current_section++))
    
    progress_bar $current_section $total_sections
    check_gitignore
    ((current_section++))
    
    progress_bar $current_section $total_sections
    check_terraform_formatting
    ((current_section++))
    
    progress_bar $current_section $total_sections
    check_repository_size
    ((current_section++))
    
    progress_bar $current_section $total_sections
    collect_performance_metrics
    ((current_section++))
    
    progress_bar $current_section $total_sections
    generate_cleanup_recommendations
    ((current_section++))
    
    echo -e "\n"
    generate_summary_report
    save_report
}

# Individual check functions for selective execution
run_infrastructure_check() {
    init_logging
    check_infrastructure_health
    generate_summary_report
    save_report
}

run_security_check() {
    init_logging
    check_security
    generate_summary_report
    save_report
}

run_module_check() {
    init_logging
    check_module_versions
    generate_summary_report
    save_report
}

run_formatting_check() {
    init_logging
    check_terraform_formatting
    generate_summary_report
    save_report
}

# Help function
show_help() {
    echo -e "${WHITE}Infrastructure Maintenance & Health Check Script${NC}"
    echo
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0 [OPTIONS]"
    echo
    echo -e "${CYAN}Options:${NC}"
    echo -e "  -a, --all              Run all checks (default)"
    echo -e "  -i, --infrastructure   Infrastructure health check only"
    echo -e "  -s, --security         Security scanning only"
    echo -e "  -m, --modules          Module version consistency check only"
    echo -e "  -f, --format           Terraform formatting check only"
    echo -e "  -g, --gitignore        .gitignore completeness check only"
    echo -e "  -r, --repository       Repository size monitoring only"
    echo -e "  -p, --performance      Performance metrics collection only"
    echo -e "  -c, --cleanup          Cleanup recommendations only"
    echo -e "  -h, --help             Show this help message"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0                     # Run all checks"
    echo -e "  $0 --security          # Run security checks only"
    echo -e "  $0 -i -s               # Run infrastructure and security checks"
    echo
    echo -e "${CYAN}Output Files:${NC}"
    echo -e "  Log file: ${SCRIPT_DIR}/maintenance-check.log"
    echo -e "  Report file: ${SCRIPT_DIR}/maintenance-report-YYYYMMDD-HHMMSS.txt"
}

# Main script execution
main() {
    # Initialize logging
    init_logging
    
    # Parse command line arguments
    local run_all=true
    local run_infra=false
    local run_security=false
    local run_modules=false
    local run_format=false
    local run_gitignore=false
    local run_repo=false
    local run_perf=false
    local run_cleanup=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                run_all=true
                shift
                ;;
            -i|--infrastructure)
                run_all=false
                run_infra=true
                shift
                ;;
            -s|--security)
                run_all=false
                run_security=true
                shift
                ;;
            -m|--modules)
                run_all=false
                run_modules=true
                shift
                ;;
            -f|--format)
                run_all=false
                run_format=true
                shift
                ;;
            -g|--gitignore)
                run_all=false
                run_gitignore=true
                shift
                ;;
            -r|--repository)
                run_all=false
                run_repo=true
                shift
                ;;
            -p|--performance)
                run_all=false
                run_perf=true
                shift
                ;;
            -c|--cleanup)
                run_all=false
                run_cleanup=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Execute checks based on arguments
    if [[ "$run_all" == true ]]; then
        run_all_checks
    else
        print_header "Selective Infrastructure Checks"
        
        [[ "$run_infra" == true ]] && check_infrastructure_health
        [[ "$run_security" == true ]] && check_security
        [[ "$run_modules" == true ]] && check_module_versions
        [[ "$run_format" == true ]] && check_terraform_formatting
        [[ "$run_gitignore" == true ]] && check_gitignore
        [[ "$run_repo" == true ]] && check_repository_size
        [[ "$run_perf" == true ]] && collect_performance_metrics
        [[ "$run_cleanup" == true ]] && generate_cleanup_recommendations
        
        generate_summary_report
        save_report
    fi
    
    log_message "Maintenance check completed successfully"
}

# Execute main function with all arguments
main "$@"