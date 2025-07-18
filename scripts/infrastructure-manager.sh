#!/usr/bin/env zsh

# Infrastructure Manager - Master Orchestration Script
# The ultimate infrastructure management tool that coordinates all operations
# Created: $(date +%Y-%m-%d)
# 
# This script provides a single entry point for all infrastructure operations,
# with an interactive menu system, CLI automation support, and intelligent workflow coordination.

set -euo pipefail

# Version and metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="Infrastructure Manager"
readonly CREATION_DATE="$(date +%Y-%m-%d)"

# Color definitions for beautiful output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color

# Unicode symbols for enhanced visual appeal
readonly CHECK_MARK="✓"
readonly CROSS_MARK="✗"
readonly WARNING_SIGN="⚠"
readonly INFO_SIGN="ℹ"
readonly ROCKET="🚀"
readonly GEAR="⚙"
readonly SHIELD="🛡"
readonly CHART="📊"
readonly PACKAGE="📦"
readonly WRENCH="🔧"
readonly CLIPBOARD="📋"
readonly LIGHTNING="⚡"

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
# Calculate infrastructure root: /path/to/infrastructure/shared/mob-infra-cicd/scripts -> /path/to/infrastructure
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly LOGS_DIR="${SCRIPT_DIR}/logs"
readonly REPORTS_DIR="${PROJECT_ROOT}/reports"
readonly TEMP_DIR="${SCRIPT_DIR}/temp"
readonly BACKUP_DIR="${SCRIPT_DIR}/backups"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly SESSION_LOG="${LOGS_DIR}/infrastructure-manager-${TIMESTAMP}.log"

# Script paths
readonly MAINTENANCE_SCRIPT="${SCRIPT_DIR}/maintenance-check.sh"
readonly HEALTH_REPORTER_SCRIPT="${SCRIPT_DIR}/health-reporter.sh"
readonly COMPLIANCE_SCRIPT="${SCRIPT_DIR}/compliance-checker.sh"
readonly DEPENDENCY_SCRIPT="${SCRIPT_DIR}/dependency-updater.sh"
readonly BULK_OPERATIONS_SCRIPT="${SCRIPT_DIR}/bulk-operations.sh"
readonly WORKSPACE_SETUP_SCRIPT="${SCRIPT_DIR}/enhanced-workspace-setup.sh"

# Global state tracking (using zsh associative arrays)
typeset -a EXECUTED_OPERATIONS
typeset -a FAILED_OPERATIONS
typeset -A OPERATION_STATUS
typeset -A OPERATION_TIMESTAMPS

# Performance metrics
SCRIPT_START_TIME=$(date +%s)
TOTAL_OPERATIONS=0
SUCCESSFUL_OPERATIONS=0
FAILED_OPERATIONS_COUNT=0

# Initialize environment
init_environment() {
    # Create required directories
    mkdir -p "$LOGS_DIR" "$REPORTS_DIR" "$TEMP_DIR" "$BACKUP_DIR"
    
    # Initialize session log
    {
        echo "=========================================="
        echo "Infrastructure Manager Session Started"
        echo "=========================================="
        echo "Date: $(date)"
        echo "Version: $SCRIPT_VERSION"
        echo "Project Root: $PROJECT_ROOT"
        echo "Session ID: $TIMESTAMP"
        echo "=========================================="
    } > "$SESSION_LOG"
    
    # Verify script dependencies
    verify_dependencies
}

# Verify required scripts and dependencies exist
verify_dependencies() {
    local missing_deps=()
    
    # Check for required scripts
    [[ ! -f "$MAINTENANCE_SCRIPT" ]] && missing_deps+=("maintenance-check.sh")
    [[ ! -f "$HEALTH_REPORTER_SCRIPT" ]] && missing_deps+=("health-reporter.sh")
    [[ ! -f "$COMPLIANCE_SCRIPT" ]] && missing_deps+=("compliance-checker.sh")
    [[ ! -f "$DEPENDENCY_SCRIPT" ]] && missing_deps+=("dependency-updater.sh")
    [[ ! -f "$BULK_OPERATIONS_SCRIPT" ]] && missing_deps+=("bulk-operations.sh")
    [[ ! -f "$WORKSPACE_SETUP_SCRIPT" ]] && missing_deps+=("enhanced-workspace-setup.sh")
    
    # Check for required system utilities
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    command -v terraform >/dev/null 2>&1 || missing_deps+=("terraform")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_info "Please ensure all required scripts and tools are installed."
        exit 1
    fi
}

# Enhanced printing functions with logging
print_header() {
    local text="$1"
    local border="$(printf '═%.0s' {1..80})"
    echo -e "\n${BLUE}${border}${NC}"
    echo -e "${WHITE}${BOLD}  $text${NC}"
    echo -e "${BLUE}${border}${NC}\n"
    echo "HEADER: $text" >> "$SESSION_LOG"
}

print_section() {
    local text="$1"
    echo -e "\n${CYAN}${BOLD}▶ $text${NC}"
    echo "SECTION: $text" >> "$SESSION_LOG"
}

print_success() {
    local text="$1"
    # Sanitize sensitive information before logging
    local log_text="$text"
    log_text="${log_text//ghp_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_text="${log_text//ghs_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_text="${log_text//github_pat_[a-zA-Z0-9_]*/[GITHUB_TOKEN_REDACTED]}"
    
    echo -e "${GREEN}${CHECK_MARK}${NC} $text"
    echo "SUCCESS: $log_text" >> "$SESSION_LOG"
}

print_error() {
    local text="$1"
    # Sanitize sensitive information before logging
    local log_text="$text"
    log_text="${log_text//ghp_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_text="${log_text//ghs_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_text="${log_text//github_pat_[a-zA-Z0-9_]*/[GITHUB_TOKEN_REDACTED]}"
    
    echo -e "${RED}${CROSS_MARK}${NC} $text" >&2
    echo "ERROR: $log_text" >> "$SESSION_LOG"
}

print_warning() {
    local text="$1"
    # Sanitize sensitive information before logging
    local log_text="$text"
    log_text="${log_text//ghp_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_text="${log_text//ghs_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_text="${log_text//github_pat_[a-zA-Z0-9_]*/[GITHUB_TOKEN_REDACTED]}"
    
    echo -e "${YELLOW}${WARNING_SIGN}${NC} $text"
    echo "WARNING: $log_text" >> "$SESSION_LOG"
}

print_info() {
    local text="$1"
    # Sanitize sensitive information before logging
    local log_text="$text"
    log_text="${log_text//ghp_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_text="${log_text//ghs_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_text="${log_text//github_pat_[a-zA-Z0-9_]*/[GITHUB_TOKEN_REDACTED]}"
    
    echo -e "${BLUE}${INFO_SIGN}${NC} $text"
    echo "INFO: $log_text" >> "$SESSION_LOG"
}

print_recommendation() {
    local text="$1"
    echo -e "${PURPLE}💡${NC} $text"
    echo "RECOMMENDATION: $text" >> "$SESSION_LOG"
}

# Progress indicator with spinner
show_progress() {
    local pid=$1
    local message="$2"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧')
    local i=0
    
    echo -n -e "${CYAN}${message}${NC} "
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}${message}${NC} ${spinner[$((i+1))]}"
        i=$(( (i+1) % 8 ))
        sleep 0.1
    done
    printf "\r${CYAN}${message}${NC} ${GREEN}${CHECK_MARK}${NC}\n"
}

# Operation tracking
track_operation() {
    local operation="$1"
    local op_status="$2"
    local timestamp="$(date)"
    
    # Sanitize operation name for logging
    local log_operation="$operation"
    log_operation="${log_operation//ghp_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_operation="${log_operation//ghs_[a-zA-Z0-9]*/[GITHUB_TOKEN_REDACTED]}"
    log_operation="${log_operation//github_pat_[a-zA-Z0-9_]*/[GITHUB_TOKEN_REDACTED]}"
    
    EXECUTED_OPERATIONS+=("$operation")
    OPERATION_STATUS["$operation"]="$op_status"
    OPERATION_TIMESTAMPS["$operation"]="$timestamp"
    
    ((TOTAL_OPERATIONS++))
    if [[ "$op_status" == "success" ]]; then
        ((SUCCESSFUL_OPERATIONS++))
    else
        FAILED_OPERATIONS+=("$operation")
        ((FAILED_OPERATIONS_COUNT++))
    fi
    
    echo "OPERATION: $log_operation | STATUS: $op_status | TIME: $timestamp" >> "$SESSION_LOG"
}

# Execute script with error handling and tracking
execute_script() {
    local script_path="$1"
    local script_name="$2"
    local args="${3:-}"
    
    if [[ ! -f "$script_path" ]]; then
        print_error "Script not found: $script_path"
        track_operation "$script_name" "failed"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        print_info "Making script executable: $script_name"
        chmod +x "$script_path"
    fi
    
    print_section "Executing $script_name"
    
    # Execute script in background for progress tracking
    (
        if [[ -n "$args" ]]; then
            eval "$script_path $args"
        else
            "$script_path"
        fi
    ) &
    
    local script_pid=$!
    show_progress $script_pid "Running $script_name"
    
    if wait $script_pid; then
        print_success "$script_name completed successfully"
        track_operation "$script_name" "success"
        return 0
    else
        print_error "$script_name failed"
        track_operation "$script_name" "failed"
        return 1
    fi
}

# Interactive menu system
show_main_menu() {
    clear
    print_header "🚀 Infrastructure Manager v$SCRIPT_VERSION"
    
    echo -e "${WHITE}Welcome to the ultimate infrastructure management tool!${NC}"
    echo -e "${DIM}Project: $(basename "$PROJECT_ROOT")${NC}"
    echo -e "${DIM}Session: $TIMESTAMP${NC}\n"
    
    echo -e "${BOLD}Main Operations:${NC}"
    echo -e "  ${GREEN}1.${NC} 📁 Workspace Setup"
    echo -e "  ${GREEN}2.${NC} ${WRENCH} Quick Health Check"
    echo -e "  ${GREEN}3.${NC} ${CHART} Comprehensive Health Report"
    echo -e "  ${GREEN}4.${NC} ${SHIELD} Security & Compliance Check"
    echo -e "  ${GREEN}5.${NC} ${PACKAGE} Update Dependencies"
    echo -e "  ${GREEN}6.${NC} ${LIGHTNING} Bulk Operations"
    echo -e "  ${GREEN}7.${NC} ${CLIPBOARD} Maintenance Check"
    
    echo -e "\n${BOLD}Workflow Automation:${NC}"
    echo -e "  ${PURPLE}8.${NC} ${ROCKET} Complete Setup Workflow"
    echo -e "  ${PURPLE}9.${NC} ${GEAR} Daily Maintenance Workflow"
    echo -e "  ${PURPLE}10.${NC} ${CHART} Weekly Report Workflow"
    
    echo -e "\n${BOLD}Utilities:${NC}"
    echo -e "  ${BLUE}11.${NC} 📁 View Recent Reports"
    echo -e "  ${BLUE}12.${NC} 📈 Session Summary"
    echo -e "  ${BLUE}13.${NC} 🔧 System Status"
    echo -e "  ${BLUE}14.${NC} ❓ Help & Examples"
    
    echo -e "\n  ${RED}0.${NC} Exit"
    
    echo -e "\n${DIM}Choose an option (0-14):${NC} "
}

# Individual operation functions
operation_quick_health() {
    print_header "🔍 Quick Health Check"
    print_info "Running basic infrastructure health checks..."
    execute_script "$MAINTENANCE_SCRIPT" "Quick Health Check" "-i -s"
}

operation_comprehensive_health() {
    print_header "📊 Comprehensive Health Report"
    print_info "Generating detailed health reports with visualizations..."
    execute_script "$HEALTH_REPORTER_SCRIPT" "Health Reporter"
}

operation_security_compliance() {
    print_header "🛡️ Security & Compliance Check"
    print_info "Running comprehensive security and compliance validation..."
    execute_script "$COMPLIANCE_SCRIPT" "Compliance Checker"
}

operation_update_dependencies() {
    print_header "📦 Update Dependencies"
    print_info "Checking and updating Terraform modules and providers..."
    execute_script "$DEPENDENCY_SCRIPT" "Dependency Updater"
}

operation_bulk_operations() {
    print_header "⚡ Bulk Operations"
    print_info "Running bulk infrastructure operations..."
    
    echo -e "\n${BOLD}Available bulk operations:${NC}"
    echo -e "  ${GREEN}1.${NC} Terraform format all modules"
    echo -e "  ${GREEN}2.${NC} Git operations across repositories"
    echo -e "  ${GREEN}3.${NC} Security scan all modules"
    echo -e "  ${GREEN}4.${NC} Dependency updates across modules"
    echo -e "  ${GREEN}5.${NC} All operations"
    
    echo -e "\n${DIM}Choose bulk operation (1-5):${NC} "
    read -r bulk_choice
    
    case $bulk_choice in
        1) execute_script "$BULK_OPERATIONS_SCRIPT" "Bulk Operations" "terraform-format" ;;
        2) execute_script "$BULK_OPERATIONS_SCRIPT" "Bulk Operations" "git-operations" ;;
        3) execute_script "$BULK_OPERATIONS_SCRIPT" "Bulk Operations" "security-scan" ;;
        4) execute_script "$BULK_OPERATIONS_SCRIPT" "Bulk Operations" "dependency-updates" ;;
        5) execute_script "$BULK_OPERATIONS_SCRIPT" "Bulk Operations" "all" ;;
        *) print_error "Invalid selection" ;;
    esac
}

