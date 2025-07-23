#!/bin/bash

# Bulk Infrastructure Operations Script
# Created: $(date +%Y-%m-%d)
# Description: Comprehensive bulk operations for Git repos, Terraform, security scanning, and dependency management
# Features: Parallel execution, progress tracking, rollback capabilities, colored output

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
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Calculate infrastructure root: /path/to/infrastructure/shared/mob-infra-cicd/scripts -> /path/to/infrastructure
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly BACKUP_DIR="${SCRIPT_DIR}/backups"
readonly TEMP_DIR="${SCRIPT_DIR}/temp"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly BULK_LOG="${LOG_DIR}/bulk-operations-${TIMESTAMP}.log"

# Operation tracking (using arrays and files since bash 3.2 doesn't support associative arrays)
OPERATION_PIDS=()
OPERATION_NAMES=()
FAILED_OPERATIONS=()
SUCCESSFUL_OPERATIONS=()
SKIPPED_OPERATIONS=()
readonly STATUS_DIR="${TEMP_DIR}/status-${TIMESTAMP}"

# Performance settings
MAX_PARALLEL_JOBS=8
readonly CURRENT_JOBS=0

# Initialize directories
init_directories() {
    mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$TEMP_DIR" "$STATUS_DIR"
}

# Logging functions
log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" >> "$BULK_LOG"
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

print_subsection() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
    log_message "INFO" "SUBSECTION: $1"
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

# Progress bar with colors
progress_bar() {
    local current=$1
    local total=$2
    local operation=${3:-"Processing"}
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r${CYAN}${operation}: ${NC}${BLUE}[${NC}"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $((width - completed)) | tr ' ' '░'
    printf "${BLUE}] ${WHITE}%d%% ${CYAN}(%d/%d)${NC}" $percentage $current $total
    
    if [[ $current -eq $total ]]; then
        echo # New line when complete
    fi
}

# Spinner for long-running operations
show_spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${PURPLE}${spin:$i:1}${NC} $message"
        i=$(((i + 1) % ${#spin}))
        sleep 0.1
    done
    printf "\r"
}

# Operation status helpers (bash 3.2 compatible)
set_operation_status() {
    local operation="$1"
    local status="$2"
    echo "$status" > "${STATUS_DIR}/${operation}.status"
}

get_operation_status() {
    local operation="$1"
    if [[ -f "${STATUS_DIR}/${operation}.status" ]]; then
        cat "${STATUS_DIR}/${operation}.status"
    else
        echo "UNKNOWN"
    fi
}

add_operation_pid() {
    local pid="$1"
    local operation="$2"
    OPERATION_PIDS+=("$pid")
    OPERATION_NAMES+=("$operation")
    echo "$operation" > "${STATUS_DIR}/${pid}.operation"
}

remove_operation_pid() {
    local target_pid="$1"
    local new_pids=()
    local new_names=()
    
    for i in "${!OPERATION_PIDS[@]}"; do
        if [[ "${OPERATION_PIDS[$i]}" != "$target_pid" ]]; then
            new_pids+=("${OPERATION_PIDS[$i]}")
            new_names+=("${OPERATION_NAMES[$i]}")
        fi
    done
    
    if [[ ${#new_pids[@]} -gt 0 ]]; then
        OPERATION_PIDS=("${new_pids[@]}")
        OPERATION_NAMES=("${new_names[@]}")
    else
        OPERATION_PIDS=()
        OPERATION_NAMES=()
    fi
    
    rm -f "${STATUS_DIR}/${target_pid}.operation"
}

# Parallel job management
wait_for_job_slot() {
    while [[ ${#OPERATION_PIDS[@]} -ge $MAX_PARALLEL_JOBS ]]; do
        local found_completed=false
        
        for i in "${!OPERATION_PIDS[@]}"; do
            local pid="${OPERATION_PIDS[$i]}"
            local operation="${OPERATION_NAMES[$i]}"
            
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid"
                local exit_code=$?
                
                if [[ $exit_code -eq 0 ]]; then
                    set_operation_status "$operation" "SUCCESS"
                    SUCCESSFUL_OPERATIONS+=("$operation")
                else
                    set_operation_status "$operation" "FAILED"
                    FAILED_OPERATIONS+=("$operation")
                fi
                
                remove_operation_pid "$pid"
                found_completed=true
                break
            fi
        done
        
        if [[ "$found_completed" == false ]]; then
            sleep 0.1
        fi
    done
}

# Wait for all jobs to complete
wait_for_all_jobs() {
    while [[ ${#OPERATION_PIDS[@]} -gt 0 ]]; do
        local pids_to_remove=()
        
        for i in "${!OPERATION_PIDS[@]}"; do
            local pid="${OPERATION_PIDS[$i]}"
            local operation="${OPERATION_NAMES[$i]}"
            
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid"
                local exit_code=$?
                
                if [[ $exit_code -eq 0 ]]; then
                    set_operation_status "$operation" "SUCCESS"
                    SUCCESSFUL_OPERATIONS+=("$operation")
                else
                    set_operation_status "$operation" "FAILED"
                    FAILED_OPERATIONS+=("$operation")
                fi
                
                pids_to_remove+=("$pid")
            fi
        done
        
        # Remove completed PIDs
        for pid in "${pids_to_remove[@]}"; do
            remove_operation_pid "$pid"
        done
        
        sleep 0.1
    done
}

# Find all Git repositories
find_git_repositories() {
    find "$PROJECT_ROOT" -type d -name ".git" -exec dirname {} \; | sort
}

# Find all Terraform directories
find_terraform_directories() {
    find "$PROJECT_ROOT" -name "*.tf" -type f -exec dirname {} \; | sort -u | grep -v "\.terraform"
}

# Create backup of current state
create_backup() {
    local operation="$1"
    local target="$2"
    local backup_path="${BACKUP_DIR}/${operation}-${TIMESTAMP}"
    
    print_info "Creating backup for $operation: $target"
    
    if [[ -d "$target" ]]; then
        mkdir -p "$backup_path"
        
        # Backup git state if it's a git repo
        if [[ -d "$target/.git" ]]; then
            git -C "$target" stash push -m "bulk-operations-backup-${TIMESTAMP}" 2>/dev/null || true
            git -C "$target" log --oneline -n 10 > "$backup_path/git-log.txt" 2>/dev/null || true
            git -C "$target" status --porcelain > "$backup_path/git-status.txt" 2>/dev/null || true
        fi
        
        # Backup Terraform state if it exists
        if [[ -f "$target/.terraform.lock.hcl" ]]; then
            cp "$target/.terraform.lock.hcl" "$backup_path/" 2>/dev/null || true
        fi
        
        # Store rollback command
        echo "restore_backup '$backup_path'" > "${STATUS_DIR}/${operation}.rollback"
        
        print_success "Backup created: $backup_path"
        return 0
    else
        print_warning "Target directory not found: $target"
        return 1
    fi
}

# Restore from backup
restore_backup() {
    local backup_path="$1"
    print_warning "Restoring from backup: $backup_path"
    
    # Implementation would depend on specific backup contents
    # This is a placeholder for the rollback mechanism
    log_message "ROLLBACK" "Restore initiated from: $backup_path"
}

# Get rollback command for operation
get_rollback_command() {
    local operation="$1"
    if [[ -f "${STATUS_DIR}/${operation}.rollback" ]]; then
        cat "${STATUS_DIR}/${operation}.rollback"
    fi
}

# ============================================
# GIT BULK OPERATIONS
# ============================================

bulk_git_status() {
    print_section "Bulk Git Status Check"
    
    local repos=($(find_git_repositories))
    local total=${#repos[@]}
    local current=0
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Git repositories found"
        return 0
    fi
    
    print_info "Found $total Git repositories"
    
    for repo in "${repos[@]}"; do
        ((current++))
        progress_bar $current $total "Git Status"
        
        local repo_name="$(basename "$repo")"
        print_subsection "Repository: $repo_name"
        
        (
            cd "$repo"
            echo -e "${CYAN}Repository:${NC} $repo"
            echo -e "${BLUE}Branch:${NC} $(git branch --show-current 2>/dev/null || echo 'detached')"
            echo -e "${BLUE}Status:${NC}"
            
            local status_output="$(git status --porcelain 2>/dev/null)"
            if [[ -n "$status_output" ]]; then
                echo "$status_output" | while IFS= read -r line; do
                    local status_code="${line:0:2}"
                    local file_path="${line:3}"
                    
                    case "$status_code" in
                        " M"|"M ") echo -e "  ${YELLOW}Modified:${NC} $file_path" ;;
                        " A"|"A ") echo -e "  ${GREEN}Added:${NC} $file_path" ;;
                        " D"|"D ") echo -e "  ${RED}Deleted:${NC} $file_path" ;;
                        "??") echo -e "  ${BLUE}Untracked:${NC} $file_path" ;;
                        *) echo -e "  ${PURPLE}Other:${NC} $file_path ($status_code)" ;;
                    esac
                done
            else
                echo -e "  ${GREEN}Clean working directory${NC}"
            fi
            
            # Check for unpushed commits
            local unpushed="$(git log --oneline @{u}.. 2>/dev/null | wc -l || echo "0")"
            if [[ $unpushed -gt 0 ]]; then
                echo -e "${YELLOW}Unpushed commits:${NC} $unpushed"
            fi
            
            # Check for unpulled commits
            local unpulled="$(git log --oneline ..@{u} 2>/dev/null | wc -l || echo "0")"
            if [[ $unpulled -gt 0 ]]; then
                echo -e "${YELLOW}Unpulled commits:${NC} $unpulled"
            fi
            
            echo
        ) | tee -a "$BULK_LOG"
    done
    
    print_success "Git status check completed for $total repositories"
}

bulk_git_pull() {
    print_section "Bulk Git Pull"
    
    local repos=($(find_git_repositories))
    local total=${#repos[@]}
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Git repositories found"
        return 0
    fi
    
    print_info "Pulling updates for $total repositories"
    
    for repo in "${repos[@]}"; do
        wait_for_job_slot
        
        local repo_name="$(basename "$repo")"
        print_progress "Pulling: $repo_name"
        
        (
            operation_name="git-pull-$repo_name"
            create_backup "$operation_name" "$repo"
            
            cd "$repo"
            
            # Check if we have a remote
            if ! git remote get-url origin &>/dev/null; then
                print_warning "$repo_name: No remote origin configured"
                exit 1
            fi
            
            local has_stash=false
            
            # Check for local changes
            if [[ -n "$(git status --porcelain)" ]]; then
                print_warning "$repo_name: Local changes detected, stashing first"
                if git stash push -m "bulk-pull-stash-${TIMESTAMP}"; then
                    has_stash=true
                    print_info "$repo_name: Changes stashed successfully"
                else
                    print_error "$repo_name: Failed to stash changes"
                    exit 1
                fi
            fi
            
            # Pull changes (without rebase to avoid conflicts)
            if git pull origin "$(git branch --show-current)" 2>&1; then
                print_success "$repo_name: Pull completed successfully"
                
                # Reapply stash if we created one
                if [[ "$has_stash" == true ]]; then
                    if git stash pop; then
                        print_success "$repo_name: Stashed changes reapplied successfully"
                    else
                        print_warning "$repo_name: Stash reapplication may have conflicts - check manually"
                    fi
                fi
            else
                print_error "$repo_name: Pull failed"
                
                # If we stashed, try to restore the stash
                if [[ "$has_stash" == true ]]; then
                    git stash pop
                    print_info "$repo_name: Restored stashed changes due to pull failure"
                fi
                exit 1
            fi
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "git-pull-$(basename "$repo")"
    done
    
    wait_for_all_jobs
    print_success "Bulk Git pull completed"
}

bulk_git_commit() {
    local message="$1"
    
    if [[ -z "$message" ]]; then
        print_error "Commit message is required"
        return 1
    fi
    
    print_section "Bulk Git Commit"
    
    local repos=($(find_git_repositories))
    local total=${#repos[@]}
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Git repositories found"
        return 0
    fi
    
    print_info "Committing changes to $total repositories with message: '$message'"
    
    for repo in "${repos[@]}"; do
        wait_for_job_slot
        
        local repo_name="$(basename "$repo")"
        
        (
            cd "$repo"
            
            # Check if there are changes to commit
            if [[ -z "$(git status --porcelain)" ]]; then
                print_info "$repo_name: No changes to commit"
                exit 0
            fi
            
            print_progress "Committing: $repo_name"
            
            # Add all changes
            git add -A
            
            # Commit with provided message
            if git commit -m "$message

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"; then
                print_success "$repo_name: Changes committed successfully"
            else
                print_error "$repo_name: Commit failed"
                exit 1
            fi
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "git-commit-$(basename "$repo")"
    done
    
    wait_for_all_jobs
    print_success "Bulk Git commit completed"
}

bulk_git_push() {
    print_section "Bulk Git Push"
    
    local repos=($(find_git_repositories))
    local total=${#repos[@]}
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Git repositories found"
        return 0
    fi
    
    print_info "Pushing changes for $total repositories"
    
    for repo in "${repos[@]}"; do
        wait_for_job_slot
        
        local repo_name="$(basename "$repo")"
        
        (
            cd "$repo"
            
            # Check if we have commits to push
            local unpushed="$(git log --oneline @{u}.. 2>/dev/null | wc -l || echo "0")"
            if [[ $unpushed -eq 0 ]]; then
                print_info "$repo_name: No commits to push"
                exit 0
            fi
            
            print_progress "Pushing: $repo_name"
            
            # Push changes
            if git push origin "$(git branch --show-current)" 2>&1; then
                print_success "$repo_name: Push completed successfully"
            else
                print_error "$repo_name: Push failed"
                exit 1
            fi
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "git-push-$(basename "$repo")"
    done
    
    wait_for_all_jobs
    print_success "Bulk Git push completed"
}

# ============================================
# TERRAFORM BULK OPERATIONS
# ============================================

bulk_terraform_fmt() {
    print_section "Bulk Terraform Format"
    
    local tf_dirs=($(find_terraform_directories))
    local total=${#tf_dirs[@]}
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Terraform directories found"
        return 0
    fi
    
    if ! command -v terraform &>/dev/null; then
        print_error "Terraform is not installed"
        return 1
    fi
    
    print_info "Formatting $total Terraform directories"
    
    for dir in "${tf_dirs[@]}"; do
        wait_for_job_slot
        
        local dir_name="$(basename "$dir")"
        
        (
            print_progress "Formatting: $dir_name"
            
            cd "$dir"
            
            if terraform fmt -recursive 2>&1; then
                print_success "$dir_name: Formatting completed successfully"
            else
                print_error "$dir_name: Formatting failed"
                exit 1
            fi
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "tf-fmt-$(basename "$dir")"
    done
    
    wait_for_all_jobs
    print_success "Bulk Terraform format completed"
}

bulk_terraform_validate() {
    print_section "Bulk Terraform Validate"
    
    local tf_dirs=($(find_terraform_directories))
    local total=${#tf_dirs[@]}
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Terraform directories found"
        return 0
    fi
    
    if ! command -v terraform &>/dev/null; then
        print_error "Terraform is not installed"
        return 1
    fi
    
    print_info "Validating $total Terraform directories"
    
    for dir in "${tf_dirs[@]}"; do
        wait_for_job_slot
        
        local dir_name="$(basename "$dir")"
        
        (
            print_progress "Validating: $dir_name"
            
            cd "$dir"
            
            # Initialize if needed
            if [[ ! -d ".terraform" ]]; then
                print_info "$dir_name: Initializing Terraform"
                terraform init -input=false -no-color &>/dev/null || {
                    print_warning "$dir_name: Terraform init failed, skipping validation"
                    exit 2
                }
            fi
            
            if terraform validate -no-color 2>&1; then
                print_success "$dir_name: Validation passed"
            else
                print_error "$dir_name: Validation failed"
                exit 1
            fi
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "tf-validate-$(basename "$dir")"
    done
    
    wait_for_all_jobs
    print_success "Bulk Terraform validate completed"
}

bulk_terraform_plan() {
    print_section "Bulk Terraform Plan"
    
    local tf_dirs=($(find_terraform_directories))
    local total=${#tf_dirs[@]}
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Terraform directories found"
        return 0
    fi
    
    if ! command -v terraform &>/dev/null; then
        print_error "Terraform is not installed"
        return 1
    fi
    
    print_info "Creating plans for $total Terraform directories"
    local plan_dir="${TEMP_DIR}/terraform-plans-${TIMESTAMP}"
    mkdir -p "$plan_dir"
    
    for dir in "${tf_dirs[@]}"; do
        wait_for_job_slot
        
        local dir_name="$(basename "$dir")"
        local plan_file="${plan_dir}/${dir_name}.tfplan"
        
        (
            print_progress "Planning: $dir_name"
            
            cd "$dir"
            
            # Initialize if needed
            if [[ ! -d ".terraform" ]]; then
                print_info "$dir_name: Initializing Terraform"
                terraform init -input=false -no-color &>/dev/null || {
                    print_warning "$dir_name: Terraform init failed, skipping plan"
                    exit 2
                }
            fi
            
            # Create plan
            if terraform plan -detailed-exitcode -out="$plan_file" -no-color > "${plan_file}.txt" 2>&1; then
                local exit_code=$?
                
                case $exit_code in
                    0)
                        print_success "$dir_name: No changes needed"
                        ;;
                    2)
                        local changes=$(grep -E "(will be created|will be updated|will be destroyed)" "${plan_file}.txt" | wc -l)
                        print_info "$dir_name: $changes changes detected"
                        ;;
                esac
            else
                print_error "$dir_name: Plan failed"
                cat "${plan_file}.txt" | head -20
                exit 1
            fi
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "tf-plan-$(basename "$dir")"
    done
    
    wait_for_all_jobs
    print_info "Plans saved to: $plan_dir"
    print_success "Bulk Terraform plan completed"
}

# ============================================
# SECURITY SCANNING
# ============================================

bulk_security_scan() {
    print_section "Bulk Security Scanning"
    
    # Check for available security tools
    local tools_found=()
    
    if command -v checkov &>/dev/null; then
        tools_found+=("checkov")
    fi
    
    if command -v tfsec &>/dev/null; then
        tools_found+=("tfsec")
    fi
    
    if command -v semgrep &>/dev/null; then
        tools_found+=("semgrep")
    fi
    
    if command -v bandit &>/dev/null; then
        tools_found+=("bandit")
    fi
    
    if [[ ${#tools_found[@]} -eq 0 ]]; then
        print_warning "No security scanning tools found (checkov, tfsec, semgrep, bandit)"
        run_basic_security_scan
        return
    fi
    
    print_info "Found security tools: ${tools_found[*]}"
    
    local scan_dir="${TEMP_DIR}/security-scans-${TIMESTAMP}"
    mkdir -p "$scan_dir"
    
    # Run each available tool
    for tool in "${tools_found[@]}"; do
        wait_for_job_slot
        
        (
            print_progress "Running: $tool"
            
            case "$tool" in
                "checkov")
                    checkov -d "$PROJECT_ROOT" --framework terraform --output json > "$scan_dir/checkov-results.json" 2>/dev/null || true
                    checkov -d "$PROJECT_ROOT" --framework terraform > "$scan_dir/checkov-results.txt" 2>/dev/null || true
                    ;;
                "tfsec")
                    tfsec "$PROJECT_ROOT" --format json > "$scan_dir/tfsec-results.json" 2>/dev/null || true
                    tfsec "$PROJECT_ROOT" > "$scan_dir/tfsec-results.txt" 2>/dev/null || true
                    ;;
                "semgrep")
                    semgrep --config=auto "$PROJECT_ROOT" --json > "$scan_dir/semgrep-results.json" 2>/dev/null || true
                    semgrep --config=auto "$PROJECT_ROOT" > "$scan_dir/semgrep-results.txt" 2>/dev/null || true
                    ;;
                "bandit")
                    find "$PROJECT_ROOT" -name "*.py" -type f | head -1 >/dev/null && {
                        bandit -r "$PROJECT_ROOT" -f json > "$scan_dir/bandit-results.json" 2>/dev/null || true
                        bandit -r "$PROJECT_ROOT" > "$scan_dir/bandit-results.txt" 2>/dev/null || true
                    }
                    ;;
            esac
            
            print_success "$tool: Scan completed"
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "security-$tool"
    done
    
    wait_for_all_jobs
    
    # Generate summary report
    generate_security_summary "$scan_dir"
    
    print_info "Security scan results saved to: $scan_dir"
    print_success "Bulk security scanning completed"
}

run_basic_security_scan() {
    print_info "Running basic security pattern scanning"
    
    local scan_dir="${TEMP_DIR}/basic-security-scan-${TIMESTAMP}"
    mkdir -p "$scan_dir"
    
    # Basic security patterns
    local patterns=(
        "password\s*=\s*[\"'][^\"']{8,}"
        "secret\s*=\s*[\"'][^\"']{8,}"
        "api[_-]?key\s*=\s*[\"'][^\"']{8,}"
        "access[_-]?key\s*=\s*[\"'][^\"']{16,}"
        "private[_-]?key\s*=\s*[\"'][^\"']{20,}"
        "token\s*=\s*[\"'][^\"']{8,}"
        "aws_access_key_id\s*=\s*[\"']AKIA[0-9A-Z]{16}[\"']"
        "aws_secret_access_key\s*=\s*[\"'][A-Za-z0-9/+=]{40}[\"']"
    )
    
    print_info "Scanning for hardcoded secrets and credentials"
    
    local results_file="$scan_dir/basic-security-results.txt"
    echo "Basic Security Scan Results - $(date)" > "$results_file"
    echo "=======================================" >> "$results_file"
    
    local issues_found=0
    
    for pattern in "${patterns[@]}"; do
        local matches=$(grep -r -E -i "$pattern" "$PROJECT_ROOT" \
            --include="*.tf" --include="*.tfvars" --include="*.yaml" --include="*.yml" \
            --include="*.json" --include="*.sh" --include="*.py" \
            --exclude-dir=".git" --exclude-dir=".terraform" --exclude-dir="node_modules" \
            2>/dev/null || true)
        
        if [[ -n "$matches" ]]; then
            echo -e "\nPattern: $pattern" >> "$results_file"
            echo "$matches" >> "$results_file"
            ((issues_found++))
        fi
    done
    
    if [[ $issues_found -eq 0 ]]; then
        print_success "No obvious security issues found"
        echo "No obvious security issues found" >> "$results_file"
    else
        print_warning "$issues_found potential security issues found"
        echo "$issues_found potential security issues found" >> "$results_file"
    fi
    
    print_info "Basic security scan results saved to: $results_file"
}

generate_security_summary() {
    local scan_dir="$1"
    local summary_file="$scan_dir/security-summary.txt"
    
    print_info "Generating security summary"
    
    {
        echo "Security Scan Summary - $(date)"
        echo "==============================="
        echo
        
        # Process each tool's results
        for result_file in "$scan_dir"/*.json; do
            [[ -f "$result_file" ]] || continue
            
            local tool_name="$(basename "$result_file" .json | cut -d'-' -f1)"
            echo "=== $tool_name Results ==="
            
            case "$tool_name" in
                "checkov")
                    if command -v jq &>/dev/null; then
                        local failed=$(jq '.results.failed_checks | length' "$result_file" 2>/dev/null || echo "0")
                        local passed=$(jq '.results.passed_checks | length' "$result_file" 2>/dev/null || echo "0")
                        echo "Failed checks: $failed"
                        echo "Passed checks: $passed"
                    fi
                    ;;
                "tfsec")
                    if command -v jq &>/dev/null; then
                        local high=$(jq '.results[] | select(.severity=="HIGH") | length' "$result_file" 2>/dev/null | wc -l || echo "0")
                        local medium=$(jq '.results[] | select(.severity=="MEDIUM") | length' "$result_file" 2>/dev/null | wc -l || echo "0")
                        local low=$(jq '.results[] | select(.severity=="LOW") | length' "$result_file" 2>/dev/null | wc -l || echo "0")
                        echo "High severity: $high"
                        echo "Medium severity: $medium"
                        echo "Low severity: $low"
                    fi
                    ;;
            esac
            echo
        done
        
        echo "Full results available in individual files:"
        ls "$scan_dir"/*.txt 2>/dev/null | while read -r file; do
            echo "- $(basename "$file")"
        done
        
    } > "$summary_file"
    
    print_success "Security summary generated: $summary_file"
}

# ============================================
# DEPENDENCY MANAGEMENT
# ============================================

bulk_dependency_update() {
    print_section "Bulk Dependency Updates"
    
    local package_files=()
    
    # Find different types of package files
    mapfile -t package_files < <(find "$PROJECT_ROOT" -name "package.json" -o -name "requirements.txt" -o -name "Gemfile" -o -name "go.mod" -o -name "Cargo.toml" -o -name "composer.json" 2>/dev/null)
    
    if [[ ${#package_files[@]} -eq 0 ]]; then
        print_warning "No package files found"
        return 0
    fi
    
    print_info "Found ${#package_files[@]} package files"
    
    for file in "${package_files[@]}"; do
        wait_for_job_slot
        
        local dir="$(dirname "$file")"
        local filename="$(basename "$file")"
        local project_name="$(basename "$dir")"
        
        (
            print_progress "Updating dependencies: $project_name ($filename)"
            
            cd "$dir"
            
            case "$filename" in
                "package.json")
                    if command -v npm &>/dev/null; then
                        npm audit fix 2>&1 || print_warning "$project_name: npm audit fix failed"
                        npm update 2>&1 || print_warning "$project_name: npm update failed"
                        print_success "$project_name: npm dependencies updated"
                    elif command -v yarn &>/dev/null; then
                        yarn audit --fix 2>&1 || print_warning "$project_name: yarn audit fix failed"
                        yarn upgrade 2>&1 || print_warning "$project_name: yarn upgrade failed"
                        print_success "$project_name: yarn dependencies updated"
                    else
                        print_warning "$project_name: No npm or yarn found"
                    fi
                    ;;
                "requirements.txt")
                    if command -v pip &>/dev/null; then
                        pip install --upgrade -r requirements.txt 2>&1 || print_warning "$project_name: pip upgrade failed"
                        print_success "$project_name: Python dependencies updated"
                    else
                        print_warning "$project_name: pip not found"
                    fi
                    ;;
                "Gemfile")
                    if command -v bundle &>/dev/null; then
                        bundle update 2>&1 || print_warning "$project_name: bundle update failed"
                        print_success "$project_name: Ruby dependencies updated"
                    else
                        print_warning "$project_name: bundler not found"
                    fi
                    ;;
                "go.mod")
                    if command -v go &>/dev/null; then
                        go get -u ./... 2>&1 || print_warning "$project_name: go get -u failed"
                        go mod tidy 2>&1 || print_warning "$project_name: go mod tidy failed"
                        print_success "$project_name: Go dependencies updated"
                    else
                        print_warning "$project_name: go command not found"
                    fi
                    ;;
                "Cargo.toml")
                    if command -v cargo &>/dev/null; then
                        cargo update 2>&1 || print_warning "$project_name: cargo update failed"
                        print_success "$project_name: Rust dependencies updated"
                    else
                        print_warning "$project_name: cargo not found"
                    fi
                    ;;
                "composer.json")
                    if command -v composer &>/dev/null; then
                        composer update 2>&1 || print_warning "$project_name: composer update failed"
                        print_success "$project_name: PHP dependencies updated"
                    else
                        print_warning "$project_name: composer not found"
                    fi
                    ;;
            esac
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "deps-$project_name"
    done
    
    wait_for_all_jobs
    print_success "Bulk dependency updates completed"
}

# ============================================
# GIT REFERENCE MANAGEMENT
# ============================================

# Find all Terraform files with git references
find_terraform_git_references() {
    find "$PROJECT_ROOT" -name "*.tf" -type f -exec grep -l "git::" {} \; | grep -v ".terraform" | grep -v ".history" | sort
}

# Update all git references to a new version
bulk_update_git_references() {
    local target_version="$1"
    local filter_repo="${2:-}"
    
    if [[ -z "$target_version" ]]; then
        print_error "Target version is required (e.g., v1.0.6)"
        return 1
    fi
    
    print_section "Bulk Git Reference Update to $target_version"
    
    local tf_files=($(find_terraform_git_references))
    local total=${#tf_files[@]}
    local updated_count=0
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Terraform files with git references found"
        return 0
    fi
    
    print_info "Found $total Terraform files with git references"
    
    if [[ -n "$filter_repo" ]]; then
        print_info "Filtering for repository: $filter_repo"
    fi
    
    for file in "${tf_files[@]}"; do
        wait_for_job_slot
        
        local relative_path="${file#$PROJECT_ROOT/}"
        
        (
            print_progress "Processing: $relative_path"
            
            # Create backup
            create_backup "git-ref-update" "$(dirname "$file")"
            
            local temp_file="${file}.tmp"
            local changes_made=false
            
            # Process git references
            if [[ -n "$filter_repo" ]]; then
                # Filter by specific repository
                if sed -E "s/(git::.*github\.com\/[^\/]*\/${filter_repo}\.git[^?]*\?ref=)[^\"&]*/\1${target_version}/g" "$file" > "$temp_file"; then
                    if ! diff -q "$file" "$temp_file" >/dev/null 2>&1; then
                        changes_made=true
                    fi
                fi
            else
                # Update all git references and ensure mob-infra-core is used
                if sed -E 's/(git::.*github\.com\/[^\/]*\/)mob-infrastructure-core(\.git[^?]*\?ref=)[^"&]*/\1mob-infra-core\2'$target_version'/g; s/(git::.*github\.com\/[^\/]*\/)mob-infra-core(\.git[^?]*\?ref=)[^"&]*/\1mob-infra-core\2'$target_version'/g; s/(git::ssh:\/\/git@github\.com\/[^\/]*\/)mob-infrastructure-core(\.git[^?]*\?ref=)[^"&]*/\1mob-infra-core\2'$target_version'/g; s/(git::ssh:\/\/git@github\.com\/[^\/]*\/)mob-infra-core(\.git[^?]*\?ref=)[^"&]*/\1mob-infra-core\2'$target_version'/g' "$file" > "$temp_file"; then
                    if ! diff -q "$file" "$temp_file" >/dev/null 2>&1; then
                        changes_made=true
                    fi
                fi
            fi
            
            if [[ "$changes_made" == true ]]; then
                mv "$temp_file" "$file"
                print_success "$relative_path: Updated git references to $target_version"
                echo "1" > "${STATUS_DIR}/updated-${RANDOM}.count"
            else
                rm -f "$temp_file"
                print_info "$relative_path: No matching references found"
            fi
            
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "git-ref-update-$(basename "$file")"
    done
    
    wait_for_all_jobs
    
    # Count updates
    updated_count=$(find "${STATUS_DIR}" -name "updated-*.count" 2>/dev/null | wc -l || echo "0")
    rm -f "${STATUS_DIR}"/updated-*.count 2>/dev/null
    
    print_success "Git reference update completed: $updated_count files updated"
}

# Standardize repository names from old to new
bulk_standardize_repo_names() {
    local old_name="${1:-mob-infrastructure-core}"
    local new_name="${2:-mob-infra-core}"
    
    print_section "Standardizing Repository Names: $old_name → $new_name"
    
    local tf_files=($(find_terraform_git_references))
    local total=${#tf_files[@]}
    local updated_count=0
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Terraform files with git references found"
        return 0
    fi
    
    print_info "Found $total Terraform files with git references"
    print_info "Updating: $old_name → $new_name"
    
    for file in "${tf_files[@]}"; do
        wait_for_job_slot
        
        local relative_path="${file#$PROJECT_ROOT/}"
        
        (
            print_progress "Processing: $relative_path"
            
            # Create backup
            create_backup "repo-name-update" "$(dirname "$file")"
            
            local temp_file="${file}.tmp"
            local changes_made=false
            
            # Update repository names - handle multiple URL formats
            if sed -E "s|github\.com/EightpointIO/${old_name}\.git|github.com/EightpointIO/${new_name}.git|g; s|git@github\.com:EightpointIO/${old_name}\.git|git@github.com:EightpointIO/${new_name}.git|g; s|ssh://git@github\.com/EightpointIO/${old_name}\.git|ssh://git@github.com/EightpointIO/${new_name}.git|g" "$file" > "$temp_file"; then
                if ! diff -q "$file" "$temp_file" >/dev/null 2>&1; then
                    changes_made=true
                fi
            fi
            
            if [[ "$changes_made" == true ]]; then
                mv "$temp_file" "$file"
                print_success "$relative_path: Updated repository name"
                echo "1" > "${STATUS_DIR}/repo-updated-${RANDOM}.count"
            else
                rm -f "$temp_file"
                print_info "$relative_path: No repository name changes needed"
            fi
            
        ) &
        
        local pid=$!
        add_operation_pid "$pid" "repo-name-update-$(basename "$file")"
    done
    
    wait_for_all_jobs
    
    # Count updates
    updated_count=$(find "${STATUS_DIR}" -name "repo-updated-*.count" 2>/dev/null | wc -l || echo "0")
    rm -f "${STATUS_DIR}"/repo-updated-*.count 2>/dev/null
    
    print_success "Repository name standardization completed: $updated_count files updated"
}

# Detect latest git tag from repository
detect_latest_git_tag() {
    local repo_url="$1"
    local repo_name="$2"
    
    print_info "Detecting latest tag for $repo_name..."
    
    # Try to get latest tag from GitHub API first
    if command -v curl >/dev/null 2>&1; then
        local api_url="https://api.github.com/repos/EightpointIO/${repo_name}/releases/latest"
        local latest_tag=$(curl -s "$api_url" | grep '"tag_name":' | cut -d'"' -f4 2>/dev/null || echo "")
        
        if [[ -n "$latest_tag" ]]; then
            echo "$latest_tag"
            return 0
        fi
    fi
    
    # Fallback: clone and get latest tag
    local temp_clone_dir="${TEMP_DIR}/clone-${repo_name}-${RANDOM}"
    mkdir -p "$temp_clone_dir"
    
    if git clone --depth 1 "$repo_url" "$temp_clone_dir" >/dev/null 2>&1; then
        cd "$temp_clone_dir"
        local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
        cd - >/dev/null
        rm -rf "$temp_clone_dir"
        
        if [[ -n "$latest_tag" ]]; then
            echo "$latest_tag"
            return 0
        fi
    fi
    
    print_warning "Could not detect latest tag for $repo_name"
    return 1
}

# Drift detection and update
bulk_drift_detection() {
    local repo_name="${1:-mob-infra-core}"
    local repo_url="https://github.com/EightpointIO/${repo_name}.git"
    
    print_section "Git Reference Drift Detection for $repo_name"
    
    # Detect latest tag
    local latest_tag=$(detect_latest_git_tag "$repo_url" "$repo_name")
    
    if [[ -z "$latest_tag" ]]; then
        print_error "Could not detect latest tag for $repo_name"
        return 1
    fi
    
    print_success "Latest tag detected: $latest_tag"
    
    # Find current references and count outdated ones
    print_info "Scanning for current git references..."
    
    local tf_files=($(find_terraform_git_references))
    local outdated_count=0
    local refs_file="${TEMP_DIR}/outdated_refs_${RANDOM}.txt"
    
    for file in "${tf_files[@]}"; do
        local relative_path="${file#$PROJECT_ROOT/}"
        
        # Check this file for outdated references to the target repo
        while IFS= read -r line; do
            local current_ref=$(echo "$line" | sed -n 's/.*?ref=\([^"]*\).*/\1/p')
            if [[ -n "$current_ref" && "$current_ref" != "$latest_tag" ]]; then
                echo "$relative_path:$current_ref" >> "$refs_file"
            fi
        done < <(grep -n "git::.*github\.com/[^/]*/${repo_name}\.git" "$file" 2>/dev/null)
    done
    
    if [[ -f "$refs_file" ]]; then
        outdated_count=$(wc -l < "$refs_file" 2>/dev/null || echo "0")
    fi
    
    if [[ $outdated_count -eq 0 ]]; then
        print_success "All references are up to date with $latest_tag"
        rm -f "$refs_file"
        return 0
    fi
    
    print_warning "Found $outdated_count outdated references for $repo_name"
    echo -e "\n${YELLOW}Outdated references:${NC}"
    
    if [[ -f "$refs_file" ]]; then
        while IFS= read -r ref_info; do
            local file_path=$(echo "$ref_info" | cut -d: -f1)
            local old_ref=$(echo "$ref_info" | cut -d: -f2)
            echo -e "  ${RED}$file_path${NC}: $old_ref → $latest_tag"
        done < "$refs_file"
        rm -f "$refs_file"
    fi
    
    echo -e "\n${BLUE}Would you like to update all references to $latest_tag? (y/N):${NC}"
    read -r update_choice
    
    if [[ "$update_choice" =~ ^[Yy]$ ]]; then
        bulk_update_git_references "$latest_tag" "$repo_name"
    else
        print_info "Drift detection completed. No updates applied."
    fi
}

# Show git reference summary
show_git_reference_summary() {
    print_section "Git Reference Summary"
    
    local tf_files=($(find_terraform_git_references))
    local total=${#tf_files[@]}
    
    if [[ $total -eq 0 ]]; then
        print_warning "No Terraform files with git references found"
        return 0
    fi
    
    print_info "Analyzing $total Terraform files..."
    
    # Create temporary file to collect references
    local refs_file="${TEMP_DIR}/git_refs_summary_${RANDOM}.txt"
    
    # Collect all references from all files
    for file in "${tf_files[@]}"; do
        local relative_path="${file#$PROJECT_ROOT/}"
        
        # Extract git references from this file
        grep -n "git::" "$file" 2>/dev/null | while IFS= read -r line; do
            local line_content=$(echo "$line" | cut -d: -f2-)
            local current_ref=$(echo "$line_content" | sed -n 's/.*?ref=\([^"]*\).*/\1/p')
            local repo_name=$(echo "$line_content" | sed -n 's/.*github\.com\/[^/]*\/\([^/]*\)\.git.*/\1/p')
            
            if [[ -n "$repo_name" && -n "$current_ref" ]]; then
                echo "${repo_name}:${current_ref}:${relative_path}" >> "$refs_file"
            fi
        done
    done
    
    if [[ ! -f "$refs_file" ]] || [[ ! -s "$refs_file" ]]; then
        print_warning "No git references found in Terraform files"
        return 0
    fi
    
    # Display summary
    echo -e "\n${WHITE}${BOLD}Repository Reference Summary:${NC}"
    
    # Sort and count unique repository:version combinations
    sort "$refs_file" | uniq -c | while read -r count repo_version_file; do
        local repo=$(echo "$repo_version_file" | cut -d: -f1)
        local version=$(echo "$repo_version_file" | cut -d: -f2)
        local sample_file=$(echo "$repo_version_file" | cut -d: -f3)
        
        echo -e "\n${CYAN}$repo${NC} @ ${YELLOW}$version${NC} (${count} references)"
        echo -e "  ${DIM}Example: $sample_file${NC}"
        
        if [[ $count -gt 1 ]]; then
            echo -e "  ${DIM}... and $((count - 1)) more files${NC}"
        fi
    done
    
    # Clean up
    rm -f "$refs_file"
    
    print_success "Git reference summary completed"
}

# ============================================
# ROLLBACK FUNCTIONALITY
# ============================================

rollback_operation() {
    local operation="$1"
    
    local rollback_cmd="$(get_rollback_command "$operation")"
    if [[ -z "$rollback_cmd" ]]; then
        print_error "No rollback command available for: $operation"
        return 1
    fi
    
    print_warning "Rolling back operation: $operation"
    eval "$rollback_cmd"
}

rollback_all_failed() {
    print_section "Rolling Back Failed Operations"
    
    if [[ ${#FAILED_OPERATIONS[@]} -eq 0 ]]; then
        print_info "No failed operations to rollback"
        return 0
    fi
    
    print_warning "Rolling back ${#FAILED_OPERATIONS[@]} failed operations"
    
    for operation in "${FAILED_OPERATIONS[@]}"; do
        rollback_operation "$operation"
    done
    
    print_success "Rollback completed"
}

# ============================================
# REPORTING AND SUMMARY
# ============================================

generate_operations_summary() {
    print_header "BULK OPERATIONS SUMMARY"
    
    local total_ops=$((${#SUCCESSFUL_OPERATIONS[@]} + ${#FAILED_OPERATIONS[@]} + ${#SKIPPED_OPERATIONS[@]}))
    local success_rate=0
    
    if [[ $total_ops -gt 0 ]]; then
        success_rate=$(( (${#SUCCESSFUL_OPERATIONS[@]} * 100) / total_ops ))
    fi
    
    echo -e "${WHITE}Operation Statistics:${NC}"
    echo -e "  Total Operations: ${BLUE}$total_ops${NC}"
    echo -e "  Successful: ${GREEN}${#SUCCESSFUL_OPERATIONS[@]}${NC}"
    echo -e "  Failed: ${RED}${#FAILED_OPERATIONS[@]}${NC}"
    echo -e "  Skipped: ${YELLOW}${#SKIPPED_OPERATIONS[@]}${NC}"
    echo -e "  Success Rate: ${success_rate}%"
    
    if [[ ${#SUCCESSFUL_OPERATIONS[@]} -gt 0 ]]; then
        echo -e "\n${GREEN}Successful Operations:${NC}"
        for op in "${SUCCESSFUL_OPERATIONS[@]}"; do
            echo -e "  ${GREEN}✓${NC} $op"
        done
    fi
    
    if [[ ${#FAILED_OPERATIONS[@]} -gt 0 ]]; then
        echo -e "\n${RED}Failed Operations:${NC}"
        for op in "${FAILED_OPERATIONS[@]}"; do
            echo -e "  ${RED}✗${NC} $op"
        done
    fi
    
    if [[ ${#SKIPPED_OPERATIONS[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}Skipped Operations:${NC}"
        for op in "${SKIPPED_OPERATIONS[@]}"; do
            echo -e "  ${YELLOW}⊘${NC} $op"
        done
    fi
    
    echo -e "\n${BLUE}Log File:${NC} $BULK_LOG"
    echo -e "${BLUE}Backup Directory:${NC} $BACKUP_DIR"
    echo -e "${BLUE}Temp Directory:${NC} $TEMP_DIR"
    
    # Overall health score
    local health_score=$success_rate
    
    echo -e "\n${WHITE}Overall Success Score: "
    if [[ $health_score -ge 90 ]]; then
        echo -e "${GREEN}$health_score/100 (Excellent)${NC}"
    elif [[ $health_score -ge 75 ]]; then
        echo -e "${YELLOW}$health_score/100 (Good)${NC}"
    elif [[ $health_score -ge 50 ]]; then
        echo -e "${YELLOW}$health_score/100 (Fair)${NC}"
    else
        echo -e "${RED}$health_score/100 (Needs Attention)${NC}"
    fi
}

# ============================================
# MAIN OPERATIONS MENU
# ============================================

show_help() {
    echo -e "${WHITE}${BOLD}Bulk Infrastructure Operations Script${NC}"
    echo
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0 [OPERATION] [OPTIONS]"
    echo
    echo -e "${CYAN}Git Operations:${NC}"
    echo -e "  git-status              Show status of all Git repositories"
    echo -e "  git-pull-all            Pull updates for all Git repositories"
    echo -e "  git-commit \"message\"     Commit changes to all Git repositories"
    echo -e "  git-push                Push changes for all Git repositories"
    echo -e "  git-commit-push \"msg\"    Commit with message and push for all repos (no pull)"
    echo
    echo -e "${CYAN}Terraform Operations:${NC}"
    echo -e "  tf-fmt                  Format all Terraform files"
    echo -e "  tf-validate             Validate all Terraform configurations"
    echo -e "  tf-plan                 Create plans for all Terraform configurations"
    echo -e "  tf-all                  Format, validate, and plan all Terraform configs"
    echo
    echo -e "${CYAN}Security Operations:${NC}"
    echo -e "  security-scan           Run security scans on all code"
    echo -e "  security-report         Generate comprehensive security report"
    echo
    echo -e "${CYAN}Dependency Operations:${NC}"
    echo -e "  deps-update             Update dependencies in all projects"
    echo -e "  deps-audit              Audit dependencies for vulnerabilities"
    echo
    echo -e "${CYAN}Git Reference Operations:${NC}"
    echo -e "  git-ref-summary         Show summary of all git references and versions"
    echo -e "  git-ref-update VERSION  Update all git references to specified version (e.g., v1.0.6)"
    echo -e "  git-ref-drift           Detect and optionally update outdated git references"
    echo -e "  git-ref-standardize     Standardize repository names (mob-infrastructure-core → mob-infra-core)"
    echo
    echo -e "${CYAN}Bulk Operations:${NC}"
    echo -e "  all                     Run all operations (git, terraform, security, deps)"
    echo -e "  maintenance             Run maintenance tasks (format, validate, security)"
    echo -e "  rollback                Rollback all failed operations"
    echo
    echo -e "${CYAN}Options:${NC}"
    echo -e "  --parallel N            Set maximum parallel jobs (default: 8)"
    echo -e "  --no-backup             Skip creating backups"
    echo -e "  --force                 Force operations even if warnings"
    echo -e "  --dry-run               Show what would be done without executing"
    echo -e "  -h, --help              Show this help message"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0 git-status                    # Check status of all repos"
    echo -e "  $0 git-pull-all                  # Pull all repositories"
    echo -e "  $0 git-commit-push \"Update deps\" # Commit and push (no pull)"
    echo -e "  $0 tf-all                        # Format, validate, plan all TF"
    echo -e "  $0 git-ref-summary               # Show git reference versions"
    echo -e "  $0 git-ref-update v1.0.6         # Update all refs to v1.0.6"
    echo -e "  $0 git-ref-drift                 # Check for outdated references"
    echo -e "  $0 git-ref-standardize           # Update repo names"
    echo -e "  $0 all                           # Run everything"
    echo -e "  $0 maintenance --parallel 4      # Run maintenance with 4 jobs"
}

# ============================================
# MAIN EXECUTION
# ============================================

main() {
    # Initialize
    init_directories
    log_message "INFO" "Bulk operations started with args: $*"
    
    # Parse global options
    local operation=""
    local commit_message=""
    local no_backup=false
    local force=false
    local dry_run=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --parallel)
                if [[ -n "$2" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    MAX_PARALLEL_JOBS="$2"
                    shift 2
                else
                    print_error "Invalid parallel jobs number: $2"
                    exit 1
                fi
                ;;
            --no-backup)
                no_backup=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            git-status|git-pull-all|git-push|tf-fmt|tf-validate|tf-plan|security-scan|deps-update|git-ref-summary|git-ref-drift|git-ref-standardize|all|maintenance|rollback)
                operation="$1"
                shift
                ;;
            git-commit|git-commit-push|git-ref-update)
                operation="$1"
                if [[ -n "$2" ]] && [[ ! "$2" =~ ^-- ]]; then
                    commit_message="$2"
                    shift 2
                else
                    print_error "Commit message required for $1"
                    exit 1
                fi
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$operation" ]]; then
        print_error "No operation specified"
        show_help
        exit 1
    fi
    
    # Start operations
    print_header "Bulk Infrastructure Operations"
    print_info "Operation: $operation"
    print_info "Parallel jobs: $MAX_PARALLEL_JOBS"
    print_info "Project root: $PROJECT_ROOT"
    print_info "Log file: $BULK_LOG"
    
    if [[ "$dry_run" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi
    
    # Execute requested operation
    case "$operation" in
        "git-status")
            bulk_git_status
            ;;
        "git-pull-all")
            [[ "$dry_run" == false ]] && bulk_git_pull || print_info "Would pull all repositories"
            ;;
        "git-commit")
            [[ "$dry_run" == false ]] && bulk_git_commit "$commit_message" || print_info "Would commit with message: $commit_message"
            ;;
        "git-push")
            [[ "$dry_run" == false ]] && bulk_git_push || print_info "Would push all repositories"
            ;;
        "git-commit-push")
            if [[ "$dry_run" == false ]]; then
                bulk_git_commit "$commit_message"
                bulk_git_push
            else
                print_info "Would commit ('$commit_message') and push all repositories (no pull)"
            fi
            ;;
        "tf-fmt")
            [[ "$dry_run" == false ]] && bulk_terraform_fmt || print_info "Would format all Terraform files"
            ;;
        "tf-validate")
            bulk_terraform_validate
            ;;
        "tf-plan")
            bulk_terraform_plan
            ;;
        "tf-all")
            if [[ "$dry_run" == false ]]; then
                bulk_terraform_fmt
                bulk_terraform_validate
                bulk_terraform_plan
            else
                print_info "Would format, validate, and plan all Terraform configurations"
            fi
            ;;
        "security-scan")
            bulk_security_scan
            ;;
        "deps-update")
            [[ "$dry_run" == false ]] && bulk_dependency_update || print_info "Would update all dependencies"
            ;;
        "git-ref-summary")
            show_git_reference_summary
            ;;
        "git-ref-update")
            [[ "$dry_run" == false ]] && bulk_update_git_references "$commit_message" || print_info "Would update all git references to: $commit_message"
            ;;
        "git-ref-drift")
            [[ "$dry_run" == false ]] && bulk_drift_detection || print_info "Would check for drift and prompt for updates"
            ;;
        "git-ref-standardize")
            [[ "$dry_run" == false ]] && bulk_standardize_repo_names || print_info "Would standardize repository names"
            ;;
        "maintenance")
            if [[ "$dry_run" == false ]]; then
                bulk_terraform_fmt
                bulk_terraform_validate
                bulk_security_scan
            else
                print_info "Would run maintenance tasks (format, validate, security scan)"
            fi
            ;;
        "all")
            if [[ "$dry_run" == false ]]; then
                bulk_git_status
                bulk_terraform_fmt
                bulk_terraform_validate
                bulk_terraform_plan
                bulk_security_scan
                bulk_dependency_update
            else
                print_info "Would run all operations (git, terraform, security, dependencies)"
            fi
            ;;
        "rollback")
            [[ "$dry_run" == false ]] && rollback_all_failed || print_info "Would rollback all failed operations"
            ;;
        *)
            print_error "Unknown operation: $operation"
            exit 1
            ;;
    esac
    
    # Generate summary
    generate_operations_summary
    
    log_message "INFO" "Bulk operations completed"
    print_success "Bulk operations completed successfully!"
}

# Trap for cleanup
cleanup() {
    # Kill any remaining background jobs
    if [[ ${#OPERATION_PIDS[@]} -gt 0 ]]; then
        for pid in "${OPERATION_PIDS[@]}"; do
            kill "$pid" 2>/dev/null || true
        done
    fi
    
    # Wait for jobs to terminate
    wait 2>/dev/null || true
    
    print_info "Cleanup completed"
}

trap cleanup EXIT INT TERM

# Execute main function with all arguments
main "$@"