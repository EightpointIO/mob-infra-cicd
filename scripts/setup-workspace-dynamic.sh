#!/bin/bash

# Dynamic Infrastructure Workspace Setup Script
# Enhanced version that uses dynamic repository discovery instead of hardcoded lists
# Automatically detects new repositories and organizes them properly

set -euo pipefail

# Color definitions for beautiful CLI
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="${SCRIPT_DIR}/logs/setup-workspace-$(date +%Y%m%d-%H%M%S).log"
readonly DISCOVERY_SCRIPT="${SCRIPT_DIR}/dynamic-repo-discovery.sh"

# Default configuration
readonly DEFAULT_ORG="your-github-org"
readonly DEFAULT_BASE_URL="git@github.com"
readonly WORKSPACE_CONFIG_FILE="${WORKSPACE_DIR}/infrastructure-workspace.code-workspace"

# Workspace structure
readonly TEAMS_DIR="${WORKSPACE_DIR}/teams"
readonly SHARED_DIR="${WORKSPACE_DIR}/shared"

# Usage information
usage() {
    cat << EOF
${WHITE}Dynamic Infrastructure Workspace Setup${NC}

${CYAN}DESCRIPTION:${NC}
    Enhanced workspace setup that automatically discovers infrastructure repositories
    using the GitHub API and organizes them in a proper directory structure.

${CYAN}USAGE:${NC}
    $SCRIPT_NAME [OPTIONS]

${CYAN}OPTIONS:${NC}
    -o, --org ORG              GitHub organization (default: $DEFAULT_ORG)
    -u, --base-url URL         Git base URL (default: $DEFAULT_BASE_URL)
    -t, --team TEAM            Setup only specific team repositories
    -e, --env ENVIRONMENT      Setup only specific environment
    -d, --dry-run              Show what would be done without executing
    -f, --force                Force re-clone existing repositories
    -p, --parallel JOBS        Number of parallel clone operations [default: 4]
    -s, --skip-vscode          Skip VS Code workspace configuration
    -v, --verbose              Verbose output
    -h, --help                 Show this help message

${CYAN}EXAMPLES:${NC}
    $SCRIPT_NAME                                    # Setup all infrastructure repos
    $SCRIPT_NAME --team ios                         # Setup only iOS repos
    $SCRIPT_NAME --org myorg --parallel 8          # Use custom org with 8 parallel jobs
    $SCRIPT_NAME --dry-run --verbose                # Preview with verbose output

${CYAN}AUTHENTICATION:${NC}
    Set GITHUB_TOKEN environment variable for repository discovery.
    Ensure SSH keys are configured for Git operations.

EOF
}

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR")   echo -e "${RED}✗ $message${NC}" >&2 ;;
        "WARN")    echo -e "${YELLOW}⚠ $message${NC}" >&2 ;;
        "INFO")    [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${GREEN}ℹ $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✓ $message${NC}" ;;
        "DEBUG")   [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${PURPLE}🔍 $message${NC}" ;;
        "DRY_RUN") echo -e "${CYAN}[DRY RUN] $message${NC}" ;;
    esac
}

# Progress indicator with spinner
show_spinner() {
    local pid=$1
    local message="$2"
    local spin='-\|/'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${CYAN}%s ${spin:$i:1}${NC}" "$message"
        sleep 0.1
    done
    printf "\r"
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local desc="${3:-Processing}"
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}%s${NC} [" "$desc"
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $empty | tr ' ' '░'
    printf "] %d%% (%d/%d)" $percentage $current $total
}

# Initialize environment
init_environment() {
    mkdir -p "$TEAMS_DIR" "$SHARED_DIR" "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    log "INFO" "Initialized workspace environment"
    log "INFO" "Workspace directory: $WORKSPACE_DIR"
    log "INFO" "Teams directory: $TEAMS_DIR"
    log "INFO" "Shared directory: $SHARED_DIR"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for discovery script
    if [[ ! -x "$DISCOVERY_SCRIPT" ]]; then
        log "ERROR" "Discovery script not found or not executable: $DISCOVERY_SCRIPT"
        echo -e "${RED}Required dependency missing:${NC} dynamic-repo-discovery.sh"
        exit 1
    fi
    
    # Check for git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    # Check for jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        echo -e "${RED}Missing dependencies:${NC} ${missing_deps[*]}"
        echo -e "Please install them and try again."
        exit 1
    fi
    
    log "SUCCESS" "All dependencies are available"
}

# Discover repositories
discover_repositories() {
    local org="$1"
    local team_filter="${2:-}"
    local env_filter="${3:-}"
    
    log "INFO" "Discovering repositories for organization: $org"
    
    local discovery_args=("--org" "$org" "--format" "json")
    
    [[ -n "$team_filter" ]] && discovery_args+=("--team" "$team_filter")
    [[ -n "$env_filter" ]] && discovery_args+=("--env" "$env_filter")
    [[ "${VERBOSE:-false}" == "true" ]] && discovery_args+=("--verbose")
    
    local discovery_output
    discovery_output=$("$DISCOVERY_SCRIPT" "${discovery_args[@]}" 2>/dev/null) || {
        log "ERROR" "Failed to discover repositories"
        echo -e "${RED}Repository discovery failed!${NC}"
        echo -e "Please check your GitHub authentication and try again."
        exit 1
    }
    
    echo "$discovery_output"
}

# Parse repository information
parse_repo_structure() {
    local repo_data="$1"
    
    # Parse with jq and create structured data
    echo "$repo_data" | jq -r '.repositories[] | "\(.name)|\(.team)|\(.environment)|\(.resource)|\(.type)"'
}

# Get repository directory path
get_repo_path() {
    local repo_name="$1"
    local team="$2"
    local environment="$3"
    local resource="$4"
    local type="$5"
    
    if [[ "$type" == "exception" ]]; then
        echo "${SHARED_DIR}/${repo_name}"
    else
        echo "${TEAMS_DIR}/${team}/${environment}/${resource}"
    fi
}

# Clone or update repository
clone_or_update_repo() {
    local repo_name="$1"
    local org="$2"
    local base_url="$3"
    local target_path="$4"
    local force_update="${5:-false}"
    local dry_run="${6:-false}"
    
    local repo_url="${base_url}:${org}/${repo_name}.git"
    
    if [[ "$dry_run" == "true" ]]; then
        if [[ -d "$target_path" ]]; then
            log "DRY_RUN" "Would update existing repository: $target_path"
        else
            log "DRY_RUN" "Would clone repository: $repo_url -> $target_path"
        fi
        return 0
    fi
    
    # Create parent directory
    mkdir -p "$(dirname "$target_path")"
    
    if [[ -d "$target_path" ]]; then
        if [[ "$force_update" == "true" ]]; then
            log "INFO" "Force updating repository: $repo_name"
            rm -rf "$target_path"
        else
            log "INFO" "Updating existing repository: $repo_name"
            (
                cd "$target_path"
                git fetch --all --prune >/dev/null 2>&1 || {
                    log "WARN" "Failed to fetch updates for $repo_name"
                    return 1
                }
                git reset --hard origin/main >/dev/null 2>&1 || \
                git reset --hard origin/master >/dev/null 2>&1 || {
                    log "WARN" "Failed to reset $repo_name to latest"
                    return 1
                }
            )
            log "SUCCESS" "Updated repository: $repo_name"
            return 0
        fi
    fi
    
    log "INFO" "Cloning repository: $repo_name"
    git clone "$repo_url" "$target_path" >/dev/null 2>&1 || {
        log "ERROR" "Failed to clone repository: $repo_name"
        return 1
    }
    
    log "SUCCESS" "Cloned repository: $repo_name"
}