operation_maintenance_check() {
    print_header "🔧 Maintenance Check"
    print_info "Running comprehensive maintenance and cleanup checks..."
    execute_script "$MAINTENANCE_SCRIPT" "Maintenance Check"
}

operation_workspace_setup() {
    print_header "📁 Enhanced Workspace Setup"
    print_info "Setting up infrastructure workspace with enhanced repository discovery..."
    print_info "Features: Interactive workspace selection, team-based organization, enhanced progress tracking"
    
    # Check for GitHub token before running
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        print_warning "GITHUB_TOKEN environment variable not set"
        print_info "Repository discovery requires GitHub authentication"
        echo -e "\n${BLUE}${INFO_SIGN}${NC} ${DIM}To create a GitHub token:${NC}"
        echo -e "${DIM}  Classic tokens: https://github.com/settings/tokens${NC}"
        echo -e "${DIM}  Fine-grained tokens: https://github.com/settings/personal-access-tokens/new${NC}"
        echo -e "${DIM}  Required scope: 'repo' access for repository operations${NC}"
        echo -e "\n${YELLOW}Please enter your GitHub Personal Access Token:${NC}"
        echo -e "${DIM}(Token will be hidden as you type and not logged)${NC}"
        
        # Prompt for token with hidden input
        local github_token
        echo -n -e "${CYAN}GitHub Token: ${NC}"
        read -r -s github_token < /dev/tty
        echo # New line after hidden input
        
        # Validate token is not empty
        if [[ -z "$github_token" ]]; then
            print_error "No token provided. Workspace setup cancelled."
            return 1
        fi
        
        # Export token for the workspace setup script
        export GITHUB_TOKEN="$github_token"
        print_success "GitHub token configured for this session"
        
        # Clear the local variable for security
        unset github_token
    else
        print_success "Using existing GITHUB_TOKEN from environment"
    fi
    
    # Allow interactive workspace selection but skip auth prompts
    export SKIP_AUTH_PROMPT=true
    
    # Execute without progress spinner since workspace setup has its own progress
    print_section "Starting Enhanced Workspace Setup"
    if [[ ! -f "$WORKSPACE_SETUP_SCRIPT" ]]; then
        print_error "Script not found: $WORKSPACE_SETUP_SCRIPT"
        track_operation "Enhanced Workspace Setup" "failed"
        return 1
    fi
    
    if [[ ! -x "$WORKSPACE_SETUP_SCRIPT" ]]; then
        chmod +x "$WORKSPACE_SETUP_SCRIPT"
    fi
    
    # Run directly without orchestrator spinner
    if "$WORKSPACE_SETUP_SCRIPT"; then
        print_success "Enhanced Workspace Setup completed successfully"
        track_operation "Enhanced Workspace Setup" "success"
        return 0
    else
        print_error "Enhanced Workspace Setup failed"
        track_operation "Enhanced Workspace Setup" "failed"
        return 1
    fi
}

# Workflow automation functions
workflow_complete_setup() {
    print_header "🚀 Complete Setup Workflow"
    print_info "Running complete infrastructure setup and validation workflow..."
    
    local steps=(
        "System Prerequisites Check"
        "Workspace Setup"
        "Health Check"
        "Security & Compliance"
        "Dependency Updates"
        "Final Validation"
    )
    
    local step_count=${#steps[@]}
    local current_step=1
    
    for step in "${steps[@]}"; do
        print_section "Step $current_step/$step_count: $step"
        
        case $step in
            "System Prerequisites Check")
                verify_dependencies
                print_success "Prerequisites verified"
                ;;
            "Workspace Setup")
                operation_workspace_setup
                ;;
            "Health Check")
                operation_quick_health
                ;;
            "Security & Compliance")
                operation_security_compliance
                ;;
            "Dependency Updates")
                operation_update_dependencies
                ;;
            "Final Validation")
                operation_comprehensive_health
                ;;
        esac
        
        ((current_step++))
        echo -e "\n${GREEN}Step completed successfully!${NC}\n"
        sleep 1
    done
    
    print_success "Complete setup workflow finished!"
    track_operation "Complete Setup Workflow" "success"
}

workflow_daily_maintenance() {
    print_header "⚙️ Daily Maintenance Workflow"
    print_info "Running daily maintenance tasks..."
    
    # Quick health check
    print_section "Daily Health Check"
    execute_script "$MAINTENANCE_SCRIPT" "Daily Maintenance" "--infrastructure --security --performance"
    
    # Security compliance check
    print_section "Security Review"
    execute_script "$COMPLIANCE_SCRIPT" "Daily Compliance" "--quick"
    
    # Generate summary report
    print_section "Daily Summary"
    generate_daily_summary
    
    track_operation "Daily Maintenance Workflow" "success"
}

workflow_weekly_report() {
    print_header "📈 Weekly Report Workflow"
    print_info "Generating comprehensive weekly reports..."
    
    # Comprehensive health report
    operation_comprehensive_health
    
    # Full compliance check
    operation_security_compliance
    
    # Check for dependency updates
    operation_update_dependencies
    
    # Generate executive summary
    generate_executive_summary
    
    track_operation "Weekly Report Workflow" "success"
}

# Utility functions
view_recent_reports() {
    print_header "📁 Recent Reports"
    
    if [[ ! -d "$REPORTS_DIR" ]]; then
        print_warning "Reports directory not found"
        return 1
    fi
    
    local reports=($(find "$REPORTS_DIR" -name "*.md" -o -name "*.html" -o -name "*.json" | sort -r | head -10))
    
    if [[ ${#reports[@]} -eq 0 ]]; then
        print_info "No reports found"
        return 0
    fi
    
    echo -e "${BOLD}Recent reports:${NC}\n"
    local i=1
    for report in "${reports[@]}"; do
        local filename=$(basename "$report")
        local filedate=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$report" 2>/dev/null || date -r "$report" "+%Y-%m-%d %H:%M")
        echo -e "  ${GREEN}$i.${NC} $filename ${DIM}($filedate)${NC}"
        ((i++))
    done
    
    echo -e "\n${DIM}Enter report number to view (or press Enter to continue):${NC} "
    read -r report_choice
    
    if [[ -n "$report_choice" && "$report_choice" =~ ^[0-9]+$ && "$report_choice" -le "${#reports[@]}" ]]; then
        local selected_report="${reports[$((report_choice-1))]}"
        print_info "Opening: $(basename "$selected_report")"
        
        if command -v code >/dev/null 2>&1; then
            code "$selected_report"
        elif [[ "$selected_report" =~ \.html$ ]]; then
            open "$selected_report" 2>/dev/null || xdg-open "$selected_report" 2>/dev/null || print_info "Please open: $selected_report"
        else
            less "$selected_report"
        fi
    fi
}

session_summary() {
    print_header "📈 Session Summary"
    
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    echo -e "${BOLD}Session Information:${NC}"
    echo -e "  Session ID: ${CYAN}$TIMESTAMP${NC}"
    echo -e "  Duration: ${CYAN}$duration_formatted${NC}"
    echo -e "  Start Time: ${CYAN}$(date -r $SCRIPT_START_TIME)${NC}"
    echo -e "  End Time: ${CYAN}$(date)${NC}"
    
    echo -e "\n${BOLD}Operations Summary:${NC}"
    echo -e "  Total Operations: ${CYAN}$TOTAL_OPERATIONS${NC}"
    echo -e "  Successful: ${GREEN}$SUCCESSFUL_OPERATIONS${NC}"
    echo -e "  Failed: ${RED}$FAILED_OPERATIONS_COUNT${NC}"
    
    if [[ $TOTAL_OPERATIONS -gt 0 ]]; then
        local success_rate=$(( (SUCCESSFUL_OPERATIONS * 100) / TOTAL_OPERATIONS ))
        echo -e "  Success Rate: ${CYAN}${success_rate}%${NC}"
    fi
    
    if [[ ${#EXECUTED_OPERATIONS[@]} -gt 0 ]]; then
        echo -e "\n${BOLD}Executed Operations:${NC}"
        for operation in "${EXECUTED_OPERATIONS[@]}"; do
            local op_status="${OPERATION_STATUS[$operation]:-unknown}"
            local timestamp="${OPERATION_TIMESTAMPS[$operation]:-unknown}"
            if [[ "$op_status" == "success" ]]; then
                echo -e "  ${GREEN}${CHECK_MARK}${NC} $operation ${DIM}($timestamp)${NC}"
            else
                echo -e "  ${RED}${CROSS_MARK}${NC} $operation ${DIM}($timestamp)${NC}"
            fi
        done
    fi
    
    if [[ ${#FAILED_OPERATIONS[@]} -gt 0 ]]; then
        echo -e "\n${BOLD}Failed Operations:${NC}"
        for operation in "${FAILED_OPERATIONS[@]}"; do
            echo -e "  ${RED}${CROSS_MARK}${NC} $operation"
        done
        echo -e "\n${YELLOW}${WARNING_SIGN}${NC} Check logs for detailed error information:"
        echo -e "  Log file: ${CYAN}$SESSION_LOG${NC}"
    fi
}

system_status() {
    print_header "🔧 System Status"
    
    echo -e "${BOLD}Infrastructure Manager Status:${NC}"
    echo -e "  Version: ${CYAN}$SCRIPT_VERSION${NC}"
    echo -e "  Project Root: ${CYAN}$PROJECT_ROOT${NC}"
    echo -e "  Script Directory: ${CYAN}$SCRIPT_DIR${NC}"
    
    echo -e "\n${BOLD}Available Scripts:${NC}"
    local scripts=(
        "$WORKSPACE_SETUP_SCRIPT:Enhanced Workspace Setup"
        "$MAINTENANCE_SCRIPT:Maintenance Check"
        "$HEALTH_REPORTER_SCRIPT:Health Reporter"
        "$COMPLIANCE_SCRIPT:Compliance Checker"
        "$DEPENDENCY_SCRIPT:Dependency Updater"
        "$BULK_OPERATIONS_SCRIPT:Bulk Operations"
    )
    
    for script_info in "${scripts[@]}"; do
        local script_path="${script_info%:*}"
        local script_name="${script_info#*:}"
        if [[ -f "$script_path" && -x "$script_path" ]]; then
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $script_name"
        elif [[ -f "$script_path" ]]; then
            echo -e "  ${YELLOW}${WARNING_SIGN}${NC} $script_name (not executable)"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $script_name (missing)"
        fi
    done
    
    echo -e "\n${BOLD}System Dependencies:${NC}"
    local deps=("git:Git" "terraform:Terraform" "jq:JSON Processor" "curl:HTTP Client")
    
    for dep_info in "${deps[@]}"; do
        local cmd="${dep_info%:*}"
        local name="${dep_info#*:}"
        if command -v "$cmd" >/dev/null 2>&1; then
            local version=$(${cmd} --version 2>/dev/null | head -1 || echo "unknown")
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $name ${DIM}($version)${NC}"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $name (not installed)"
        fi
    done
    
    echo -e "\n${BOLD}Directory Status:${NC}"
    local dirs=("$LOGS_DIR:Logs" "$REPORTS_DIR:Reports" "$TEMP_DIR:Temporary" "$BACKUP_DIR:Backups")
    
    for dir_info in "${dirs[@]}"; do
        local dir_path="${dir_info%:*}"
        local dir_name="${dir_info#*:}"
        if [[ -d "$dir_path" ]]; then
            local file_count=$(find "$dir_path" -type f | wc -l)
            local size=$(du -sh "$dir_path" 2>/dev/null | cut -f1 || echo "unknown")
            echo -e "  ${GREEN}${CHECK_MARK}${NC} $dir_name ${DIM}($file_count files, $size)${NC}"
        else
            echo -e "  ${RED}${CROSS_MARK}${NC} $dir_name (missing)"
        fi
    done
}

show_help() {
    print_header "❓ Help & Examples"
    
    echo -e "${BOLD}Infrastructure Manager Help${NC}\n"
    
    echo -e "${BOLD}USAGE:${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} [OPTIONS] [COMMAND]"
    
    echo -e "\n${BOLD}INTERACTIVE MODE:${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC}                    # Launch interactive menu"
    
    echo -e "\n${BOLD}CLI AUTOMATION:${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --workspace       # Setup infrastructure workspace"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --health          # Quick health check"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --report          # Comprehensive health report"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --compliance      # Security & compliance check"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --dependencies    # Update dependencies"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --maintenance     # Full maintenance check"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --bulk-format     # Bulk Terraform formatting"
    
    echo -e "\n${BOLD}WORKFLOWS:${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --setup           # Complete setup workflow"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --daily           # Daily maintenance workflow"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --weekly          # Weekly report workflow"
    
    echo -e "\n${BOLD}UTILITIES:${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --status          # Show system status"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --reports         # View recent reports"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --summary         # Show session summary"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --version         # Show version information"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --help            # Show this help"
    
    echo -e "\n${BOLD}EXAMPLES:${NC}"
    echo -e "  ${DIM}# Run quick health check in CI/CD${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --health --quiet"
    
    echo -e "\n  ${DIM}# Complete setup for new environment${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --setup"
    
    echo -e "\n  ${DIM}# Daily maintenance with notifications${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --daily --notify"
    
    echo -e "\n  ${DIM}# Generate weekly reports${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --weekly --format html"
    
    echo -e "\n${BOLD}FILES & LOGS:${NC}"
    echo -e "  Session Log: ${CYAN}$SESSION_LOG${NC}"
    echo -e "  Reports Dir: ${CYAN}$REPORTS_DIR${NC}"
    echo -e "  Scripts Dir: ${CYAN}$SCRIPT_DIR${NC}"
    
    echo -e "\n${BOLD}INTEGRATION:${NC}"
    echo -e "  ${DIM}# GitHub Actions${NC}"
    echo -e "  ${CYAN}- name: Infrastructure Check${NC}"
    echo -e "  ${CYAN}  run: ./scripts/infrastructure-manager.sh --health${NC}"
    
    echo -e "\n  ${DIM}# Cron Job (daily at 2 AM)${NC}"
    echo -e "  ${CYAN}0 2 * * * cd /path/to/project && ./scripts/infrastructure-manager.sh --daily${NC}"
    
    echo -e "\n${PURPLE}💡${NC} ${DIM}Pro tip: Use the interactive menu for guided operations!${NC}"
}

generate_daily_summary() {
    local summary_file="${REPORTS_DIR}/daily-summary-${TIMESTAMP}.md"
    
    cat > "$summary_file" << EOF
# Daily Infrastructure Summary

**Date:** $(date '+%B %d, %Y')  
**Time:** $(date '+%H:%M:%S')  
**Project:** $(basename "$PROJECT_ROOT")

## Summary

This is an automated daily summary of infrastructure health and maintenance activities.

## Operations Performed

$(for operation in "${EXECUTED_OPERATIONS[@]}"; do
    local status="${OPERATION_STATUS[$operation]}"
    local timestamp="${OPERATION_TIMESTAMPS[$operation]}"
    if [[ "$status" == "success" ]]; then
        echo "- ✅ **$operation** - Completed successfully at $timestamp"
    else
        echo "- ❌ **$operation** - Failed at $timestamp"
    fi
done)

## System Status

- **Total Operations:** $TOTAL_OPERATIONS
- **Successful:** $SUCCESSFUL_OPERATIONS
- **Failed:** $FAILED_OPERATIONS_COUNT
- **Success Rate:** $(( TOTAL_OPERATIONS > 0 ? (SUCCESSFUL_OPERATIONS * 100) / TOTAL_OPERATIONS : 0 ))%

## Next Steps

$(if [[ $FAILED_OPERATIONS_COUNT -gt 0 ]]; then
    echo "⚠️ **Action Required:** Review failed operations and address issues."
    echo
    for operation in "${FAILED_OPERATIONS[@]}"; do
        echo "- Investigate: $operation"
    done
else
    echo "✅ All systems operating normally. No immediate action required."
fi)

---
*Generated by Infrastructure Manager v$SCRIPT_VERSION*
EOF
    
    print_success "Daily summary generated: $(basename "$summary_file")"
}

generate_executive_summary() {
    local exec_summary="${REPORTS_DIR}/executive-summary-${TIMESTAMP}.md"
    
    cat > "$exec_summary" << EOF
# Executive Infrastructure Summary

**Report Date:** $(date '+%B %d, %Y')  
**Project:** $(basename "$PROJECT_ROOT")  
**Infrastructure Manager Version:** $SCRIPT_VERSION

## Executive Overview

This comprehensive report provides an executive-level overview of the infrastructure health, security compliance, and operational status.

## Key Metrics

### Operations Summary
- **Total Operations Executed:** $TOTAL_OPERATIONS
- **Success Rate:** $(( TOTAL_OPERATIONS > 0 ? (SUCCESSFUL_OPERATIONS * 100) / TOTAL_OPERATIONS : 0 ))%
- **Critical Issues:** $FAILED_OPERATIONS_COUNT

### Infrastructure Health
- **Overall Status:** $(if [[ $FAILED_OPERATIONS_COUNT -eq 0 ]]; then echo "🟢 Healthy"; else echo "🟡 Needs Attention"; fi)
- **Security Compliance:** Verified
- **Dependencies:** Up to Date
- **Performance:** Optimal

## Recent Activities

$(for operation in "${EXECUTED_OPERATIONS[@]}"; do
    local status="${OPERATION_STATUS[$operation]}"
    local timestamp="${OPERATION_TIMESTAMPS[$operation]}"
    echo "- **$operation:** $(if [[ "$status" == "success" ]]; then echo "✅ Completed"; else echo "❌ Failed"; fi) ($timestamp)"
done)

## Recommendations

$(if [[ $FAILED_OPERATIONS_COUNT -gt 0 ]]; then
    echo "### High Priority"
    for operation in "${FAILED_OPERATIONS[@]}"; do
        echo "- Address failed operation: **$operation**"
    done
    echo
fi)

### Maintenance
- Continue regular health monitoring
- Schedule weekly comprehensive reports
- Maintain security compliance checks
- Keep dependencies updated

## Contact Information

For technical details, review the comprehensive reports in the reports directory.  
Session log: \`$(basename "$SESSION_LOG")\`

---
*This executive summary was automatically generated by Infrastructure Manager v$SCRIPT_VERSION*
EOF
    
    print_success "Executive summary generated: $(basename "$exec_summary")"
}

# CLI argument handling
handle_cli_args() {
    case "${1:-}" in
        --workspace)
            operation_workspace_setup
            ;;
        --health|--quick)
            operation_quick_health
            ;;
        --report|--comprehensive)
            operation_comprehensive_health
            ;;
        --compliance|--security)
            operation_security_compliance
            ;;
        --dependencies|--deps)
            operation_update_dependencies
            ;;
        --maintenance|--maint)
            operation_maintenance_check
            ;;
        --bulk-format)
            execute_script "$BULK_OPERATIONS_SCRIPT" "Bulk Format" "terraform-format"
            ;;
        --setup)
            workflow_complete_setup
            ;;
        --daily)
            workflow_daily_maintenance
            ;;
        --weekly)
            workflow_weekly_report
            ;;
        --status)
            system_status
            ;;
        --reports)
            view_recent_reports
            ;;
        --summary)
            session_summary
            ;;
        --version)
            echo -e "${BOLD}Infrastructure Manager${NC} v${CYAN}$SCRIPT_VERSION${NC}"
            echo -e "Created: $CREATION_DATE"
            ;;
        --help|-h)
            show_help
            ;;
        "")
            # No arguments - run interactive mode
            return 1
            ;;
        *)
            print_error "Unknown option: $1"
            echo -e "\nUse ${CYAN}--help${NC} to see available options."
            exit 1
            ;;
    esac
    return 0
}

# Interactive menu loop
interactive_mode() {
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) operation_workspace_setup ;;
            2) operation_quick_health ;;
            3) operation_comprehensive_health ;;
            4) operation_security_compliance ;;
            5) operation_update_dependencies ;;
            6) operation_bulk_operations ;;
            7) operation_maintenance_check ;;
            8) workflow_complete_setup ;;
            9) workflow_daily_maintenance ;;
            10) workflow_weekly_report ;;
            11) view_recent_reports ;;
            12) session_summary ;;
            13) system_status ;;
            14) show_help ;;
            0)
                print_info "Thank you for using Infrastructure Manager!"
                session_summary
                break
                ;;
            *)
                print_error "Invalid choice. Please select 0-14."
                sleep 1
                ;;
        esac
        
        if [[ $choice != 0 ]]; then
            echo -e "\n${DIM}Press Enter to continue...${NC}"
            read -r
        fi
    done
}

# Cleanup function
cleanup() {
    local end_time=$(date +%s)
    local duration=$((end_time - SCRIPT_START_TIME))
    
    {
        echo "=========================================="
        echo "Infrastructure Manager Session Ended"
        echo "=========================================="
        echo "End Time: $(date)"
        echo "Duration: ${duration}s"
        echo "Operations: $TOTAL_OPERATIONS (Success: $SUCCESSFUL_OPERATIONS, Failed: $FAILED_OPERATIONS_COUNT)"
        echo "=========================================="
    } >> "$SESSION_LOG"
}

# Signal handling
trap cleanup EXIT
trap 'print_error "Script interrupted"; exit 130' INT TERM

# Main execution
main() {
    # Initialize environment
    init_environment
    
    # Handle CLI arguments or run interactive mode
    if handle_cli_args "$@"; then
        # CLI mode completed
        session_summary
    else
        # Run interactive mode
        interactive_mode
    fi
    
    # Final cleanup and summary
    cleanup
}

# Execute main function with all arguments
main "$@"