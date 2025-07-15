#!/bin/bash

# Infrastructure Health Reporter Script
# Created: $(date +%Y-%m-%d)
# Description: Comprehensive health reporting system with visualizations, notifications, and multi-format output
# Features: Markdown reports, JSON/CSV/HTML export, Slack/email notifications, trend tracking, executive summaries

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly REPORTS_DIR="${PROJECT_ROOT}/reports"
readonly LOGS_DIR="${SCRIPT_DIR}/logs"
readonly TEMP_DIR="${SCRIPT_DIR}/temp"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly DATE_HUMAN="$(date '+%B %d, %Y at %H:%M:%S')"

# Report files
readonly HEALTH_LOG="${LOGS_DIR}/health-reporter-${TIMESTAMP}.log"
readonly MARKDOWN_REPORT="${REPORTS_DIR}/health-report-${TIMESTAMP}.md"
readonly JSON_REPORT="${REPORTS_DIR}/health-report-${TIMESTAMP}.json"
readonly CSV_REPORT="${REPORTS_DIR}/health-report-${TIMESTAMP}.csv"
readonly HTML_REPORT="${REPORTS_DIR}/health-report-${TIMESTAMP}.html"
readonly EXECUTIVE_SUMMARY="${REPORTS_DIR}/executive-summary-${TIMESTAMP}.md"
readonly TRENDS_DATA="${REPORTS_DIR}/health-trends.json"

# Health metrics collection (using regular variables for compatibility)
HEALTH_METRICS_FILE="${TEMP_DIR}/health_metrics.tmp"
PERFORMANCE_METRICS_FILE="${TEMP_DIR}/performance_metrics.tmp"
SECURITY_METRICS_FILE="${TEMP_DIR}/security_metrics.tmp"
COMPLIANCE_METRICS_FILE="${TEMP_DIR}/compliance_metrics.tmp"
ALERTS_FILE="${TEMP_DIR}/alerts.tmp"
RECOMMENDATIONS_FILE="${TEMP_DIR}/recommendations.tmp"
CRITICAL_ISSUES_FILE="${TEMP_DIR}/critical_issues.tmp"

# Helper functions for metrics storage
set_health_metric() {
    echo "$1=$2" >> "$HEALTH_METRICS_FILE"
}

get_health_metric() {
    grep "^$1=" "$HEALTH_METRICS_FILE" 2>/dev/null | tail -1 | cut -d'=' -f2- || echo "0"
}

add_recommendation() {
    echo "$1" >> "$RECOMMENDATIONS_FILE"
}

add_critical_issue() {
    echo "$1" >> "$CRITICAL_ISSUES_FILE"
}

count_recommendations() {
    wc -l < "$RECOMMENDATIONS_FILE" 2>/dev/null || echo "0"
}

count_critical_issues() {
    wc -l < "$CRITICAL_ISSUES_FILE" 2>/dev/null || echo "0"
}

get_security_metric() {
    grep "^$1=" "$SECURITY_METRICS_FILE" 2>/dev/null | tail -1 | cut -d'=' -f2- || echo "0"
}

get_performance_metric() {
    grep "^$1=" "$PERFORMANCE_METRICS_FILE" 2>/dev/null | tail -1 | cut -d'=' -f2- || echo "0"
}

get_compliance_metric() {
    grep "^$1=" "$COMPLIANCE_METRICS_FILE" 2>/dev/null | tail -1 | cut -d'=' -f2- || echo "0"
}

# Configuration options
ENABLE_SLACK_NOTIFICATIONS=true
ENABLE_EMAIL_NOTIFICATIONS=false
ENABLE_CHARTS=true
ENABLE_TREND_TRACKING=true
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
EMAIL_RECIPIENTS="${EMAIL_RECIPIENTS:-}"
HEALTH_THRESHOLD_CRITICAL=60
HEALTH_THRESHOLD_WARNING=80

# Initialize directories and logging
init_environment() {
    mkdir -p "$REPORTS_DIR" "$LOGS_DIR" "$TEMP_DIR"
    
    # Initialize metrics files
    touch "$HEALTH_METRICS_FILE" "$PERFORMANCE_METRICS_FILE" "$SECURITY_METRICS_FILE" \
          "$COMPLIANCE_METRICS_FILE" "$RECOMMENDATIONS_FILE" "$CRITICAL_ISSUES_FILE"
    
    # Initialize log file
    {
        echo "Infrastructure Health Reporter - $(date)"
        echo "Project Root: $PROJECT_ROOT"
        echo "Report Generation Started: $DATE_HUMAN"
        echo "========================================"
    } > "$HEALTH_LOG"
}

# Logging functions
log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" >> "$HEALTH_LOG"
}

print_header() {
    echo -e "\n${BLUE}${BOLD}============================================${NC}"
    echo -e "${WHITE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}============================================${NC}\n"
    log_message "INFO" "HEADER: $1"
}

print_section() {
    echo -e "\n${CYAN}${BOLD}>>> $1${NC}"
    log_message "INFO" "SECTION: $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    log_message "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    log_message "WARNING" "$1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    log_message "ERROR" "$1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
    log_message "INFO" "$1"
}

print_progress() {
    echo -e "${PURPLE}⟳${NC} $1"
    log_message "PROGRESS" "$1"
}

# Progress bar
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

# Health score calculation
calculate_health_score() {
    local infrastructure_score=$(get_health_metric infrastructure_score)
    local security_score=$(get_health_metric security_score)
    local performance_score=$(get_health_metric performance_score)
    local compliance_score=$(get_health_metric compliance_score)
    
    # Weighted average (infrastructure and security are most important)
    local total_score=$(( (infrastructure_score * 30 + security_score * 30 + performance_score * 20 + compliance_score * 20) / 100 ))
    
    set_health_metric overall_score $total_score
    
    if [[ $total_score -ge 90 ]]; then
        set_health_metric health_status "Excellent"
        set_health_metric health_color "green"
    elif [[ $total_score -ge $HEALTH_THRESHOLD_WARNING ]]; then
        set_health_metric health_status "Good"
        set_health_metric health_color "yellow"
    elif [[ $total_score -ge $HEALTH_THRESHOLD_CRITICAL ]]; then
        set_health_metric health_status "Fair"
        set_health_metric health_color "orange"
    else
        set_health_metric health_status "Critical"
        set_health_metric health_color "red"
        add_critical_issue "Overall health score below critical threshold ($total_score/100)"
    fi
}

# Infrastructure health collection
collect_infrastructure_health() {
    print_section "Collecting Infrastructure Health Metrics"
    
    local score=100
    local issues=0
    
    # Run maintenance check if available
    if [[ -f "${SCRIPT_DIR}/maintenance-check.sh" ]]; then
        print_info "Running infrastructure maintenance checks..."
        local maintenance_output
        if maintenance_output=$(bash "${SCRIPT_DIR}/maintenance-check.sh" 2>&1); then
            print_success "Maintenance checks completed successfully"
            
            # Parse maintenance check results
            if echo "$maintenance_output" | grep -q "Failed: 0"; then
                score=$((score + 0))
            else
                local failed_count=$(echo "$maintenance_output" | grep -oE "Failed: [0-9]+" | grep -oE "[0-9]+")
                score=$((score - (failed_count * 10)))
                issues=$((issues + failed_count))
            fi
            
            if echo "$maintenance_output" | grep -q "Warnings:"; then
                local warning_count=$(echo "$maintenance_output" | grep -oE "Warnings: [0-9]+" | grep -oE "[0-9]+")
                score=$((score - (warning_count * 3)))
            fi
        else
            print_warning "Maintenance checks failed or incomplete"
            score=$((score - 20))
            issues=$((issues + 1))
        fi
    else
        print_warning "Maintenance check script not found"
        score=$((score - 10))
    fi
    
    # Check Terraform state
    print_info "Checking Terraform state health..."
    local terraform_dirs=$(find "$PROJECT_ROOT" -name "*.tf" -type f -exec dirname {} \; | sort -u | head -10)
    local terraform_issues=0
    
    if [[ -n "$terraform_dirs" ]]; then
        while IFS= read -r dir; do
            if [[ "$dir" == *".terraform"* ]]; then
                continue
            fi
            
            # Check if terraform validate passes
            if command -v terraform > /dev/null; then
                if ! terraform -chdir="$dir" validate > /dev/null 2>&1; then
                    terraform_issues=$((terraform_issues + 1))
                fi
            fi
        done <<< "$terraform_dirs"
        
        if [[ $terraform_issues -eq 0 ]]; then
            print_success "All Terraform configurations are valid"
        else
            print_warning "$terraform_issues Terraform configuration(s) have validation issues"
            score=$((score - (terraform_issues * 15)))
            issues=$((issues + terraform_issues))
        fi
    fi
    
    # Check for exposed secrets or credentials
    print_info "Scanning for exposed credentials..."
    local secret_files=$(find "$PROJECT_ROOT" -name "*.tfvars" -o -name "*.env" -o -name "*.key" -o -name "*.pem" 2>/dev/null | wc -l)
    
    if [[ $secret_files -gt 0 ]]; then
        print_warning "Found $secret_files potentially sensitive files"
        add_recommendation "Review and secure sensitive files"
        score=$((score - 5))
    fi
    
    # Ensure score doesn't go below 0
    if [[ $score -lt 0 ]]; then
        score=0
    fi
    
    set_health_metric infrastructure_score $score
    set_health_metric infrastructure_issues $issues
    
    print_success "Infrastructure health assessment complete (Score: $score/100)"
}

# Security health collection
collect_security_health() {
    print_section "Collecting Security Health Metrics"
    
    local score=100
    local vulnerabilities=0
    local security_issues=0
    
    # Check for hardcoded secrets
    print_info "Scanning for hardcoded secrets..."
    local secret_patterns=(
        "password\s*=\s*[\"'][^\"']{8,}"
        "secret\s*=\s*[\"'][^\"']{8,}"
        "api[_-]?key\s*=\s*[\"'][^\"']{8,}"
        "access[_-]?key\s*=\s*[\"'][^\"']{16,}"
        "token\s*=\s*[\"'][^\"']{8,}"
    )
    
    for pattern in "${secret_patterns[@]}"; do
        local matches=$(grep -r -E -i "$pattern" "$PROJECT_ROOT" \
            --include="*.tf" --include="*.tfvars" --include="*.yaml" --include="*.yml" \
            --include="*.json" --include="*.sh" --include="*.py" \
            --exclude-dir=".git" --exclude-dir=".terraform" 2>/dev/null | wc -l)
        
        if [[ $matches -gt 0 ]]; then
            vulnerabilities=$((vulnerabilities + matches))
            print_warning "Found $matches potential hardcoded secrets"
        fi
    done
    
    if [[ $vulnerabilities -gt 0 ]]; then
        score=$((score - (vulnerabilities * 10)))
        security_issues=$((security_issues + 1))
        add_critical_issue "$vulnerabilities hardcoded secrets detected"
    else
        print_success "No hardcoded secrets detected"
    fi
    
    # Check file permissions
    print_info "Checking sensitive file permissions..."
    local permission_issues=0
    local sensitive_files=$(find "$PROJECT_ROOT" -name "*.tfvars" -o -name "*.pem" -o -name "*.key" 2>/dev/null)
    
    if [[ -n "$sensitive_files" ]]; then
        while IFS= read -r file; do
            if [[ -f "$file" ]]; then
                local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
                if [[ ${perms: -1} -gt 0 ]] || [[ ${perms: -2:1} -gt 0 ]]; then
                    permission_issues=$((permission_issues + 1))
                fi
            fi
        done <<< "$sensitive_files"
        
        if [[ $permission_issues -gt 0 ]]; then
            print_warning "$permission_issues sensitive files have permissive permissions"
            score=$((score - (permission_issues * 5)))
            security_issues=$((security_issues + 1))
            add_recommendation "Restrict permissions on sensitive files (chmod 600)"
        else
            print_success "Sensitive file permissions are secure"
        fi
    fi
    
    # Check for insecure configurations
    print_info "Checking for insecure configurations..."
    local insecure_patterns=(
        "publicly_accessible\s*=\s*true"
        "skip_final_snapshot\s*=\s*true"
        "encryption\s*=\s*false"
        "enforce_ssl\s*=\s*false"
    )
    
    local insecure_configs=0
    for pattern in "${insecure_patterns[@]}"; do
        local matches=$(grep -r -E -i "$pattern" "$PROJECT_ROOT" \
            --include="*.tf" --exclude-dir=".git" --exclude-dir=".terraform" 2>/dev/null | wc -l)
        insecure_configs=$((insecure_configs + matches))
    done
    
    if [[ $insecure_configs -gt 0 ]]; then
        print_warning "$insecure_configs potentially insecure configurations found"
        score=$((score - (insecure_configs * 8)))
        security_issues=$((security_issues + 1))
        add_recommendation "Review and harden insecure configurations"
    else
        print_success "No obviously insecure configurations found"
    fi
    
    # Ensure score doesn't go below 0
    if [[ $score -lt 0 ]]; then
        score=0
    fi
    
    echo "vulnerabilities=$vulnerabilities" >> "$SECURITY_METRICS_FILE"
    echo "security_issues=$security_issues" >> "$SECURITY_METRICS_FILE"
    set_health_metric security_score $score
    
    print_success "Security health assessment complete (Score: $score/100)"
}

# Performance metrics collection
collect_performance_metrics() {
    print_section "Collecting Performance Metrics"
    
    local score=100
    
    # Repository size analysis
    print_info "Analyzing repository size and complexity..."
    local total_size_mb=$(du -sm "$PROJECT_ROOT" 2>/dev/null | cut -f1)
    local tf_file_count=$(find "$PROJECT_ROOT" -name "*.tf" -type f 2>/dev/null | wc -l)
    local resource_count=0
    local module_count=0
    
    # Count Terraform resources and modules
    if [[ $tf_file_count -gt 0 ]]; then
        local tf_files=$(find "$PROJECT_ROOT" -name "*.tf" -type f 2>/dev/null)
        while IFS= read -r file; do
            if [[ -f "$file" ]]; then
                local file_resources=$(grep -c "^resource " "$file" 2>/dev/null || echo "0")
                local file_modules=$(grep -c "^module " "$file" 2>/dev/null || echo "0")
                # Ensure we have valid numbers
                file_resources=${file_resources//[^0-9]/}
                file_modules=${file_modules//[^0-9]/}
                file_resources=${file_resources:-0}
                file_modules=${file_modules:-0}
                resource_count=$((resource_count + file_resources))
                module_count=$((module_count + file_modules))
            fi
        done <<< "$tf_files"
    fi
    
    # Performance scoring
    if [[ $total_size_mb -gt 1000 ]]; then
        score=$((score - 20))
        add_recommendation "Repository size is large (${total_size_mb}MB) - consider cleanup"
    elif [[ $total_size_mb -gt 500 ]]; then
        score=$((score - 10))
        add_recommendation "Repository size is growing (${total_size_mb}MB) - monitor growth"
    fi
    
    if [[ $resource_count -gt 500 ]]; then
        score=$((score - 15))
        add_recommendation "High resource count ($resource_count) - consider modularization"
    elif [[ $resource_count -gt 200 ]]; then
        score=$((score - 5))
    fi
    
    # Check for large files
    local large_files=$(find "$PROJECT_ROOT" -type f -size +10M 2>/dev/null | wc -l)
    if [[ $large_files -gt 0 ]]; then
        score=$((score - (large_files * 5)))
        add_recommendation "$large_files large files (>10MB) found - consider Git LFS"
    fi
    
    # Store performance metrics
    echo "repo_size_mb=$total_size_mb" >> "$PERFORMANCE_METRICS_FILE"
    echo "tf_files=$tf_file_count" >> "$PERFORMANCE_METRICS_FILE"
    echo "resources=$resource_count" >> "$PERFORMANCE_METRICS_FILE"
    echo "modules=$module_count" >> "$PERFORMANCE_METRICS_FILE"
    echo "large_files=$large_files" >> "$PERFORMANCE_METRICS_FILE"
    
    set_health_metric performance_score $score
    
    print_success "Performance metrics collection complete (Score: $score/100)"
}

# Compliance and best practices check
collect_compliance_metrics() {
    print_section "Collecting Compliance and Best Practices Metrics"
    
    local score=100
    local compliance_issues=0
    
    # Check for .gitignore completeness
    print_info "Checking .gitignore completeness..."
    local gitignore_file="$PROJECT_ROOT/.gitignore"
    local required_patterns=(
        "*.tfstate"
        "*.tfstate.*"
        "*.tfvars"
        ".terraform/"
        ".terraform.lock.hcl"
        "*.log"
        ".env"
    )
    
    if [[ -f "$gitignore_file" ]]; then
        local missing_patterns=0
        for pattern in "${required_patterns[@]}"; do
            if ! grep -Fxq "$pattern" "$gitignore_file"; then
                missing_patterns=$((missing_patterns + 1))
            fi
        done
        
        if [[ $missing_patterns -gt 0 ]]; then
            score=$((score - (missing_patterns * 5)))
            compliance_issues=$((compliance_issues + 1))
            add_recommendation "Add $missing_patterns missing patterns to .gitignore"
        else
            print_success ".gitignore contains all recommended patterns"
        fi
    else
        score=$((score - 20))
        compliance_issues=$((compliance_issues + 1))
        add_recommendation "Create .gitignore with Terraform-specific patterns"
    fi
    
    # Check for provider version constraints
    print_info "Checking provider version constraints..."
    local tf_files=$(find "$PROJECT_ROOT" -name "*.tf" -type f 2>/dev/null)
    local unconstrained_providers=0
    
    if [[ -n "$tf_files" ]]; then
        while IFS= read -r file; do
            if grep -E "^\s*provider\s+\"[^\"]+\"\s*{" "$file" > /dev/null 2>&1; then
                local provider_name=$(grep -E "^\s*provider\s+\"[^\"]+\"" "$file" | sed 's/.*"\([^"]*\)".*/\1/')
                if ! grep -A 10 "provider.*\"$provider_name\"" "$file" | grep -E "(version\s*=|required_version)" > /dev/null 2>&1; then
                    unconstrained_providers=$((unconstrained_providers + 1))
                fi
            fi
        done <<< "$tf_files"
        
        if [[ $unconstrained_providers -gt 0 ]]; then
            score=$((score - (unconstrained_providers * 8)))
            compliance_issues=$((compliance_issues + 1))
            add_recommendation "Add version constraints to $unconstrained_providers provider(s)"
        else
            print_success "All providers have version constraints"
        fi
    fi
    
    # Check for README documentation
    print_info "Checking for documentation..."
    local readme_files=$(find "$PROJECT_ROOT" -iname "readme*" -type f | wc -l)
    if [[ $readme_files -eq 0 ]]; then
        score=$((score - 10))
        compliance_issues=$((compliance_issues + 1))
        add_recommendation "Add README documentation for the project"
    fi
    
    echo "compliance_issues=$compliance_issues" >> "$COMPLIANCE_METRICS_FILE"
    set_health_metric compliance_score $score
    
    print_success "Compliance assessment complete (Score: $score/100)"
}

# Dependency health check
check_dependency_health() {
    print_section "Checking Dependency Health"
    
    # Run dependency updater check if available
    if [[ -f "${SCRIPT_DIR}/dependency-updater.sh" ]]; then
        print_info "Running dependency update checks..."
        if command -v zsh > /dev/null; then
            local dep_output
            if dep_output=$(zsh "${SCRIPT_DIR}/dependency-updater.sh" check 2>&1); then
                print_success "Dependency checks completed"
                
                # Parse for outdated dependencies
                local outdated_count=$(echo "$dep_output" | grep -c "outdated" || echo 0)
                if [[ $outdated_count -gt 0 ]]; then
                    add_recommendation "$outdated_count dependencies are outdated - consider updating"
                fi
            else
                print_warning "Dependency checks failed or incomplete"
            fi
        else
            print_warning "zsh not available for dependency updater"
        fi
    else
        print_info "Dependency updater script not found"
    fi
}

# Generate ASCII chart for health scores
generate_ascii_chart() {
    local title="$1"
    local value="$2"
    local max_value="$3"
    
    local bar_length=50
    local filled_length=$((value * bar_length / max_value))
    local empty_length=$((bar_length - filled_length))
    
    printf "%-20s [" "$title"
    printf "%*s" $filled_length | tr ' ' '█'
    printf "%*s" $empty_length | tr ' ' '░'
    printf "] %d/%d\n" "$value" "$max_value"
}

# Generate trend data
update_trend_data() {
    if [[ "$ENABLE_TREND_TRACKING" != true ]]; then
        return
    fi
    
    print_info "Updating trend data..."
    
    local current_data=$(cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "overall_score": $(get_health_metric overall_score),
  "infrastructure_score": $(get_health_metric infrastructure_score),
  "security_score": $(get_health_metric security_score),
  "performance_score": $(get_health_metric performance_score),
  "compliance_score": $(get_health_metric compliance_score),
  "total_issues": $(($(get_health_metric infrastructure_issues) + $(get_security_metric security_issues) + $(get_compliance_metric compliance_issues))),
  "critical_issues": $(count_critical_issues),
  "recommendations": $(count_recommendations)
}
EOF
)
    
    # Append to trends file
    if [[ -f "$TRENDS_DATA" ]]; then
        # Read existing data and append new entry
        local existing_data=$(cat "$TRENDS_DATA" 2>/dev/null || echo "[]")
        echo "$existing_data" | jq ". += [$current_data]" > "$TRENDS_DATA" 2>/dev/null || {
            # Fallback if jq is not available
            echo "[$current_data]" > "$TRENDS_DATA"
        }
    else
        echo "[$current_data]" > "$TRENDS_DATA"
    fi
}

# Generate markdown report
generate_markdown_report() {
    print_info "Generating comprehensive markdown report..."
    
    cat > "$MARKDOWN_REPORT" << EOF
# Infrastructure Health Report

**Generated:** $DATE_HUMAN  
**Project:** $(basename "$PROJECT_ROOT")  
**Overall Health Score:** $(get_health_metric overall_score)/100 ($(get_health_metric health_status))

---

## Executive Summary

### Health Status: $(get_health_metric health_status) 🔥
- **Overall Score:** $(get_health_metric overall_score)/100
- **Critical Issues:** $(count_critical_issues)
- **Total Recommendations:** $(count_recommendations)
- **Assessment Date:** $DATE_HUMAN

### Key Metrics Dashboard

\`\`\`
$(generate_ascii_chart "Infrastructure" "$(get_health_metric infrastructure_score)" "100")
$(generate_ascii_chart "Security" "$(get_health_metric security_score)" "100")  
$(generate_ascii_chart "Performance" "$(get_health_metric performance_score)" "100")
$(generate_ascii_chart "Compliance" "$(get_health_metric compliance_score)" "100")
\`\`\`

---

## Detailed Health Assessment

### 🏗️ Infrastructure Health
- **Score:** $(get_health_metric infrastructure_score)/100
- **Issues Found:** $(get_health_metric infrastructure_issues)
- **Status:** $([ $(get_health_metric infrastructure_score) -ge 80 ] && echo "✅ Healthy" || echo "⚠️ Needs Attention")

### 🔒 Security Health  
- **Score:** $(get_health_metric security_score)/100
- **Vulnerabilities:** $(get_security_metric vulnerabilities)
- **Security Issues:** $(get_security_metric security_issues)
- **Status:** $([ $(get_health_metric security_score) -ge 80 ] && echo "✅ Secure" || echo "🚨 Security Concerns")

### 🚀 Performance Metrics
- **Score:** $(get_health_metric performance_score)/100
- **Repository Size:** $(get_performance_metric repo_size_mb)MB
- **Terraform Files:** $(get_performance_metric tf_files)
- **Resources:** $(get_performance_metric resources)
- **Modules:** $(get_performance_metric modules)
- **Large Files:** $(get_performance_metric large_files)

### 📋 Compliance & Best Practices
- **Score:** $(get_health_metric compliance_score)/100
- **Compliance Issues:** $(get_compliance_metric compliance_issues)
- **Status:** $([ $(get_health_metric compliance_score) -ge 80 ] && echo "✅ Compliant" || echo "⚠️ Non-Compliant")

---

## 🚨 Critical Issues
$(if [[ $(count_critical_issues) -eq 0 ]]; then
    echo "No critical issues found! 🎉"
else
    while IFS= read -r issue; do
        echo "- ❌ $issue"
    done < "$CRITICAL_ISSUES_FILE"
fi)

---

## 💡 Recommendations
$(if [[ $(count_recommendations) -eq 0 ]]; then
    echo "No recommendations at this time. Great job! 👏"
else
    while IFS= read -r rec; do
        echo "- 🔧 $rec"
    done < "$RECOMMENDATIONS_FILE"
fi)

---

## 📊 Historical Trends
$(if [[ -f "$TRENDS_DATA" ]] && command -v jq > /dev/null; then
    echo "### Recent Health Scores"
    echo ""
    echo "| Date | Overall | Infrastructure | Security | Performance | Compliance |"
    echo "|------|---------|----------------|----------|-------------|------------|"
    tail -n 5 "$TRENDS_DATA" | jq -r '.[].timestamp + " | " + (.[].overall_score|tostring) + " | " + (.[].infrastructure_score|tostring) + " | " + (.[].security_score|tostring) + " | " + (.[].performance_score|tostring) + " | " + (.[].compliance_score|tostring)' 2>/dev/null || echo "Trend data unavailable"
else
    echo "Historical trend tracking will be available after multiple runs."
fi)

---

## Next Steps

### Immediate Actions Required
$(if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then
    echo "🚨 **URGENT:** Health score is below critical threshold"
    echo "1. Address all critical issues immediately"
    echo "2. Review security vulnerabilities"
    echo "3. Schedule emergency maintenance"
elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then
    echo "⚠️ **ATTENTION:** Health score needs improvement"
    echo "1. Prioritize high-impact recommendations"
    echo "2. Schedule maintenance window"
    echo "3. Review compliance issues"
else
    echo "✅ **GOOD:** Infrastructure is healthy"
    echo "1. Continue regular monitoring"
    echo "2. Address minor recommendations when convenient"
    echo "3. Maintain current practices"
fi)

### Recommended Maintenance Schedule
- **Daily:** Monitor critical alerts and logs
- **Weekly:** Review health reports and trends
- **Monthly:** Update dependencies and security patches
- **Quarterly:** Comprehensive infrastructure review

---

*Report generated by Infrastructure Health Reporter v1.0*  
*For questions or issues, contact your DevOps team*
EOF

    print_success "Markdown report generated: $MARKDOWN_REPORT"
}

# Generate JSON report
generate_json_report() {
    print_info "Generating JSON report..."
    
    local critical_issues_json=$(printf '%s\n' "${CRITICAL_ISSUES[@]}" | jq -R . | jq -s .)
    local recommendations_json=$(printf '%s\n' "${RECOMMENDATIONS[@]}" | jq -R . | jq -s .)
    
    cat > "$JSON_REPORT" << EOF
{
  "report_metadata": {
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "generator": "Infrastructure Health Reporter v1.0",
    "project_root": "$PROJECT_ROOT",
    "project_name": "$(basename "$PROJECT_ROOT")"
  },
  "health_summary": {
    "overall_score": $(get_health_metric overall_score),
    "health_status": "$(get_health_metric health_status)",
    "health_color": "$(get_health_metric health_color)",
    "critical_issues_count": $(count_critical_issues),
    "recommendations_count": $(count_recommendations)
  },
  "detailed_scores": {
    "infrastructure": {
      "score": $(get_health_metric infrastructure_score),
      "issues": $(get_health_metric infrastructure_issues),
      "status": "$([ $(get_health_metric infrastructure_score) -ge 80 ] && echo "healthy" || echo "needs_attention")"
    },
    "security": {
      "score": $(get_health_metric security_score),
      "vulnerabilities": $(get_security_metric vulnerabilities),
      "issues": $(get_security_metric security_issues),
      "status": "$([ $(get_health_metric security_score) -ge 80 ] && echo "secure" || echo "vulnerable")"
    },
    "performance": {
      "score": $(get_health_metric performance_score),
      "repo_size_mb": $(get_performance_metric repo_size_mb),
      "terraform_files": $(get_performance_metric tf_files),
      "resources": $(get_performance_metric resources),
      "modules": $(get_performance_metric modules),
      "large_files": $(get_performance_metric large_files)
    },
    "compliance": {
      "score": $(get_health_metric compliance_score),
      "issues": $(get_compliance_metric compliance_issues),
      "status": "$([ $(get_health_metric compliance_score) -ge 80 ] && echo "compliant" || echo "non_compliant")"
    }
  },
  "critical_issues": $critical_issues_json,
  "recommendations": $recommendations_json
}
EOF

    print_success "JSON report generated: $JSON_REPORT"
}

# Generate CSV report
generate_csv_report() {
    print_info "Generating CSV report..."
    
    cat > "$CSV_REPORT" << EOF
Timestamp,Overall_Score,Infrastructure_Score,Security_Score,Performance_Score,Compliance_Score,Critical_Issues,Recommendations,Health_Status
$(date -u +%Y-%m-%dT%H:%M:%SZ),$(get_health_metric overall_score),$(get_health_metric infrastructure_score),$(get_health_metric security_score),$(get_health_metric performance_score),$(get_health_metric compliance_score),$(count_critical_issues),$(count_recommendations),$(get_health_metric health_status)
EOF

    print_success "CSV report generated: $CSV_REPORT"
}

# Generate HTML report
generate_html_report() {
    print_info "Generating HTML report..."
    
    cat > "$HTML_REPORT" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Infrastructure Health Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem;
            border-radius: 10px;
            margin-bottom: 2rem;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5rem;
        }
        .header p {
            margin: 0.5rem 0 0 0;
            opacity: 0.9;
        }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        .metric-card {
            background: white;
            padding: 1.5rem;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
        }
        .metric-score {
            font-size: 3rem;
            font-weight: bold;
            margin: 0.5rem 0;
        }
        .score-excellent { color: #28a745; }
        .score-good { color: #ffc107; }
        .score-fair { color: #fd7e14; }
        .score-critical { color: #dc3545; }
        .section {
            background: white;
            margin-bottom: 2rem;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .section-header {
            background: #f8f9fa;
            padding: 1rem 1.5rem;
            border-bottom: 1px solid #dee2e6;
            font-weight: bold;
            font-size: 1.2rem;
        }
        .section-content {
            padding: 1.5rem;
        }
        .chart-container {
            position: relative;
            height: 400px;
            margin: 1rem 0;
        }
        .alert {
            padding: 1rem;
            margin: 1rem 0;
            border-radius: 5px;
            border-left: 4px solid;
        }
        .alert-critical {
            background: #f8d7da;
            border-color: #dc3545;
            color: #721c24;
        }
        .alert-warning {
            background: #fff3cd;
            border-color: #ffc107;
            color: #856404;
        }
        .alert-success {
            background: #d4edda;
            border-color: #28a745;
            color: #155724;
        }
        .recommendations {
            list-style: none;
            padding: 0;
        }
        .recommendations li {
            padding: 0.5rem 0;
            border-bottom: 1px solid #eee;
        }
        .recommendations li:before {
            content: "💡 ";
            margin-right: 0.5rem;
        }
        .footer {
            text-align: center;
            margin-top: 3rem;
            padding: 2rem;
            color: #666;
            border-top: 1px solid #eee;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏗️ Infrastructure Health Report</h1>
        <p>Generated on DATE_HUMAN</p>
        <p>Project: PROJECT_NAME</p>
    </div>

    <div class="dashboard">
        <div class="metric-card">
            <h3>Overall Health</h3>
            <div class="metric-score OVERALL_SCORE_CLASS">OVERALL_SCORE/100</div>
            <p>HEALTH_STATUS</p>
        </div>
        <div class="metric-card">
            <h3>Infrastructure</h3>
            <div class="metric-score INFRA_SCORE_CLASS">INFRASTRUCTURE_SCORE/100</div>
            <p>INFRASTRUCTURE_ISSUES issues</p>
        </div>
        <div class="metric-card">
            <h3>Security</h3>
            <div class="metric-score SECURITY_SCORE_CLASS">SECURITY_SCORE/100</div>
            <p>VULNERABILITIES vulnerabilities</p>
        </div>
        <div class="metric-card">
            <h3>Performance</h3>
            <div class="metric-score PERF_SCORE_CLASS">PERFORMANCE_SCORE/100</div>
            <p>REPO_SIZE_MB MB repository</p>
        </div>
    </div>

    <div class="section">
        <div class="section-header">📊 Health Metrics Visualization</div>
        <div class="section-content">
            <div class="chart-container">
                <canvas id="healthChart"></canvas>
            </div>
        </div>
    </div>

    <div class="section">
        <div class="section-header">🚨 Critical Issues</div>
        <div class="section-content">
            CRITICAL_ISSUES_HTML
        </div>
    </div>

    <div class="section">
        <div class="section-header">💡 Recommendations</div>
        <div class="section-content">
            RECOMMENDATIONS_HTML
        </div>
    </div>

    <div class="footer">
        <p>Report generated by Infrastructure Health Reporter v1.0</p>
        <p>For questions or issues, contact your DevOps team</p>
    </div>

    <script>
        // Health metrics chart
        const ctx = document.getElementById('healthChart').getContext('2d');
        new Chart(ctx, {
            type: 'radar',
            data: {
                labels: ['Infrastructure', 'Security', 'Performance', 'Compliance'],
                datasets: [{
                    label: 'Health Scores',
                    data: [INFRASTRUCTURE_SCORE, SECURITY_SCORE, PERFORMANCE_SCORE, COMPLIANCE_SCORE],
                    backgroundColor: 'rgba(102, 126, 234, 0.2)',
                    borderColor: 'rgba(102, 126, 234, 1)',
                    borderWidth: 2,
                    pointBackgroundColor: 'rgba(102, 126, 234, 1)',
                    pointBorderColor: '#fff',
                    pointHoverBackgroundColor: '#fff',
                    pointHoverBorderColor: 'rgba(102, 126, 234, 1)'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scale: {
                    ticks: {
                        beginAtZero: true,
                        max: 100,
                        stepSize: 20
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    }
                }
            }
        });
    </script>
</body>
</html>
EOF

    # Replace placeholders with actual values
    local overall_score_class="score-excellent"
    if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then
        overall_score_class="score-critical"
    elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then
        overall_score_class="score-fair"
    elif [[ $(get_health_metric overall_score) -lt 90 ]]; then
        overall_score_class="score-good"
    fi
    
    # Generate critical issues HTML
    local critical_issues_html=""
    if [[ $(count_critical_issues) -eq 0 ]]; then
        critical_issues_html='<div class="alert alert-success">No critical issues found! 🎉</div>'
    else
        critical_issues_html='<div class="alert alert-critical">'
        while IFS= read -r issue; do
            critical_issues_html+="<p>❌ $issue</p>"
        done < "$CRITICAL_ISSUES_FILE"
        critical_issues_html+='</div>'
    fi
    
    # Generate recommendations HTML
    local recommendations_html=""
    if [[ $(count_recommendations) -eq 0 ]]; then
        recommendations_html='<div class="alert alert-success">No recommendations at this time. Great job! 👏</div>'
    else
        recommendations_html='<ul class="recommendations">'
        while IFS= read -r rec; do
            recommendations_html+="<li>$rec</li>"
        done < "$RECOMMENDATIONS_FILE"
        recommendations_html+='</ul>'
    fi
    
    # Replace all placeholders
    sed -i.bak \
        -e "s/DATE_HUMAN/$DATE_HUMAN/g" \
        -e "s/PROJECT_NAME/$(basename "$PROJECT_ROOT")/g" \
        -e "s/OVERALL_SCORE_CLASS/$overall_score_class/g" \
        -e "s/OVERALL_SCORE/$(get_health_metric overall_score)/g" \
        -e "s/HEALTH_STATUS/$(get_health_metric health_status)/g" \
        -e "s/INFRA_SCORE_CLASS/$overall_score_class/g" \
        -e "s/INFRASTRUCTURE_SCORE/$(get_health_metric infrastructure_score)/g" \
        -e "s/INFRASTRUCTURE_ISSUES/$(get_health_metric infrastructure_issues)/g" \
        -e "s/SECURITY_SCORE_CLASS/$overall_score_class/g" \
        -e "s/SECURITY_SCORE/$(get_health_metric security_score)/g" \
        -e "s/VULNERABILITIES/$(get_security_metric vulnerabilities)/g" \
        -e "s/PERF_SCORE_CLASS/$overall_score_class/g" \
        -e "s/PERFORMANCE_SCORE/$(get_health_metric performance_score)/g" \
        -e "s/COMPLIANCE_SCORE/$(get_health_metric compliance_score)/g" \
        -e "s/REPO_SIZE_MB/$(get_performance_metric repo_size_mb)/g" \
        "$HTML_REPORT"
    
    # Replace complex HTML sections
    sed -i.bak "s|CRITICAL_ISSUES_HTML|$critical_issues_html|g" "$HTML_REPORT"
    sed -i.bak "s|RECOMMENDATIONS_HTML|$recommendations_html|g" "$HTML_REPORT"
    
    # Clean up backup file
    rm -f "${HTML_REPORT}.bak"
    
    print_success "HTML report generated: $HTML_REPORT"
}

# Generate executive summary
generate_executive_summary() {
    print_info "Generating executive summary..."
    
    cat > "$EXECUTIVE_SUMMARY" << EOF
# Executive Summary - Infrastructure Health Report

**Date:** $DATE_HUMAN  
**Project:** $(basename "$PROJECT_ROOT")

## Key Findings

### Overall Health: $(get_health_metric health_status) ($(get_health_metric overall_score)/100)

$(if [[ $(get_health_metric overall_score) -ge 90 ]]; then
    echo "✅ **EXCELLENT** - Infrastructure is operating at optimal levels"
elif [[ $(get_health_metric overall_score) -ge $HEALTH_THRESHOLD_WARNING ]]; then
    echo "✅ **GOOD** - Infrastructure is healthy with minor areas for improvement"
elif [[ $(get_health_metric overall_score) -ge $HEALTH_THRESHOLD_CRITICAL ]]; then
    echo "⚠️ **FAIR** - Infrastructure needs attention to prevent issues"
else
    echo "🚨 **CRITICAL** - Immediate action required to address infrastructure issues"
fi)

## Executive Dashboard

| Metric | Score | Status | Priority |
|--------|-------|--------|----------|
| Infrastructure | $(get_health_metric infrastructure_score)/100 | $([ $(get_health_metric infrastructure_score) -ge 80 ] && echo "✅ Healthy" || echo "⚠️ Needs Attention") | $([ $(get_health_metric infrastructure_score) -lt 70 ] && echo "HIGH" || echo "MEDIUM") |
| Security | $(get_health_metric security_score)/100 | $([ $(get_health_metric security_score) -ge 80 ] && echo "✅ Secure" || echo "🚨 At Risk") | $([ $(get_health_metric security_score) -lt 70 ] && echo "CRITICAL" || echo "MEDIUM") |
| Performance | $(get_health_metric performance_score)/100 | $([ $(get_health_metric performance_score) -ge 80 ] && echo "✅ Optimal" || echo "⚠️ Needs Optimization") | LOW |
| Compliance | $(get_health_metric compliance_score)/100 | $([ $(get_health_metric compliance_score) -ge 80 ] && echo "✅ Compliant" || echo "⚠️ Non-Compliant") | MEDIUM |

## Immediate Actions Required

$(if [[ $(count_critical_issues) -gt 0 ]]; then
    echo "### 🚨 Critical Issues ($(count_critical_issues))"
    while IFS= read -r issue; do
        echo "- $issue"
    done < "$CRITICAL_ISSUES_FILE"
    echo ""
else
    echo "### ✅ No Critical Issues"
    echo "No immediate critical actions required."
    echo ""
fi)

## Top Recommendations

$(if [[ $(count_recommendations) -gt 0 ]]; then
    echo "### Priority Actions (Top 5)"
    local count=0
    while IFS= read -r rec; do
        if [[ $count -lt 5 ]]; then
            echo "$((count + 1)). $rec"
            count=$((count + 1))
        fi
    done < "$RECOMMENDATIONS_FILE"
else
    echo "### ✅ No Recommendations"
    echo "Infrastructure is well-maintained. Continue current practices."
fi)

## Business Impact Assessment

### Risk Level: $(if [[ $(get_health_metric overall_score) -ge 80 ]]; then echo "🟢 LOW"; elif [[ $(get_health_metric overall_score) -ge 60 ]]; then echo "🟡 MEDIUM"; else echo "🔴 HIGH"; fi)

$(if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then
    echo "**HIGH RISK:** Infrastructure health below acceptable thresholds"
    echo "- Potential for service disruptions"
    echo "- Security vulnerabilities may exist"
    echo "- Performance degradation likely"
    echo "- Compliance violations possible"
elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then
    echo "**MEDIUM RISK:** Infrastructure requires attention"
    echo "- Minor service impacts possible"
    echo "- Preventive maintenance recommended"
    echo "- Monitor trends closely"
else
    echo "**LOW RISK:** Infrastructure is healthy"
    echo "- Services operating normally"
    echo "- Continue regular monitoring"
    echo "- Proactive maintenance effective"
fi)

## Resource Requirements

### Estimated Effort to Address Issues:
- **Critical Issues:** $(if [[ $(count_critical_issues) -gt 0 ]]; then echo "$(($(count_critical_issues) * 4)) hours"; else echo "0 hours"; fi)
- **High Priority Recommendations:** $(if [[ $(count_recommendations) -gt 3 ]]; then echo "8-16 hours"; else echo "4-8 hours"; fi)
- **Total Estimated Effort:** $(echo $(($(count_critical_issues) * 4 + $(count_recommendations) * 2))) hours

### Budget Impact:
$(if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then
    echo "- Emergency maintenance budget required"
    echo "- Potential downtime costs to consider"
    echo "- Security incident response costs"
elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then
    echo "- Planned maintenance within normal budget"
    echo "- Minimal operational impact expected"
else
    echo "- Maintenance within planned budget"
    echo "- No additional costs anticipated"
fi)

## Next Review

**Recommended Review Frequency:** $(if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then echo "Daily until issues resolved"; elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then echo "Weekly"; else echo "Monthly"; fi)

**Next Scheduled Review:** $(date -d "+$(if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then echo "1 day"; elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then echo "1 week"; else echo "1 month"; fi)" '+%B %d, %Y')

---

*This summary is intended for executive and management review. For technical details, see the full health report.*
EOF

    print_success "Executive summary generated: $EXECUTIVE_SUMMARY"
}

# Send Slack notification
send_slack_notification() {
    if [[ "$ENABLE_SLACK_NOTIFICATIONS" != true ]] || [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        return
    fi
    
    print_info "Sending Slack notification..."
    
    local color="good"
    local emoji="✅"
    local urgency="Normal"
    
    if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then
        color="danger"
        emoji="🚨"
        urgency="CRITICAL"
    elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then
        color="warning"
        emoji="⚠️"
        urgency="Warning"
    fi
    
    local payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "$emoji Infrastructure Health Report - $urgency",
            "title_link": "file://$HTML_REPORT",
            "fields": [
                {
                    "title": "Overall Health Score",
                    "value": "$(get_health_metric overall_score)/100 ($(get_health_metric health_status))",
                    "short": true
                },
                {
                    "title": "Critical Issues",
                    "value": "$(count_critical_issues)",
                    "short": true
                },
                {
                    "title": "Project",
                    "value": "$(basename "$PROJECT_ROOT")",
                    "short": true
                },
                {
                    "title": "Generated",
                    "value": "$DATE_HUMAN",
                    "short": true
                }
            ],
            "footer": "Infrastructure Health Reporter"
        }
    ]
}
EOF
)
    
    if curl -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL" > /dev/null 2>&1; then
        print_success "Slack notification sent successfully"
    else
        print_warning "Failed to send Slack notification"
    fi
}

# Send email notification
send_email_notification() {
    if [[ "$ENABLE_EMAIL_NOTIFICATIONS" != true ]] || [[ -z "$EMAIL_RECIPIENTS" ]]; then
        return
    fi
    
    print_info "Sending email notification..."
    
    local subject="Infrastructure Health Report - $(get_health_metric health_status) ($(get_health_metric overall_score)/100)"
    local urgency_prefix=""
    
    if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then
        urgency_prefix="[CRITICAL] "
    elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then
        urgency_prefix="[WARNING] "
    fi
    
    subject="$urgency_prefix$subject"
    
    # Create email body
    local email_body=$(cat << EOF
Infrastructure Health Report Summary

Project: $(basename "$PROJECT_ROOT")
Generated: $DATE_HUMAN
Overall Health Score: $(get_health_metric overall_score)/100 ($(get_health_metric health_status))

Quick Summary:
- Infrastructure: $(get_health_metric infrastructure_score)/100
- Security: $(get_health_metric security_score)/100
- Performance: $(get_health_metric performance_score)/100
- Compliance: $(get_health_metric compliance_score)/100

Critical Issues: $(count_critical_issues)
Recommendations: $(count_recommendations)

For detailed report, see attached files or visit:
- Markdown Report: $MARKDOWN_REPORT
- HTML Report: $HTML_REPORT
- Executive Summary: $EXECUTIVE_SUMMARY

This is an automated message from Infrastructure Health Reporter.
EOF
)
    
    # Try to send email using available mail command
    if command -v mail > /dev/null; then
        echo "$email_body" | mail -s "$subject" "$EMAIL_RECIPIENTS" && \
            print_success "Email notification sent successfully" || \
            print_warning "Failed to send email notification"
    elif command -v sendmail > /dev/null; then
        (
            echo "To: $EMAIL_RECIPIENTS"
            echo "Subject: $subject"
            echo ""
            echo "$email_body"
        ) | sendmail "$EMAIL_RECIPIENTS" && \
            print_success "Email notification sent successfully" || \
            print_warning "Failed to send email notification"
    else
        print_warning "No mail command available for email notifications"
    fi
}

# Show help
show_help() {
    cat << EOF
Infrastructure Health Reporter v1.0

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --no-slack              Disable Slack notifications
    --no-email              Disable email notifications
    --no-charts             Disable chart generation
    --no-trends             Disable trend tracking
    --slack-webhook URL     Set Slack webhook URL
    --email-recipients LIST Set email recipients (comma-separated)
    --critical-threshold N  Set critical health threshold (default: 60)
    --warning-threshold N   Set warning health threshold (default: 80)
    --output-dir DIR        Set custom output directory
    --quiet                 Suppress progress output
    --help                  Show this help message

EXAMPLES:
    $0                                          # Generate all reports with defaults
    $0 --no-slack --no-email                   # Generate reports without notifications
    $0 --slack-webhook "https://hooks.slack.com/..."  # Custom Slack webhook
    $0 --critical-threshold 50 --warning-threshold 75 # Custom thresholds
    $0 --output-dir /custom/reports            # Custom output directory

ENVIRONMENT VARIABLES:
    SLACK_WEBHOOK_URL       Slack webhook URL for notifications
    EMAIL_RECIPIENTS        Email recipients for notifications

OUTPUT FILES:
    - Markdown Report:      $MARKDOWN_REPORT
    - JSON Report:          $JSON_REPORT
    - CSV Report:           $CSV_REPORT
    - HTML Report:          $HTML_REPORT
    - Executive Summary:    $EXECUTIVE_SUMMARY
    - Trends Data:          $TRENDS_DATA
    - Log File:             $HEALTH_LOG

For more information, visit: https://github.com/your-org/infrastructure-tools
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-slack)
                ENABLE_SLACK_NOTIFICATIONS=false
                shift
                ;;
            --no-email)
                ENABLE_EMAIL_NOTIFICATIONS=false
                shift
                ;;
            --no-charts)
                ENABLE_CHARTS=false
                shift
                ;;
            --no-trends)
                ENABLE_TREND_TRACKING=false
                shift
                ;;
            --slack-webhook)
                SLACK_WEBHOOK_URL="$2"
                shift 2
                ;;
            --email-recipients)
                EMAIL_RECIPIENTS="$2"
                shift 2
                ;;
            --critical-threshold)
                HEALTH_THRESHOLD_CRITICAL="$2"
                shift 2
                ;;
            --warning-threshold)
                HEALTH_THRESHOLD_WARNING="$2"
                shift 2
                ;;
            --output-dir)
                REPORTS_DIR="$2"
                mkdir -p "$REPORTS_DIR"
                shift 2
                ;;
            --quiet)
                exec > /dev/null 2>&1
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main execution function
main() {
    print_header "Infrastructure Health Reporter v1.0"
    print_info "Starting comprehensive health assessment..."
    
    # Initialize environment
    init_environment
    
    local total_steps=12
    local current_step=0
    
    # Step 1: Infrastructure Health
    progress_bar $current_step $total_steps
    collect_infrastructure_health
    current_step=$((current_step + 1))
    
    # Step 2: Security Health
    progress_bar $current_step $total_steps
    collect_security_health
    current_step=$((current_step + 1))
    
    # Step 3: Performance Metrics
    progress_bar $current_step $total_steps
    collect_performance_metrics
    current_step=$((current_step + 1))
    
    # Step 4: Compliance Metrics
    progress_bar $current_step $total_steps
    collect_compliance_metrics
    current_step=$((current_step + 1))
    
    # Step 5: Dependency Health
    progress_bar $current_step $total_steps
    check_dependency_health
    current_step=$((current_step + 1))
    
    # Step 6: Calculate Overall Score
    progress_bar $current_step $total_steps
    calculate_health_score
    current_step=$((current_step + 1))
    
    # Step 7: Update Trends
    progress_bar $current_step $total_steps
    update_trend_data
    current_step=$((current_step + 1))
    
    # Step 8: Generate Markdown Report
    progress_bar $current_step $total_steps
    generate_markdown_report
    current_step=$((current_step + 1))
    
    # Step 9: Generate JSON Report
    progress_bar $current_step $total_steps
    generate_json_report
    current_step=$((current_step + 1))
    
    # Step 10: Generate CSV Report
    progress_bar $current_step $total_steps
    generate_csv_report
    current_step=$((current_step + 1))
    
    # Step 11: Generate HTML Report
    if [[ "$ENABLE_CHARTS" == true ]]; then
        progress_bar $current_step $total_steps
        generate_html_report
    fi
    current_step=$((current_step + 1))
    
    # Step 12: Generate Executive Summary
    progress_bar $current_step $total_steps
    generate_executive_summary
    current_step=$((current_step + 1))
    
    echo -e "\n"
    
    # Send notifications
    send_slack_notification
    send_email_notification
    
    # Final summary
    print_header "Health Assessment Complete"
    
    echo -e "${WHITE}Overall Health Score: $(get_health_metric overall_score)/100 ($(get_health_metric health_status))${NC}"
    echo -e "${WHITE}Critical Issues: ${NC}$(count_critical_issues)"
    echo -e "${WHITE}Recommendations: ${NC}$(count_recommendations)"
    
    echo -e "\n${CYAN}Generated Reports:${NC}"
    echo -e "  📄 Markdown:    $MARKDOWN_REPORT"
    echo -e "  📊 JSON:        $JSON_REPORT"
    echo -e "  📈 CSV:         $CSV_REPORT"
    echo -e "  🌐 HTML:        $HTML_REPORT"
    echo -e "  📋 Executive:   $EXECUTIVE_SUMMARY"
    echo -e "  📝 Log:         $HEALTH_LOG"
    
    if [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_CRITICAL ]]; then
        echo -e "\n${RED}${BOLD}⚠️  CRITICAL: Immediate attention required!${NC}"
        return 2
    elif [[ $(get_health_metric overall_score) -lt $HEALTH_THRESHOLD_WARNING ]]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  WARNING: Infrastructure needs attention${NC}"
        return 1
    else
        echo -e "\n${GREEN}${BOLD}✅ Infrastructure is healthy${NC}"
        return 0
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    parse_arguments "$@"
    
    # Run main function
    main
    exit $?
fi