# Process repositories in parallel
process_repositories() {
    local repo_data="$1"
    local org="$2"
    local base_url="$3"
    local parallel_jobs="$4"
    local force_update="$5"
    local dry_run="$6"
    
    local repo_list
    repo_list=$(parse_repo_structure "$repo_data")
    
    local total_repos
    total_repos=$(echo "$repo_list" | wc -l | tr -d ' ')
    
    if [[ $total_repos -eq 0 ]]; then
        log "WARN" "No repositories found to process"
        return 0
    fi
    
    log "INFO" "Processing $total_repos repositories with $parallel_jobs parallel jobs"
    
    local current=0
    local pids=()
    local repo_names=()
    
    while IFS='|' read -r repo_name team environment resource type; do
        [[ -z "$repo_name" ]] && continue
        
        ((current++))
        show_progress $current $total_repos "Processing repositories"
        
        local target_path
        target_path=$(get_repo_path "$repo_name" "$team" "$environment" "$resource" "$type")
        
        # Start background job
        (
            clone_or_update_repo "$repo_name" "$org" "$base_url" "$target_path" "$force_update" "$dry_run"
        ) &
        
        local pid=$!
        pids+=($pid)
        repo_names+=("$repo_name")
        
        # Limit parallel jobs
        if [[ ${#pids[@]} -ge $parallel_jobs ]]; then
            # Wait for first job to complete
            wait ${pids[0]}
            pids=("${pids[@]:1}")
            repo_names=("${repo_names[@]:1}")
        fi
        
    done <<< "$repo_list"
    
    # Wait for remaining jobs
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    echo # New line after progress
    log "SUCCESS" "Processed all repositories"
}

# Generate VS Code workspace configuration
generate_vscode_workspace() {
    local repo_data="$1"
    local dry_run="${2:-false}"
    
    if [[ "$dry_run" == "true" ]]; then
        log "DRY_RUN" "Would generate VS Code workspace configuration: $WORKSPACE_CONFIG_FILE"
        return 0
    fi
    
    log "INFO" "Generating VS Code workspace configuration"
    
    local workspace_folders=()
    local repo_list
    repo_list=$(parse_repo_structure "$repo_data")
    
    # Add shared repositories first
    while IFS='|' read -r repo_name team environment resource type; do
        [[ -z "$repo_name" ]] && continue
        
        if [[ "$type" == "exception" ]]; then
            local relative_path="./shared/$repo_name"
            workspace_folders+=("$(cat << EOF
        {
            "name": "$repo_name",
            "path": "$relative_path"
        }
EOF
)")
        fi
    done <<< "$repo_list"
    
    # Add team repositories organized by team/environment
    local processed_paths=()
    while IFS='|' read -r repo_name team environment resource type; do
        [[ -z "$repo_name" ]] && continue
        [[ "$type" == "exception" ]] && continue
        
        local relative_path="./teams/$team/$environment/$resource"
        
        # Avoid duplicates
        local path_exists=false
        for processed_path in "${processed_paths[@]}"; do
            if [[ "$processed_path" == "$relative_path" ]]; then
                path_exists=true
                break
            fi
        done
        
        if [[ "$path_exists" == "false" ]]; then
            processed_paths+=("$relative_path")
            workspace_folders+=("$(cat << EOF
        {
            "name": "$team/$environment/$resource",
            "path": "$relative_path"
        }
EOF
)")
        fi
    done <<< "$repo_list"
    
    # Create workspace configuration
    cat > "$WORKSPACE_CONFIG_FILE" << EOF
{
    "folders": [
$(IFS=$',\n'; echo "${workspace_folders[*]}")
    ],
    "settings": {
        "terraform.experimentalFeatures.validateOnSave": true,
        "terraform.experimentalFeatures.prefillRequiredFields": true,
        "files.associations": {
            "*.tf": "terraform",
            "*.tfvars": "terraform"
        },
        "editor.formatOnSave": true,
        "files.trimTrailingWhitespace": true,
        "files.insertFinalNewline": true,
        "search.exclude": {
            "**/.terraform": true,
            "**/node_modules": true,
            "**/.git": true
        },
        "files.watcherExclude": {
            "**/.terraform/**": true
        }
    },
    "extensions": {
        "recommendations": [
            "hashicorp.terraform",
            "ms-vscode.vscode-json",
            "redhat.vscode-yaml",
            "ms-python.python",
            "timonwong.shellcheck"
        ]
    }
}
EOF
    
    log "SUCCESS" "VS Code workspace configuration generated: $WORKSPACE_CONFIG_FILE"
}

# Display workspace summary
display_summary() {
    local repo_data="$1"
    local dry_run="${2:-false}"
    
    echo
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                          WORKSPACE SETUP SUMMARY${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    
    local total_repos
    total_repos=$(echo "$repo_data" | jq -r '.total')
    
    echo -e "${CYAN}Total Repositories:${NC} $total_repos"
    echo -e "${CYAN}Workspace Directory:${NC} $WORKSPACE_DIR"
    echo
    
    # Summary by team
    echo -e "${WHITE}REPOSITORIES BY TEAM:${NC}"
    echo "$repo_data" | jq -r '.repositories[] | .team' | sort | uniq -c | while read count team; do
        echo -e "  ${GREEN}$team:${NC} $count repositories"
    done
    
    echo
    
    # Summary by environment
    echo -e "${WHITE}REPOSITORIES BY ENVIRONMENT:${NC}"
    echo "$repo_data" | jq -r '.repositories[] | .environment' | sort | uniq -c | while read count env; do
        echo -e "  ${BLUE}$env:${NC} $count repositories"
    done
    
    echo
    
    if [[ "$dry_run" == "false" ]]; then
        echo -e "${WHITE}DIRECTORY STRUCTURE:${NC}"
        if command -v tree &> /dev/null; then
            tree -d -L 3 "$WORKSPACE_DIR" 2>/dev/null | head -20
        else
            find "$WORKSPACE_DIR" -type d -maxdepth 3 | sort | head -20
        fi
        
        echo
        echo -e "${GREEN}✓ Workspace setup completed successfully!${NC}"
        echo -e "${CYAN}Open VS Code workspace:${NC} code '$WORKSPACE_CONFIG_FILE'"
    else
        echo -e "${YELLOW}This was a dry run. Use without --dry-run to execute.${NC}"
    fi
    
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

# Main function
main() {
    local org="$DEFAULT_ORG"
    local base_url="$DEFAULT_BASE_URL"
    local team_filter=""
    local env_filter=""
    local dry_run=false
    local force_update=false
    local parallel_jobs=4
    local skip_vscode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--org)
                org="$2"
                shift 2
                ;;
            -u|--base-url)
                base_url="$2"
                shift 2
                ;;
            -t|--team)
                team_filter="$2"
                shift 2
                ;;
            -e|--env)
                env_filter="$2"
                shift 2
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -f|--force)
                force_update=true
                shift
                ;;
            -p|--parallel)
                parallel_jobs="$2"
                shift 2
                ;;
            -s|--skip-vscode)
                skip_vscode=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate parallel jobs
    if [[ ! "$parallel_jobs" =~ ^[1-9][0-9]*$ ]] || [[ $parallel_jobs -gt 20 ]]; then
        log "ERROR" "Invalid parallel jobs count: $parallel_jobs (must be 1-20)"
        exit 1
    fi
    
    # Initialize
    init_environment
    check_dependencies
    
    echo -e "${WHITE}Dynamic Infrastructure Workspace Setup${NC}"
    echo -e "${CYAN}Organization:${NC} $org"
    [[ -n "$team_filter" ]] && echo -e "${CYAN}Team Filter:${NC} $team_filter"
    [[ -n "$env_filter" ]] && echo -e "${CYAN}Environment Filter:${NC} $env_filter"
    echo -e "${CYAN}Parallel Jobs:${NC} $parallel_jobs"
    [[ "$dry_run" == "true" ]] && echo -e "${YELLOW}Mode:${NC} Dry Run"
    echo
    
    # Discover repositories
    local repo_data
    repo_data=$(discover_repositories "$org" "$team_filter" "$env_filter")
    
    if [[ -z "$repo_data" ]] || ! echo "$repo_data" | jq empty 2>/dev/null; then
        log "ERROR" "Failed to discover repositories or invalid JSON response"
        exit 1
    fi
    
    local total_repos
    total_repos=$(echo "$repo_data" | jq -r '.total')
    
    if [[ $total_repos -eq 0 ]]; then
        echo -e "${YELLOW}No repositories found matching the criteria.${NC}"
        exit 0
    fi
    
    log "SUCCESS" "Discovered $total_repos repositories"
    
    # Process repositories
    process_repositories "$repo_data" "$org" "$base_url" "$parallel_jobs" "$force_update" "$dry_run"
    
    # Generate VS Code workspace
    if [[ "$skip_vscode" == "false" ]]; then
        generate_vscode_workspace "$repo_data" "$dry_run"
    fi
    
    # Display summary
    display_summary "$repo_data" "$dry_run"
    
    log "SUCCESS" "Workspace setup completed"
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted${NC}"; exit 130' INT TERM

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi