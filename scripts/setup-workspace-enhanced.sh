#!/bin/bash

# Enhanced Infrastructure Workspace Management Script
# Automatically sets up and maintains the infrastructure workspace directory structure
# with advanced git status checking and repository health monitoring
# Usage: ./setup-workspace-enhanced.sh [command]
# Commands: setup, update, status, health, help

set -e

# Configuration - TEST ENVIRONMENT
WORKSPACE_ROOT="/Users/liviu/Desktop/infrastructure-test"
GITHUB_ORG="EightpointIO"
GITHUB_BASE_URL="https://github.com/${GITHUB_ORG}"

# Color codes for enhanced output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Repository mapping: "repo-name:local-path"
declare -a REPOSITORIES=(
    # Android repositories
    "android-infra-dev-eks:teams/android/dev/eks"
    "android-infra-dev-elastic-cache:teams/android/dev/elastic-cache"
    "android-infra-dev-network:teams/android/dev/network"
    "android-infra-dev-terraform-backend:teams/android/dev/terraform-backend"
    "android-infra-global-cloudwatch:teams/android/global/cloudwatch"
    "android-infra-global-network:teams/android/global/network"
    "android-infra-global-route53:teams/android/global/route53"
    "android-infra-global-ses:teams/android/global/ses"
    "android-infra-global-terraform-backend:teams/android/global/terraform-backend"
    "android-infra-global-eks-config:teams/android/global/eks-config"
    "android-infra-global-github-oidc:teams/android/global/github-oidc"
    "android-infra-prod-dns-email:teams/android/prod/dns-email"
    "android-infra-prod-network:teams/android/prod/network"
    "android-infra-prod-s3:teams/android/prod/s3"
    "android-infra-prod-s3-static-site:teams/android/prod/s3-static-site"
    "android-infra-prod-terraform-backend:teams/android/prod/terraform-backend"
    
    # iOS repositories
    "ios-infra-dev-aws-iot:teams/ios/dev/aws-iot"
    "ios-infra-dev-data-stores:teams/ios/dev/data-stores"
    "ios-infra-dev-eks:teams/ios/dev/eks"
    "ios-infra-dev-elastic-cache:teams/ios/dev/elastic-cache"
    "ios-infra-dev-lambda:teams/ios/dev/lambda"
    "ios-infra-dev-network:teams/ios/dev/network"
    "ios-infra-dev-queues:teams/ios/dev/queues"
    "ios-infra-dev-s3:teams/ios/dev/s3"
    "ios-infra-dev-secrets:teams/ios/dev/secrets"
    "ios-infra-dev-terraform-backend:teams/ios/dev/terraform-backend"
    "ios-infra-global-cloudwatch:teams/ios/global/cloudwatch"
    "ios-infra-global-data-stores:teams/ios/global/data-stores"
    "ios-infra-global-eks-config:teams/ios/global/eks-config"
    "ios-infra-global-github-oidc:teams/ios/global/github-oidc"
    "ios-infra-global-lambda:teams/ios/global/lambda"
    "ios-infra-global-network:teams/ios/global/network"
    "ios-infra-global-route53:teams/ios/global/route53"
    "ios-infra-global-ses:teams/ios/global/ses"
    "ios-infra-global-terraform-backend:teams/ios/global/terraform-backend"
    "ios-infra-prod-alarm-to-slack:teams/ios/prod/alarm-to-slack"
    "ios-infra-prod-aws-iot:teams/ios/prod/aws-iot"
    "ios-infra-prod-cloudwatch-dashboards:teams/ios/prod/cloudwatch-dashboards"
    "ios-infra-prod-cloudwatch-metrics:teams/ios/prod/cloudwatch-metrics"
    "ios-infra-prod-data-stores:teams/ios/prod/data-stores"
    "ios-infra-prod-dns-email:teams/ios/prod/dns-email"
    "ios-infra-prod-eks:teams/ios/prod/eks"
    "ios-infra-prod-elastic-cache:teams/ios/prod/elastic-cache"
    "ios-infra-prod-lambda:teams/ios/prod/lambda"
    "ios-infra-prod-network:teams/ios/prod/network"
    "ios-infra-prod-queues:teams/ios/prod/queues"
    "ios-infra-prod-s3:teams/ios/prod/s3"
    "ios-infra-prod-s3-static-site:teams/ios/prod/s3-static-site"
    "ios-infra-prod-secrets:teams/ios/prod/secrets"
    "ios-infra-prod-terraform-backend:teams/ios/prod/terraform-backend"
    
    # Shared repositories
    "mob-infrastructure-core:shared/mob-infrastructure-core"
    "mob-infrastructure-cicd:shared/mob-infrastructure-cicd"
)

# Enhanced logging functions
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

log_debug() {
    echo -e "${GRAY}[DEBUG]${NC} $1"
}

log_header() {
    echo -e "${BOLD}${WHITE}$1${NC}"
}

# Progress tracking
declare -i TOTAL_REPOS=0
declare -i CLONED_REPOS=0
declare -i UPDATED_REPOS=0
declare -i SKIPPED_REPOS=0
declare -i ERROR_REPOS=0

# Health scoring variables
declare -i HEALTHY_REPOS=0
declare -i WARNING_REPOS=0
declare -i CRITICAL_REPOS=0

# Helper functions
show_help() {
    cat << EOF
Enhanced Infrastructure Workspace Management Script

USAGE:
    ./setup-workspace-enhanced.sh [COMMAND]

COMMANDS:
    setup     Clone all repositories and set up workspace structure
    update    Update all existing repositories (git pull)
    status    Show enhanced status of all repositories
    health    Show repository health assessment with scoring
    help      Show this help message

EXAMPLES:
    # Initial setup for new developer
    ./setup-workspace-enhanced.sh setup
    
    # Update all repositories
    ./setup-workspace-enhanced.sh update
    
    # Check enhanced status of all repositories
    ./setup-workspace-enhanced.sh status
    
    # Show repository health assessment
    ./setup-workspace-enhanced.sh health

WORKSPACE STRUCTURE:
    ${WORKSPACE_ROOT}/
    ├── shared/
    │   ├── mob-infrastructure-core/
    │   └── mob-infrastructure-cicd/
    └── teams/
        ├── android/
        │   ├── dev/
        │   ├── global/
        │   └── prod/
        └── ios/
            ├── dev/
            ├── global/
            └── prod/

ENHANCED FEATURES:
    • Advanced git status checking with ahead/behind counts
    • Uncommitted changes detection with file counts
    • Untracked files detection and summary
    • Last commit information with author and date
    • Color-coded output for quick visual scanning
    • Repository health scoring system
    • Detailed error handling and reporting
    • Progress indicators and statistics

EOF
}

# Check if git is available
check_prerequisites() {
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI (gh) is not installed. You may need to authenticate manually."
    fi
}

# Create workspace directory structure
setup_workspace_structure() {
    log_info "Creating workspace directory structure..."
    
    # Create main directories
    mkdir -p "$WORKSPACE_ROOT"/shared
    mkdir -p "$WORKSPACE_ROOT"/teams/{android,ios}/{dev,global,prod}
    
    log_success "Workspace structure created at: $WORKSPACE_ROOT"
}

# Get git status details for a repository
get_git_details() {
    local repo_path="$1"
    local details=""
    
    if [ ! -d "$repo_path/.git" ]; then
        echo "NOT_A_REPO"
        return
    fi
    
    cd "$repo_path" || return
    
    # Basic git info
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local remote_exists=$(git remote -v 2>/dev/null | grep -q origin && echo "yes" || echo "no")
    
    # Get ahead/behind counts
    local ahead=0
    local behind=0
    if [ "$remote_exists" = "yes" ]; then
        git fetch origin &>/dev/null || true
        ahead=$(git rev-list --count HEAD..origin/"$current_branch" 2>/dev/null | head -1 | tr -d '\n' || echo "0")
        behind=$(git rev-list --count origin/"$current_branch"..HEAD 2>/dev/null | head -1 | tr -d '\n' || echo "0")
        # Ensure they are numeric
        [[ "$ahead" =~ ^[0-9]+$ ]] || ahead=0
        [[ "$behind" =~ ^[0-9]+$ ]] || behind=0
    fi
    
    # Get uncommitted changes
    local modified_files=$(git status --porcelain 2>/dev/null | grep -c "^.M" || echo "0")
    local added_files=$(git status --porcelain 2>/dev/null | grep -c "^A" || echo "0")
    local deleted_files=$(git status --porcelain 2>/dev/null | grep -c "^.D" || echo "0")
    local renamed_files=$(git status --porcelain 2>/dev/null | grep -c "^R" || echo "0")
    
    # Get untracked files
    local untracked_files=$(git status --porcelain 2>/dev/null | grep -c "^??" || echo "0")
    
    # Ensure all counts are numeric
    [[ "$modified_files" =~ ^[0-9]+$ ]] || modified_files=0
    [[ "$added_files" =~ ^[0-9]+$ ]] || added_files=0
    [[ "$deleted_files" =~ ^[0-9]+$ ]] || deleted_files=0
    [[ "$renamed_files" =~ ^[0-9]+$ ]] || renamed_files=0
    [[ "$untracked_files" =~ ^[0-9]+$ ]] || untracked_files=0
    
    # Get last commit info
    local last_commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local last_commit_author=$(git log -1 --pretty=format:"%an" 2>/dev/null || echo "unknown")
    local last_commit_date=$(git log -1 --pretty=format:"%cr" 2>/dev/null || echo "unknown")
    local last_commit_message=$(git log -1 --pretty=format:"%s" 2>/dev/null | cut -c1-50 || echo "unknown")
    
    # Calculate health score (0-100)
    local health_score=100
    
    # Deduct points for issues
    [ "$behind" -gt 0 ] && health_score=$((health_score - 20))
    [ "$ahead" -gt 5 ] && health_score=$((health_score - 10))
    [ "$modified_files" -gt 0 ] && health_score=$((health_score - 15))
    [ "$untracked_files" -gt 0 ] && health_score=$((health_score - 10))
    [ "$added_files" -gt 0 ] && health_score=$((health_score - 5))
    [ "$deleted_files" -gt 0 ] && health_score=$((health_score - 10))
    [ "$current_branch" != "main" ] && health_score=$((health_score - 15))
    
    # Ensure score doesn't go below 0
    [ "$health_score" -lt 0 ] && health_score=0
    
    echo "BRANCH:$current_branch"
    echo "AHEAD:$ahead"
    echo "BEHIND:$behind"
    echo "MODIFIED:$modified_files"
    echo "ADDED:$added_files"
    echo "DELETED:$deleted_files"
    echo "RENAMED:$renamed_files"
    echo "UNTRACKED:$untracked_files"
    echo "LAST_COMMIT_HASH:$last_commit_hash"
    echo "LAST_COMMIT_AUTHOR:$last_commit_author"
    echo "LAST_COMMIT_DATE:$last_commit_date"
    echo "LAST_COMMIT_MESSAGE:$last_commit_message"
    echo "HEALTH_SCORE:$health_score"
    echo "REMOTE_EXISTS:$remote_exists"
}

# Parse git details output
parse_git_details() {
    local details="$1"
    local key="$2"
    echo "$details" | grep "^$key:" | cut -d':' -f2-
}

# Get health status color and label
get_health_status() {
    local score="$1"
    
    if [ "$score" -ge 80 ]; then
        echo "${GREEN}HEALTHY${NC}"
        HEALTHY_REPOS=$((HEALTHY_REPOS + 1))
    elif [ "$score" -ge 60 ]; then
        echo "${YELLOW}WARNING${NC}"
        WARNING_REPOS=$((WARNING_REPOS + 1))
    else
        echo "${RED}CRITICAL${NC}"
        CRITICAL_REPOS=$((CRITICAL_REPOS + 1))
    fi
}

# Clone or update a single repository
process_repository() {
    local repo_mapping="$1"
    local repo_name=$(echo "$repo_mapping" | cut -d':' -f1)
    local local_path=$(echo "$repo_mapping" | cut -d':' -f2)
    local full_path="$WORKSPACE_ROOT/$local_path"
    local repo_url="$GITHUB_BASE_URL/$repo_name.git"
    
    TOTAL_REPOS=$((TOTAL_REPOS + 1))
    
    echo ""
    log_info "Processing: $repo_name → $local_path"
    
    if [ -d "$full_path" ]; then
        if [ -d "$full_path/.git" ]; then
            # Repository exists, update it
            log_info "Repository exists, updating..."
            
            cd "$full_path"
            local current_branch=$(git branch --show-current 2>/dev/null || echo "main")
            
            # Fetch latest changes
            if git fetch origin &>/dev/null; then
                # Check if we're on main branch
                if [ "$current_branch" = "main" ]; then
                    if git pull origin main &>/dev/null; then
                        log_success "Updated $repo_name"
                        UPDATED_REPOS=$((UPDATED_REPOS + 1))
                    else
                        log_warning "Failed to pull updates for $repo_name"
                        ERROR_REPOS=$((ERROR_REPOS + 1))
                    fi
                else
                    log_warning "Repository $repo_name is on branch '$current_branch', not updating"
                    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
                fi
            else
                log_warning "Failed to fetch updates for $repo_name"
                ERROR_REPOS=$((ERROR_REPOS + 1))
            fi
        else
            log_warning "Directory exists but is not a git repository: $full_path"
            SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
        fi
    else
        # Repository doesn't exist, clone it
        log_info "Cloning repository..."
        
        # Create parent directory
        mkdir -p "$(dirname "$full_path")"
        
        if git clone "$repo_url" "$full_path" &>/dev/null; then
            log_success "Cloned $repo_name"
            CLONED_REPOS=$((CLONED_REPOS + 1))
        else
            log_error "Failed to clone $repo_name from $repo_url"
            ERROR_REPOS=$((ERROR_REPOS + 1))
        fi
    fi
}

# Show enhanced repository status
show_repository_status() {
    local repo_mapping="$1"
    local repo_name=$(echo "$repo_mapping" | cut -d':' -f1)
    local local_path=$(echo "$repo_mapping" | cut -d':' -f2)
    local full_path="$WORKSPACE_ROOT/$local_path"
    
    printf "%-40s " "$repo_name"
    
    if [ -d "$full_path/.git" ]; then
        local git_details=$(get_git_details "$full_path")
        
        if [ "$git_details" = "NOT_A_REPO" ]; then
            printf "${YELLOW}NOT A GIT REPO${NC}\n"
            return
        fi
        
        local branch=$(parse_git_details "$git_details" "BRANCH")
        local ahead=$(parse_git_details "$git_details" "AHEAD")
        local behind=$(parse_git_details "$git_details" "BEHIND")
        local modified=$(parse_git_details "$git_details" "MODIFIED")
        local untracked=$(parse_git_details "$git_details" "UNTRACKED")
        local health_score=$(parse_git_details "$git_details" "HEALTH_SCORE")
        
        # Status indicator
        local total_changes=$((modified + untracked))
        if [ "$total_changes" -gt 0 ]; then
            printf "${YELLOW}MODIFIED${NC} "
        else
            printf "${GREEN}CLEAN${NC}   "
        fi
        
        # Branch info
        if [ "$branch" = "main" ]; then
            printf "Branch: ${GREEN}%-12s${NC} " "$branch"
        else
            printf "Branch: ${YELLOW}%-12s${NC} " "$branch"
        fi
        
        # Sync status
        local sync_status=""
        if [ "$behind" -gt 0 ]; then
            sync_status="${sync_status}${RED}↓$behind${NC} "
        fi
        if [ "$ahead" -gt 0 ]; then
            sync_status="${sync_status}${YELLOW}↑$ahead${NC} "
        fi
        if [ -z "$sync_status" ]; then
            sync_status="${GREEN}✓${NC} "
        fi
        
        printf "Sync: %-15s " "$sync_status"
        
        # Changes summary
        if [ "$total_changes" -gt 0 ]; then
            printf "Changes: ${YELLOW}$total_changes${NC} "
        fi
        
        echo ""
    elif [ -d "$full_path" ]; then
        printf "${YELLOW}NOT A GIT REPO${NC}\n"
    else
        printf "${RED}MISSING${NC}\n"
    fi
}

# Show detailed repository health assessment
show_repository_health() {
    local repo_mapping="$1"
    local repo_name=$(echo "$repo_mapping" | cut -d':' -f1)
    local local_path=$(echo "$repo_mapping" | cut -d':' -f2)
    local full_path="$WORKSPACE_ROOT/$local_path"
    
    printf "%-40s " "$repo_name"
    
    if [ -d "$full_path/.git" ]; then
        local git_details=$(get_git_details "$full_path")
        
        if [ "$git_details" = "NOT_A_REPO" ]; then
            printf "${YELLOW}NOT A GIT REPO${NC}\n"
            return
        fi
        
        local branch=$(parse_git_details "$git_details" "BRANCH")
        local ahead=$(parse_git_details "$git_details" "AHEAD")
        local behind=$(parse_git_details "$git_details" "BEHIND")
        local modified=$(parse_git_details "$git_details" "MODIFIED")
        local added=$(parse_git_details "$git_details" "ADDED")
        local deleted=$(parse_git_details "$git_details" "DELETED")
        local untracked=$(parse_git_details "$git_details" "UNTRACKED")
        local health_score=$(parse_git_details "$git_details" "HEALTH_SCORE")
        local last_commit_author=$(parse_git_details "$git_details" "LAST_COMMIT_AUTHOR")
        local last_commit_date=$(parse_git_details "$git_details" "LAST_COMMIT_DATE")
        local last_commit_hash=$(parse_git_details "$git_details" "LAST_COMMIT_HASH")
        
        # Health status
        local health_status=$(get_health_status "$health_score")
        printf "%-15s Score: %3d " "$health_status" "$health_score"
        
        # Branch status
        if [ "$branch" = "main" ]; then
            printf "Branch: ${GREEN}$branch${NC} "
        else
            printf "Branch: ${YELLOW}$branch${NC} "
        fi
        
        # Show issues
        local issues=""
        [ "$behind" -gt 0 ] && issues="${issues}Behind:$behind "
        [ "$ahead" -gt 0 ] && issues="${issues}Ahead:$ahead "
        [ "$modified" -gt 0 ] && issues="${issues}Modified:$modified "
        [ "$untracked" -gt 0 ] && issues="${issues}Untracked:$untracked "
        [ "$added" -gt 0 ] && issues="${issues}Added:$added "
        [ "$deleted" -gt 0 ] && issues="${issues}Deleted:$deleted "
        
        if [ -n "$issues" ]; then
            printf "${YELLOW}Issues: %s${NC}" "$issues"
        else
            printf "${GREEN}No issues${NC}"
        fi
        
        echo ""
        
        # Show last commit info
        printf "%-40s ${GRAY}Last: %s (%s) - %s${NC}\n" "" "$last_commit_hash" "$last_commit_date" "$last_commit_author"
        
    elif [ -d "$full_path" ]; then
        printf "${YELLOW}NOT A GIT REPO${NC}\n"
    else
        printf "${RED}MISSING${NC}\n"
    fi
}

# Main execution functions
setup_workspace() {
    log_header "=== ENHANCED WORKSPACE SETUP ==="
    log_info "Setting up infrastructure workspace..."
    log_info "Target directory: $WORKSPACE_ROOT"
    
    check_prerequisites
    setup_workspace_structure
    
    log_info "Processing ${#REPOSITORIES[@]} repositories..."
    
    for repo_mapping in "${REPOSITORIES[@]}"; do
        process_repository "$repo_mapping"
    done
    
    echo ""
    log_header "=================================="
    log_header "         SETUP COMPLETE"
    log_header "=================================="
    log_success "Total repositories: $TOTAL_REPOS"
    log_success "Newly cloned: $CLONED_REPOS"
    log_success "Updated existing: $UPDATED_REPOS"
    log_warning "Skipped: $SKIPPED_REPOS"
    log_error "Errors: $ERROR_REPOS"
    
    if [ $ERROR_REPOS -gt 0 ]; then
        echo ""
        log_warning "Some repositories had errors. Check the output above for details."
        log_warning "You may need to manually clone missing repositories or check your GitHub access."
    fi
}

update_workspace() {
    log_header "=== ENHANCED WORKSPACE UPDATE ==="
    log_info "Updating infrastructure workspace..."
    
    check_prerequisites
    
    log_info "Updating ${#REPOSITORIES[@]} repositories..."
    
    for repo_mapping in "${REPOSITORIES[@]}"; do
        process_repository "$repo_mapping"
    done
    
    echo ""
    log_header "=================================="
    log_header "         UPDATE COMPLETE"
    log_header "=================================="
    log_success "Total repositories: $TOTAL_REPOS"
    log_success "Updated: $UPDATED_REPOS"
    log_warning "Skipped: $SKIPPED_REPOS"
    log_error "Errors: $ERROR_REPOS"
}

show_workspace_status() {
    log_header "=== ENHANCED WORKSPACE STATUS ==="
    log_info "Infrastructure Workspace Status"
    log_info "Workspace: $WORKSPACE_ROOT"
    echo ""
    
    printf "${BOLD}%-40s %-10s %-20s %-20s %s${NC}\n" "REPOSITORY" "STATUS" "BRANCH" "SYNC" "CHANGES"
    printf "%-40s %-10s %-20s %-20s %s\n" "$(printf '%*s' 40 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')" "$(printf '%*s' 20 | tr ' ' '-')" "$(printf '%*s' 20 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')"
    
    for repo_mapping in "${REPOSITORIES[@]}"; do
        show_repository_status "$repo_mapping"
    done
    
    echo ""
    log_info "Legend: ${GREEN}✓${NC} = synced, ${RED}↓n${NC} = behind by n commits, ${YELLOW}↑n${NC} = ahead by n commits"
}

show_workspace_health() {
    log_header "=== REPOSITORY HEALTH ASSESSMENT ==="
    log_info "Infrastructure Workspace Health Report"
    log_info "Workspace: $WORKSPACE_ROOT"
    echo ""
    
    # Reset counters
    HEALTHY_REPOS=0
    WARNING_REPOS=0
    CRITICAL_REPOS=0
    
    printf "${BOLD}%-40s %-15s %-20s %s${NC}\n" "REPOSITORY" "HEALTH" "BRANCH" "ISSUES"
    printf "%-40s %-15s %-20s %s\n" "$(printf '%*s' 40 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 20 | tr ' ' '-')" "$(printf '%*s' 30 | tr ' ' '-')"
    
    for repo_mapping in "${REPOSITORIES[@]}"; do
        show_repository_health "$repo_mapping"
    done
    
    echo ""
    log_header "=== HEALTH SUMMARY ==="
    local total_assessed=$((HEALTHY_REPOS + WARNING_REPOS + CRITICAL_REPOS))
    log_success "Healthy repositories: $HEALTHY_REPOS"
    log_warning "Repositories needing attention: $WARNING_REPOS"
    log_error "Critical repositories: $CRITICAL_REPOS"
    
    if [ "$total_assessed" -gt 0 ]; then
        local healthy_percent=$((HEALTHY_REPOS * 100 / total_assessed))
        echo ""
        log_info "Overall workspace health: ${healthy_percent}%"
        
        if [ "$healthy_percent" -ge 80 ]; then
            log_success "Workspace is in excellent condition!"
        elif [ "$healthy_percent" -ge 60 ]; then
            log_warning "Workspace needs some attention"
        else
            log_error "Workspace requires immediate attention"
        fi
    fi
    
    echo ""
    log_info "Health Score Legend:"
    log_info "  ${GREEN}80-100${NC}: Healthy - Repository is well maintained"
    log_info "  ${YELLOW}60-79${NC}:  Warning - Repository needs attention"
    log_info "  ${RED}0-59${NC}:   Critical - Repository requires immediate action"
}

# Main script execution
main() {
    local command="${1:-help}"
    
    case "$command" in
        setup)
            setup_workspace
            ;;
        update)
            update_workspace
            ;;
        status)
            show_workspace_status
            ;;
        health)
            show_workspace_health
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run the script
main "$@"