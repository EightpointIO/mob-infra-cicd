#!/bin/bash

# Dynamic Infrastructure Repository Discovery Script
# This script uses GitHub API to discover all infrastructure repositories
# following the pattern {team}-infra-{environment}-{resource} plus exceptions
# mob-infrastructure-{cicd,core}

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
readonly CACHE_DIR="${SCRIPT_DIR}/.cache"
readonly CACHE_FILE="${CACHE_DIR}/repo-discovery-cache.json"
readonly LOG_FILE="${SCRIPT_DIR}/logs/repo-discovery-$(date +%Y%m%d-%H%M%S).log"
readonly RATE_LIMIT_FILE="${CACHE_DIR}/rate-limit.json"

# Configuration
readonly DEFAULT_ORG="EightpointIO"
readonly CACHE_EXPIRY_HOURS=1
readonly MAX_PER_PAGE=100
readonly SUPPORTED_TEAMS=("ios" "android")
readonly SUPPORTED_ENVIRONMENTS=("dev" "prod" "global")
readonly EXCEPTION_REPOS=("mob-infrastructure-cicd" "mob-infrastructure-core")

# Usage information
usage() {
    cat << EOF
${WHITE}Dynamic Infrastructure Repository Discovery${NC}

${CYAN}USAGE:${NC}
    $SCRIPT_NAME [OPTIONS]

${CYAN}OPTIONS:${NC}
    -o, --org ORG              GitHub organization (default: $DEFAULT_ORG)
    -t, --team TEAM            Filter by team (ios, android)
    -e, --env ENVIRONMENT      Filter by environment (dev, prod, global)
    -r, --resource RESOURCE    Filter by resource type
    -f, --format FORMAT        Output format (json, table, list) [default: table]
    -c, --cache-only           Use only cached results
    -R, --refresh              Force refresh cache
    -v, --verbose              Verbose output
    -h, --help                 Show this help message

${CYAN}EXAMPLES:${NC}
    $SCRIPT_NAME                                    # List all infrastructure repos
    $SCRIPT_NAME --team ios --env dev               # List iOS dev repos
    $SCRIPT_NAME --format json                      # JSON output
    $SCRIPT_NAME --refresh --verbose                # Refresh cache with verbose output

${CYAN}AUTHENTICATION:${NC}
    Set GITHUB_TOKEN environment variable with a GitHub personal access token.
    Required scopes: repo (for private repos) or public_repo (for public repos only)

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
    esac
}

# Progress indicator
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

# Initialize directories and files
init_environment() {
    mkdir -p "$CACHE_DIR" "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    log "INFO" "Initialized environment - Cache: $CACHE_DIR, Log: $LOG_FILE"
}

# Check GitHub authentication
check_github_auth() {
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log "ERROR" "GITHUB_TOKEN environment variable is not set"
        echo -e "${RED}GitHub authentication required!${NC}"
        echo -e "Please set GITHUB_TOKEN environment variable:"
        echo -e "${YELLOW}export GITHUB_TOKEN='your_github_token'${NC}"
        exit 1
    fi
    
    # Determine authentication header based on token format
    local auth_header
    if [[ "$GITHUB_TOKEN" =~ ^github_pat_ ]]; then
        auth_header="Authorization: Bearer $GITHUB_TOKEN"
    else
        auth_header="Authorization: token $GITHUB_TOKEN"
    fi
    
    # Test GitHub API access
    local response
    response=$(curl -s -H "$auth_header" \
                   -H "Accept: application/vnd.github.v3+json" \
                   "https://api.github.com/user" 2>/dev/null || echo "error")
    
    if [[ "$response" == "error" ]] || echo "$response" | grep -q '"message".*"Bad credentials"'; then
        log "ERROR" "Invalid GitHub token or API access failed"
        echo -e "${RED}GitHub authentication failed!${NC}"
        echo -e "Please check your GITHUB_TOKEN"
        exit 1
    fi
    
    local username
    username=$(echo "$response" | grep -o '"login":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
    log "SUCCESS" "GitHub authentication successful for user: $username"
}

# Check rate limiting
check_rate_limit() {
    # Determine authentication header based on token format
    local auth_header
    if [[ "$GITHUB_TOKEN" =~ ^github_pat_ ]]; then
        auth_header="Authorization: Bearer $GITHUB_TOKEN"
    else
        auth_header="Authorization: token $GITHUB_TOKEN"
    fi
    
    local response
    response=$(curl -s -H "$auth_header" \
                   -H "Accept: application/vnd.github.v3+json" \
                   "https://api.github.com/rate_limit")
    
    local remaining
    local reset_time
    remaining=$(echo "$response" | grep -o '"remaining":[0-9]*' | cut -d':' -f2)
    reset_time=$(echo "$response" | grep -o '"reset":[0-9]*' | cut -d':' -f2)
    
    echo "$response" > "$RATE_LIMIT_FILE"
    
    if [[ ${remaining:-0} -lt 10 ]]; then
        local reset_date
        reset_date=$(date -r "$reset_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
        log "WARN" "GitHub API rate limit low: $remaining requests remaining (resets at $reset_date)"
        
        if [[ ${remaining:-0} -eq 0 ]]; then
            log "ERROR" "GitHub API rate limit exceeded"
            echo -e "${RED}Rate limit exceeded!${NC} Try again after $reset_date"
            exit 1
        fi
    fi
    
    log "INFO" "GitHub API rate limit: $remaining requests remaining"
}

# Check if cache is valid
is_cache_valid() {
    [[ -f "$CACHE_FILE" ]] || return 1
    
    local cache_age
    cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    local cache_expiry_seconds=$((CACHE_EXPIRY_HOURS * 3600))
    
    [[ $cache_age -lt $cache_expiry_seconds ]]
}

# Fetch repositories from GitHub API
fetch_repositories() {
    local org="$1"
    local page=1
    local all_repos=()
    
    log "INFO" "Fetching repositories from GitHub API for organization: $org"
    
    while true; do
        show_progress $((page-1)) 10 "Fetching repositories (page $page)"
        
        # Determine authentication header based on token format
        local auth_header
        if [[ "$GITHUB_TOKEN" =~ ^github_pat_ ]]; then
            auth_header="Authorization: Bearer $GITHUB_TOKEN"
        else
            auth_header="Authorization: token $GITHUB_TOKEN"
        fi
        
        local response
        response=$(curl -s -H "$auth_header" \
                       -H "Accept: application/vnd.github.v3+json" \
                       "https://api.github.com/orgs/$org/repos?type=all&sort=updated&per_page=$MAX_PER_PAGE&page=$page")
        
        # Check for API errors
        if echo "$response" | grep -q '"message"'; then
            local error_msg
            error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            log "ERROR" "GitHub API error: $error_msg"
            echo -e "\n${RED}GitHub API Error:${NC} $error_msg"
            exit 1
        fi
        
        # Parse repository names
        local repos
        repos=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -z "$repos" ]]; then
            break
        fi
        
        all_repos+=($repos)
        ((page++))
        
        # Rate limiting protection
        sleep 0.1
    done
    
    echo # New line after progress
    log "SUCCESS" "Fetched ${#all_repos[@]} repositories from GitHub"
    
    # Filter infrastructure repositories
    local infra_repos=()
    local total_repos=${#all_repos[@]}
    local current=0
    
    for repo in "${all_repos[@]}"; do
        ((current++))
        show_progress $current $total_repos "Filtering infrastructure repositories"
        
        # Check naming pattern: {team}-infra-{environment}-{resource}
        if [[ "$repo" =~ ^[a-zA-Z0-9_-]+-infra-(dev|prod|global)-.+ ]]; then
            infra_repos+=("$repo")
            log "DEBUG" "Found infrastructure repo: $repo"
        # Check exception patterns: mob-infrastructure-{cicd,core}
        elif [[ "$repo" =~ ^mob-infrastructure-(cicd|core)$ ]]; then
            infra_repos+=("$repo")
            log "DEBUG" "Found exception repo: $repo"
        fi
    done
    
    echo # New line after progress
    log "SUCCESS" "Found ${#infra_repos[@]} infrastructure repositories"
    
    # Create cache structure
    local cache_data
    cache_data=$(cat << EOF
{
    "timestamp": $(date +%s),
    "organization": "$org",
    "repositories": [
$(printf '        "%s"' "${infra_repos[@]}" | sed 's/$/,/' | sed '$s/,$//')
    ]
}
EOF
)
    
    echo "$cache_data" > "$CACHE_FILE"
    log "INFO" "Cache updated with ${#infra_repos[@]} repositories"
    
    printf '%s\n' "${infra_repos[@]}"
}

# Parse repository information
parse_repo_info() {
    local repo="$1"
    local team="" env="" resource=""
    
    # Handle exception repositories
    if [[ "$repo" == "mob-infrastructure-cicd" ]]; then
        echo '{"name":"'$repo'","team":"shared","environment":"global","resource":"cicd","type":"exception"}'
        return
    elif [[ "$repo" == "mob-infrastructure-core" ]]; then
        echo '{"name":"'$repo'","team":"shared","environment":"global","resource":"core","type":"exception"}'
        return
    fi
    
    # Parse standard pattern: {team}-infra-{environment}-{resource}
    if [[ "$repo" =~ ^([^-]+)-infra-([^-]+)-(.+)$ ]]; then
        team="${BASH_REMATCH[1]}"
        env="${BASH_REMATCH[2]}"
        resource="${BASH_REMATCH[3]}"
        echo '{"name":"'$repo'","team":"'$team'","environment":"'$env'","resource":"'$resource'","type":"standard"}'
    else
        echo '{"name":"'$repo'","team":"unknown","environment":"unknown","resource":"unknown","type":"unknown"}'
    fi
}

# Apply filters
apply_filters() {
    local repos=("$@")
    local filtered_repos=()
    
    for repo in "${repos[@]}"; do
        local repo_info
        repo_info=$(parse_repo_info "$repo")
        
        local repo_team repo_env repo_resource
        repo_team=$(echo "$repo_info" | grep -o '"team":"[^"]*"' | cut -d'"' -f4)
        repo_env=$(echo "$repo_info" | grep -o '"environment":"[^"]*"' | cut -d'"' -f4)
        repo_resource=$(echo "$repo_info" | grep -o '"resource":"[^"]*"' | cut -d'"' -f4)
        
        # Apply team filter
        if [[ -n "${FILTER_TEAM:-}" && "$repo_team" != "$FILTER_TEAM" ]]; then
            continue
        fi
        
        # Apply environment filter
        if [[ -n "${FILTER_ENV:-}" && "$repo_env" != "$FILTER_ENV" ]]; then
            continue
        fi
        
        # Apply resource filter
        if [[ -n "${FILTER_RESOURCE:-}" && "$repo_resource" != "$FILTER_RESOURCE" ]]; then
            continue
        fi
        
        filtered_repos+=("$repo")
    done
    
    printf '%s\n' "${filtered_repos[@]}"
}

# Format output
format_output() {
    local format="$1"
    shift
    local repos=("$@")
    
    case "$format" in
        "json")
            echo "{"
            echo '  "timestamp": "'$(date -Iseconds)'",'
            echo '  "total": '${#repos[@]}','
            echo '  "repositories": ['
            for i in "${!repos[@]}"; do
                local repo_info
                repo_info=$(parse_repo_info "${repos[$i]}")
                echo "    $repo_info"
                [[ $i -lt $((${#repos[@]} - 1)) ]] && echo ","
            done
            echo "  ]"
            echo "}"
            ;;
        "list")
            printf '%s\n' "${repos[@]}"
            ;;
        "table"|*)
            echo
            printf "${WHITE}%-40s %-10s %-12s %-20s %-10s${NC}\n" "REPOSITORY" "TEAM" "ENVIRONMENT" "RESOURCE" "TYPE"
            printf "%-40s %-10s %-12s %-20s %-10s\n" "$(printf '%.40s' "----------------------------------------")" \
                   "$(printf '%.10s' "----------")" \
                   "$(printf '%.12s' "------------")" \
                   "$(printf '%.20s' "--------------------")" \
                   "$(printf '%.10s' "----------")"
            
            for repo in "${repos[@]}"; do
                local repo_info
                repo_info=$(parse_repo_info "$repo")
                
                local name team env resource type
                name=$(echo "$repo_info" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
                team=$(echo "$repo_info" | grep -o '"team":"[^"]*"' | cut -d'"' -f4)
                env=$(echo "$repo_info" | grep -o '"environment":"[^"]*"' | cut -d'"' -f4)
                resource=$(echo "$repo_info" | grep -o '"resource":"[^"]*"' | cut -d'"' -f4)
                type=$(echo "$repo_info" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
                
                # Color coding
                local color="$NC"
                case "$type" in
                    "exception") color="$YELLOW" ;;
                    "standard")  color="$GREEN" ;;
                    *)           color="$RED" ;;
                esac
                
                printf "${color}%-40s %-10s %-12s %-20s %-10s${NC}\n" \
                       "$name" "$team" "$env" "$resource" "$type"
            done
            echo
            echo -e "${CYAN}Total repositories: ${WHITE}${#repos[@]}${NC}"
            ;;
    esac
}

# Main function
main() {
    local org="$DEFAULT_ORG"
    local format="table"
    local cache_only=false
    local refresh_cache=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--org)
                org="$2"
                shift 2
                ;;
            -t|--team)
                FILTER_TEAM="$2"
                shift 2
                ;;
            -e|--env)
                FILTER_ENV="$2"
                shift 2
                ;;
            -r|--resource)
                FILTER_RESOURCE="$2"
                shift 2
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -c|--cache-only)
                cache_only=true
                shift
                ;;
            -R|--refresh)
                refresh_cache=true
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
    
    # Validate inputs
    if [[ -n "${FILTER_TEAM:-}" ]] && [[ ! " ${SUPPORTED_TEAMS[*]} " =~ " ${FILTER_TEAM} " ]]; then
        log "ERROR" "Unsupported team: $FILTER_TEAM. Supported teams: ${SUPPORTED_TEAMS[*]}"
        exit 1
    fi
    
    if [[ -n "${FILTER_ENV:-}" ]] && [[ ! " ${SUPPORTED_ENVIRONMENTS[*]} " =~ " ${FILTER_ENV} " ]]; then
        log "ERROR" "Unsupported environment: $FILTER_ENV. Supported environments: ${SUPPORTED_ENVIRONMENTS[*]}"
        exit 1
    fi
    
    # Initialize
    init_environment
    
    # Get repositories
    local repos=()
    if [[ "$cache_only" == "true" ]]; then
        if [[ ! -f "$CACHE_FILE" ]]; then
            log "ERROR" "No cache file found. Run without --cache-only first."
            exit 1
        fi
        
        mapfile -t repos < <(grep -o '"[^"]*"' "$CACHE_FILE" | grep -v '["{}:,]' | sed 's/"//g' | grep -E '^(ios|android)-infra-|^mob-infrastructure-')
        log "INFO" "Loaded ${#repos[@]} repositories from cache"
    else
        check_github_auth
        check_rate_limit
        
        if [[ "$refresh_cache" == "true" ]] || ! is_cache_valid; then
            mapfile -t repos < <(fetch_repositories "$org")
        else
            mapfile -t repos < <(grep -o '"[^"]*"' "$CACHE_FILE" | grep -v '["{}:,]' | sed 's/"//g' | grep -E '^(ios|android)-infra-|^mob-infrastructure-')
            log "INFO" "Using cached repositories (${#repos[@]} found)"
        fi
    fi
    
    # Apply filters
    if [[ -n "${FILTER_TEAM:-}${FILTER_ENV:-}${FILTER_RESOURCE:-}" ]]; then
        mapfile -t repos < <(apply_filters "${repos[@]}")
        log "INFO" "Applied filters, ${#repos[@]} repositories match"
    fi
    
    # Format and display output
    format_output "$format" "${repos[@]}"
    
    log "SUCCESS" "Repository discovery completed successfully"
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted${NC}"; exit 130' INT TERM

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi