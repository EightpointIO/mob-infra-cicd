#!/bin/bash

# Infrastructure Workspace Management Script
# Automatically sets up and maintains the infrastructure workspace directory structure
# Usage: ./setup-workspace.sh [command]
# Commands: setup, update, status, help

set -e

# Configuration
WORKSPACE_ROOT="/Users/liviu/Developer/infrastructure"
GITHUB_ORG="EightpointIO"
GITHUB_BASE_URL="https://github.com/${GITHUB_ORG}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    "mob-infrastructure-cicd:mob-infrastructure-cicd"
)

# Logging functions
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

# Progress tracking
declare -i TOTAL_REPOS=0
declare -i CLONED_REPOS=0
declare -i UPDATED_REPOS=0
declare -i SKIPPED_REPOS=0
declare -i ERROR_REPOS=0

# Helper functions
show_help() {
    cat << EOF
Infrastructure Workspace Management Script

USAGE:
    ./setup-workspace.sh [COMMAND]

COMMANDS:
    setup     Clone all repositories and set up workspace structure
    update    Update all existing repositories (git pull)
    status    Show status of all repositories
    help      Show this help message

EXAMPLES:
    # Initial setup for new developer
    ./setup-workspace.sh setup
    
    # Update all repositories
    ./setup-workspace.sh update
    
    # Check status of all repositories
    ./setup-workspace.sh status

WORKSPACE STRUCTURE:
    ${WORKSPACE_ROOT}/
    ├── shared/
    │   └── mob-infrastructure-core/
    ├── mob-infrastructure-cicd/
    └── teams/
        ├── android/
        │   ├── dev/
        │   ├── global/
        │   └── prod/
        └── ios/
            ├── dev/
            ├── global/
            └── prod/

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
    mkdir -p "$WORKSPACE_ROOT"/{shared,teams/{android,ios}/{dev,global,prod}}
    
    log_success "Workspace structure created at: $WORKSPACE_ROOT"
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

# Show repository status
show_repository_status() {
    local repo_mapping="$1"
    local repo_name=$(echo "$repo_mapping" | cut -d':' -f1)
    local local_path=$(echo "$repo_mapping" | cut -d':' -f2)
    local full_path="$WORKSPACE_ROOT/$local_path"
    
    printf "%-40s " "$repo_name"
    
    if [ -d "$full_path/.git" ]; then
        cd "$full_path"
        local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        local status=$(git status --porcelain 2>/dev/null)
        local behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
        local ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
        
        if [ -n "$status" ]; then
            printf "${YELLOW}MODIFIED${NC} "
        else
            printf "${GREEN}CLEAN${NC}   "
        fi
        
        printf "Branch: %-15s " "$current_branch"
        
        if [ "$behind" != "0" ] && [ "$behind" != "?" ]; then
            printf "${RED}Behind: $behind${NC} "
        fi
        
        if [ "$ahead" != "0" ] && [ "$ahead" != "?" ]; then
            printf "${YELLOW}Ahead: $ahead${NC} "
        fi
        
        echo ""
    elif [ -d "$full_path" ]; then
        printf "${YELLOW}NOT A GIT REPO${NC}\n"
    else
        printf "${RED}MISSING${NC}\n"
    fi
}

# Main execution functions
setup_workspace() {
    log_info "Setting up infrastructure workspace..."
    log_info "Target directory: $WORKSPACE_ROOT"
    
    check_prerequisites
    setup_workspace_structure
    
    log_info "Processing ${#REPOSITORIES[@]} repositories..."
    
    for repo_mapping in "${REPOSITORIES[@]}"; do
        process_repository "$repo_mapping"
    done
    
    echo ""
    echo "=================================="
    log_info "SETUP COMPLETE"
    echo "=================================="
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
    log_info "Updating infrastructure workspace..."
    
    check_prerequisites
    
    log_info "Updating ${#REPOSITORIES[@]} repositories..."
    
    for repo_mapping in "${REPOSITORIES[@]}"; do
        process_repository "$repo_mapping"
    done
    
    echo ""
    echo "=================================="
    log_info "UPDATE COMPLETE"
    echo "=================================="
    log_success "Total repositories: $TOTAL_REPOS"
    log_success "Updated: $UPDATED_REPOS"
    log_warning "Skipped: $SKIPPED_REPOS"
    log_error "Errors: $ERROR_REPOS"
}

show_workspace_status() {
    log_info "Infrastructure Workspace Status"
    log_info "Workspace: $WORKSPACE_ROOT"
    echo ""
    
    printf "%-40s %-10s %-20s %s\n" "REPOSITORY" "STATUS" "BRANCH" "SYNC"
    printf "%-40s %-10s %-20s %s\n" "$(printf '%*s' 40 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')" "$(printf '%*s' 20 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')"
    
    for repo_mapping in "${REPOSITORIES[@]}"; do
        show_repository_status "$repo_mapping"
    done
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