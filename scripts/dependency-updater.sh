#!/usr/bin/env zsh

# Terraform Dependency Updater Script
# Intelligently updates Terraform module versions, provider versions, and GitHub releases
# with safety checks, validation, and comprehensive reporting

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
BACKUP_DIR="${SCRIPT_DIR}/backups"
TEMP_DIR="${SCRIPT_DIR}/temp"
REPORTS_DIR="${SCRIPT_DIR}/reports"

# Create required directories
mkdir -p "${LOG_DIR}" "${BACKUP_DIR}" "${TEMP_DIR}" "${REPORTS_DIR}"

# Logging setup
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/dependency-updater-${TIMESTAMP}.log"
REPORT_FILE="${REPORTS_DIR}/update-report-${TIMESTAMP}.md"
CHANGELOG_FILE="${REPORTS_DIR}/changelog-${TIMESTAMP}.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_CONFIG_FILE="${SCRIPT_DIR}/dependency-updater.config"
GITHUB_API_BASE="https://api.github.com"
MAX_RETRIES=3
VALIDATION_TIMEOUT=300
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Version pinning strategies
typeset -A VERSION_STRATEGIES
VERSION_STRATEGIES[patch]="~> 1.0.0"    # Allow patch updates
VERSION_STRATEGIES[minor]="~> 1.0"      # Allow minor updates  
VERSION_STRATEGIES[major]=">= 1.0"      # Allow major updates
VERSION_STRATEGIES[exact]="1.0.0"       # Exact version only

# Provider version constraints
typeset -A PROVIDER_CONSTRAINTS
PROVIDER_CONSTRAINTS[hashicorp/aws]="~> 5.0"
PROVIDER_CONSTRAINTS[hashicorp/random]="~> 3.0"
PROVIDER_CONSTRAINTS[hashicorp/tls]="~> 4.0"
PROVIDER_CONSTRAINTS[hashicorp/kubernetes]="~> 2.0"
PROVIDER_CONSTRAINTS[hashicorp/helm]="~> 2.0"

# Functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  echo -e "${GREEN}[INFO]${NC}  ${message}" | tee -a "${LOG_FILE}" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  ${message}" | tee -a "${LOG_FILE}" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} ${message}" | tee -a "${LOG_FILE}" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} ${message}" | tee -a "${LOG_FILE}" ;;
        *)       echo -e "${message}" | tee -a "${LOG_FILE}" ;;
    esac
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

show_usage() {
    cat << EOF
Terraform Dependency Updater

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    check           Check for available updates without applying
    update          Update dependencies with safety checks
    providers       Update only provider versions
    modules         Update only module versions
    validate        Validate current configuration
    report          Generate update report
    restore         Restore from backup

OPTIONS:
    -c, --config FILE       Use custom configuration file
    -s, --strategy STRATEGY Version pinning strategy (patch|minor|major|exact)
    -d, --dry-run          Show what would be updated without making changes
    -f, --force            Skip interactive confirmations
    -b, --backup           Create backup before updates
    -v, --validate         Run validation after updates
    -p, --create-pr        Create pull request for updates
    -t, --target PATH      Target specific directory or file
    -e, --exclude PATTERN  Exclude files matching pattern
    -m, --max-age DAYS     Only update if current version is older than N days
    --github-token TOKEN   GitHub API token for rate limiting
    --help                 Show this help message

EXAMPLES:
    $0 check                                    # Check for updates
    $0 update --strategy minor --validate       # Update with minor strategy and validate
    $0 update --dry-run                        # Preview updates without applying
    $0 providers --target teams/ios/dev         # Update providers in specific path
    $0 modules --exclude "**/test/**"          # Update modules excluding test directories
    $0 update --create-pr --force              # Update and create PR automatically

CONFIGURATION:
    Create ${DEFAULT_CONFIG_FILE} to customize default behavior:
        DEFAULT_STRATEGY=minor
        AUTO_BACKUP=true
        AUTO_VALIDATE=true
        EXCLUDED_PATHS=("**/test/**" "**/examples/**")
        GITHUB_ORG=EightpointIO
        MODULE_REPOS=("mob-infrastructure-core" "mob-infrastructure-cicd")

EOF
}

load_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"
    
    if [[ -f "$config_file" ]]; then
        log "INFO" "Loading configuration from: $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    else
        log "WARN" "Configuration file not found: $config_file. Using defaults."
    fi
    
    # Set defaults if not configured
    DEFAULT_STRATEGY="${DEFAULT_STRATEGY:-minor}"
    AUTO_BACKUP="${AUTO_BACKUP:-true}"
    AUTO_VALIDATE="${AUTO_VALIDATE:-true}"
    GITHUB_ORG="${GITHUB_ORG:-EightpointIO}"
    EXCLUDED_PATHS="${EXCLUDED_PATHS:-()}"
    MODULE_REPOS="${MODULE_REPOS:-(mob-infrastructure-core mob-infrastructure-cicd)}"
}

check_prerequisites() {
    log "INFO" "Checking prerequisites..."
    
    local missing_tools=()
    
    for tool in terraform git jq curl; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error_exit "Missing required tools: ${missing_tools[*]}"
    fi
    
    # Check Terraform version
    local tf_version
    tf_version=$(terraform version -json | jq -r '.terraform_version')
    log "INFO" "Terraform version: $tf_version"
    
    # Check Git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        error_exit "Not in a Git repository"
    fi
    
    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain)" ]]; then
        log "WARN" "Uncommitted changes detected. Consider committing before updating dependencies."
    fi
    
    log "INFO" "Prerequisites check completed"
}

github_api_request() {
    local endpoint="$1"
    local headers=()
    
    if [[ -n "$GITHUB_TOKEN" ]]; then
        headers+=("-H" "Authorization: token $GITHUB_TOKEN")
    fi
    
    headers+=("-H" "Accept: application/vnd.github.v3+json")
    
    local response
    local http_code
    
    for ((i=1; i<=MAX_RETRIES; i++)); do
        response=$(curl -s -w "\n%{http_code}" "${headers[@]}" "${GITHUB_API_BASE}${endpoint}")
        http_code=$(echo "$response" | tail -n1)
        response=$(echo "$response" | head -n -1)
        
        if [[ "$http_code" == "200" ]]; then
            echo "$response"
            return 0
        elif [[ "$http_code" == "403" ]]; then
            log "WARN" "GitHub API rate limit exceeded. Attempt $i/$MAX_RETRIES"
            sleep $((i * 2))
        else
            log "WARN" "GitHub API request failed with HTTP $http_code. Attempt $i/$MAX_RETRIES"
            sleep $i
        fi
    done
    
    log "ERROR" "Failed to make GitHub API request after $MAX_RETRIES attempts"
    return 1
}

get_latest_github_release() {
    local repo="$1"
    local org="${2:-$GITHUB_ORG}"
    
    log "DEBUG" "Getting latest release for $org/$repo"
    
    local releases
    releases=$(github_api_request "/repos/$org/$repo/releases/latest")
    
    if [[ $? -ne 0 ]]; then
        log "WARN" "Failed to get latest release for $org/$repo"
        return 1
    fi
    
    local tag_name
    tag_name=$(echo "$releases" | jq -r '.tag_name // empty')
    
    if [[ -n "$tag_name" ]]; then
        echo "$tag_name"
        return 0
    else
        log "WARN" "No releases found for $org/$repo"
        return 1
    fi
}

get_provider_latest_version() {
    local provider="$1"
    
    log "DEBUG" "Getting latest version for provider: $provider"
    
    # Use Terraform Registry API
    local response
    response=$(curl -s "https://registry.terraform.io/v1/providers/$provider")
    
    if [[ $? -ne 0 ]]; then
        log "WARN" "Failed to get provider info for $provider"
        return 1
    fi
    
    local version
    version=$(echo "$response" | jq -r '.version // empty')
    
    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    else
        log "WARN" "No version found for provider $provider"
        return 1
    fi
}

find_terraform_files() {
    local target_path="${1:-$PROJECT_ROOT}"
    local exclude_patterns=("${EXCLUDED_PATHS[@]}")
    
    log "DEBUG" "Finding Terraform files in: $target_path"
    
    local find_cmd="find $target_path -name '*.tf' -type f"
    
    # Add exclusions
    for pattern in "${exclude_patterns[@]}"; do
        find_cmd+=" ! -path '$pattern'"
    done
    
    eval "$find_cmd"
}

parse_terraform_file() {
    local file="$1"
    local temp_file="${TEMP_DIR}/parsed_$(basename "$file").json"
    
    # Use terraform providers schema or hcl2json if available
    if command -v hcl2json &> /dev/null; then
        hcl2json < "$file" > "$temp_file" 2>/dev/null || {
            log "WARN" "Failed to parse $file with hcl2json"
            return 1
        }
    else
        # Fallback to regex parsing for basic cases
        grep -E "(required_providers|source|version)" "$file" > "$temp_file" 2>/dev/null || {
            log "DEBUG" "No provider/version blocks found in $file"
            return 1
        }
    fi
    
    echo "$temp_file"
}

extract_module_versions() {
    local file="$1"
    local modules=()
    
    log "DEBUG" "Extracting module versions from: $file"
    
    # Extract module blocks with source and ref
    while IFS= read -r line; do
        if [[ "$line" =~ module[[:space:]]+\"([^\"]+)\"[[:space:]]*\{ ]]; then
            local module_name="${BASH_REMATCH[1]}"
            local in_module=true
            local source=""
            local ref=""
            
            # Read subsequent lines to find source and ref
            while IFS= read -r module_line && [[ "$in_module" == true ]]; do
                if [[ "$module_line" =~ source[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
                    source="${BASH_REMATCH[1]}"
                elif [[ "$module_line" =~ \?ref=([^\"[:space:]]+) ]]; then
                    ref="${BASH_REMATCH[1]}"
                elif [[ "$module_line" =~ ^\} ]]; then
                    in_module=false
                fi
            done < <(tail -n +$(($(grep -n "module.*\"$module_name\"" "$file" | cut -d: -f1) + 1)) "$file")
            
            if [[ -n "$source" && -n "$ref" ]]; then
                modules+=("$module_name|$source|$ref|$file")
            fi
        fi
    done < "$file"
    
    printf '%s\n' "${modules[@]}"
}

extract_provider_versions() {
    local file="$1"
    local providers=()
    
    log "DEBUG" "Extracting provider versions from: $file"
    
    # Look for required_providers blocks
    local in_providers=false
    local brace_count=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ required_providers[[:space:]]*\{ ]]; then
            in_providers=true
            brace_count=1
        elif [[ "$in_providers" == true ]]; then
            # Count braces to track nested blocks
            local open_braces=$(echo "$line" | grep -o '{' | wc -l)
            local close_braces=$(echo "$line" | grep -o '}' | wc -l)
            brace_count=$((brace_count + open_braces - close_braces))
            
            if [[ $brace_count -eq 0 ]]; then
                in_providers=false
            elif [[ "$line" =~ ([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*\{ ]]; then
                local provider_name="${BASH_REMATCH[1]}"
                local source=""
                local version=""
                
                # Read the provider block
                while IFS= read -r provider_line && [[ $brace_count -gt 0 ]]; do
                    local p_open=$(echo "$provider_line" | grep -o '{' | wc -l)
                    local p_close=$(echo "$provider_line" | grep -o '}' | wc -l)
                    brace_count=$((brace_count + p_open - p_close))
                    
                    if [[ "$provider_line" =~ source[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
                        source="${BASH_REMATCH[1]}"
                    elif [[ "$provider_line" =~ version[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
                        version="${BASH_REMATCH[1]}"
                    fi
                done < <(tail -n +$(($(grep -n "$provider_name.*{" "$file" | head -1 | cut -d: -f1) + 1)) "$file")
                
                if [[ -n "$source" && -n "$version" ]]; then
                    providers+=("$provider_name|$source|$version|$file")
                fi
            fi
        fi
    done < "$file"
    
    printf '%s\n' "${providers[@]}"
}

check_version_age() {
    local current_version="$1"
    local max_age_days="${2:-30}"
    
    # This would require version release date information
    # For now, we'll always return true (needs update)
    # In a real implementation, you'd query the release date
    return 0
}

apply_version_strategy() {
    local current_version="$1"
    local latest_version="$2"
    local strategy="$3"
    
    # Remove 'v' prefix if present
    current_version="${current_version#v}"
    latest_version="${latest_version#v}"
    
    case "$strategy" in
        "exact")
            echo "$current_version"
            ;;
        "patch")
            # Extract major.minor and use latest patch
            local major_minor
            major_minor=$(echo "$current_version" | cut -d. -f1-2)
            if [[ "$latest_version" == "$major_minor"* ]]; then
                echo "$latest_version"
            else
                echo "$current_version"
            fi
            ;;
        "minor")
            # Extract major and use latest minor.patch
            local major
            major=$(echo "$current_version" | cut -d. -f1)
            if [[ "$latest_version" == "$major"* ]]; then
                echo "$latest_version"
            else
                echo "$current_version"
            fi
            ;;
        "major")
            echo "$latest_version"
            ;;
        *)
            echo "$current_version"
            ;;
    esac
}

create_backup() {
    local backup_name="dependency-backup-${TIMESTAMP}"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log "INFO" "Creating backup: $backup_name"
    
    mkdir -p "$backup_path"
    
    # Backup all Terraform files
    find "$PROJECT_ROOT" -name "*.tf" -type f | while read -r file; do
        local relative_path="${file#$PROJECT_ROOT/}"
        local backup_file="$backup_path/$relative_path"
        local backup_dir
        backup_dir=$(dirname "$backup_file")
        
        mkdir -p "$backup_dir"
        cp "$file" "$backup_file"
    done
    
    # Create backup manifest
    cat > "$backup_path/manifest.json" << EOF
{
    "timestamp": "$TIMESTAMP",
    "git_commit": "$(git rev-parse HEAD)",
    "git_branch": "$(git rev-parse --abbrev-ref HEAD)",
    "backup_path": "$backup_path"
}
EOF
    
    log "INFO" "Backup created at: $backup_path"
    echo "$backup_path"
}

restore_from_backup() {
    local backup_path="$1"
    
    if [[ ! -d "$backup_path" ]]; then
        error_exit "Backup path not found: $backup_path"
    fi
    
    log "INFO" "Restoring from backup: $backup_path"
    
    # Restore files
    find "$backup_path" -name "*.tf" -type f | while read -r backup_file; do
        local relative_path="${backup_file#$backup_path/}"
        local original_file="$PROJECT_ROOT/$relative_path"
        local original_dir
        original_dir=$(dirname "$original_file")
        
        mkdir -p "$original_dir"
        cp "$backup_file" "$original_file"
    done
    
    log "INFO" "Restore completed from: $backup_path"
}

update_module_version() {
    local file="$1"
    local module_name="$2"
    local old_version="$3"
    local new_version="$4"
    
    log "INFO" "Updating module $module_name from $old_version to $new_version in $file"
    
    # Create temporary file for atomic update
    local temp_file="${TEMP_DIR}/$(basename "$file").tmp"
    
    # Update the version using sed
    sed "s|\?ref=${old_version}|?ref=${new_version}|g" "$file" > "$temp_file"
    
    # Verify the change was made
    if grep -q "ref=${new_version}" "$temp_file"; then
        mv "$temp_file" "$file"
        log "INFO" "Successfully updated $module_name to $new_version"
        return 0
    else
        rm -f "$temp_file"
        log "ERROR" "Failed to update $module_name version in $file"
        return 1
    fi
}

update_provider_version() {
    local file="$1"
    local provider_name="$2"
    local old_version="$3"
    local new_version="$4"
    
    log "INFO" "Updating provider $provider_name from $old_version to $new_version in $file"
    
    # Create temporary file for atomic update
    local temp_file="${TEMP_DIR}/$(basename "$file").tmp"
    
    # Update the version using sed (more complex for provider blocks)
    awk -v provider="$provider_name" -v old_ver="$old_version" -v new_ver="$new_version" '
    BEGIN { in_provider = 0; in_required_providers = 0 }
    /required_providers/ { in_required_providers = 1 }
    in_required_providers && $0 ~ provider "\\s*=" { in_provider = 1 }
    in_provider && /version.*=/ && $0 ~ old_ver { 
        gsub(old_ver, new_ver, $0)
        in_provider = 0
    }
    /}/ && in_required_providers { 
        if (in_provider) in_provider = 0
        if ($0 == "}") in_required_providers = 0
    }
    { print }
    ' "$file" > "$temp_file"
    
    # Verify the change was made
    if grep -q "version.*$new_version" "$temp_file"; then
        mv "$temp_file" "$file"
        log "INFO" "Successfully updated $provider_name to $new_version"
        return 0
    else
        rm -f "$temp_file"
        log "ERROR" "Failed to update $provider_name version in $file"
        return 1
    fi
}

validate_terraform() {
    local path="$1"
    
    log "INFO" "Validating Terraform configuration in: $path"
    
    # Change to the directory containing terraform files
    local original_dir=$(pwd)
    cd "$path"
    
    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        log "INFO" "Initializing Terraform..."
        if ! timeout $VALIDATION_TIMEOUT terraform init -upgrade >> "$LOG_FILE" 2>&1; then
            log "ERROR" "Terraform init failed in $path"
            cd "$original_dir"
            return 1
        fi
    fi
    
    # Validate
    if ! timeout $VALIDATION_TIMEOUT terraform validate >> "$LOG_FILE" 2>&1; then
        log "ERROR" "Terraform validation failed in $path"
        cd "$original_dir"
        return 1
    fi
    
    # Plan (dry run)
    if ! timeout $VALIDATION_TIMEOUT terraform plan -detailed-exitcode >> "$LOG_FILE" 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            log "WARN" "Terraform plan shows changes in $path"
        else
            log "ERROR" "Terraform plan failed in $path"
            cd "$original_dir"
            return 1
        fi
    fi
    
    cd "$original_dir"
    log "INFO" "Terraform validation completed successfully for: $path"
    return 0
}

generate_update_report() {
    local updates=("$@")
    
    log "INFO" "Generating update report: $REPORT_FILE"
    
    cat > "$REPORT_FILE" << EOF
# Terraform Dependency Update Report

**Generated:** $(date)
**Total Updates:** ${#updates[@]}

## Summary

This report details all dependency updates performed by the Terraform Dependency Updater.

## Updates Applied

EOF
    
    for update in "${updates[@]}"; do
        IFS='|' read -r type name old_version new_version file <<< "$update"
        cat >> "$REPORT_FILE" << EOF
### $type: $name

- **File:** \`$file\`
- **Old Version:** \`$old_version\`
- **New Version:** \`$new_version\`

EOF
    done
    
    cat >> "$REPORT_FILE" << EOF

## Validation Results

$(if [[ -f "${LOG_FILE}" ]]; then
    grep -A 10 -B 2 "validation\|Validation" "${LOG_FILE}" || echo "No validation logs found"
fi)

## Recommendations

1. Test the updated infrastructure in a development environment
2. Review the changelog for breaking changes
3. Update documentation if necessary
4. Monitor deployments for any issues

---
*Generated by Terraform Dependency Updater v1.0*
EOF
    
    log "INFO" "Update report generated: $REPORT_FILE"
}

generate_changelog() {
    local updates=("$@")
    
    log "INFO" "Generating changelog: $CHANGELOG_FILE"
    
    cat > "$CHANGELOG_FILE" << EOF
# Changelog

## [$(date +%Y-%m-%d)] - Dependency Updates

### Updated

EOF
    
    for update in "${updates[@]}"; do
        IFS='|' read -r type name old_version new_version file <<< "$update"
        echo "- $type \`$name\` from \`$old_version\` to \`$new_version\`" >> "$CHANGELOG_FILE"
    done
    
    echo "" >> "$CHANGELOG_FILE"
    
    log "INFO" "Changelog generated: $CHANGELOG_FILE"
}

create_pull_request() {
    local title="$1"
    local body="$2"
    
    log "INFO" "Creating pull request: $title"
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        log "WARN" "GitHub CLI (gh) not found. Cannot create pull request automatically."
        log "INFO" "Please create a pull request manually with the following details:"
        log "INFO" "Title: $title"
        log "INFO" "Body: $body"
        return 1
    fi
    
    # Create branch
    local branch_name="dependency-updates-${TIMESTAMP}"
    git checkout -b "$branch_name"
    
    # Add changes
    git add .
    
    # Commit changes
    git commit -m "$title

$body

Generated by Terraform Dependency Updater"
    
    # Push branch
    git push -u origin "$branch_name"
    
    # Create PR
    gh pr create \
        --title "$title" \
        --body "$body" \
        --head "$branch_name" \
        --base "$(git symbolic-ref refs/remotes/origin/HEAD | cut -d'/' -f4)"
    
    log "INFO" "Pull request created successfully"
}

check_for_updates() {
    local target_path="${1:-$PROJECT_ROOT}"
    local dry_run="${2:-false}"
    
    log "INFO" "Checking for dependency updates in: $target_path"
    
    local terraform_files
    terraform_files=()
    while IFS= read -r line; do
        terraform_files+=("$line")
    done < <(find_terraform_files "$target_path")
    
    local available_updates=()
    
    for file in "${terraform_files[@]}"; do
        log "DEBUG" "Processing file: $file"
        
        # Check module updates
        while IFS= read -r module_info; do
            if [[ -n "$module_info" ]]; then
                IFS='|' read -r module_name source ref file_path <<< "$module_info"
                
                # Extract repository name from source
                if [[ "$source" =~ github\.com/[^/]+/([^/]+) ]]; then
                    local repo_name="${BASH_REMATCH[1]}"
                    repo_name="${repo_name%.git}"
                    
                    local latest_version
                    latest_version=$(get_latest_github_release "$repo_name")
                    
                    if [[ $? -eq 0 && "$latest_version" != "$ref" ]]; then
                        local updated_version
                        updated_version=$(apply_version_strategy "$ref" "$latest_version" "$DEFAULT_STRATEGY")
                        
                        if [[ "$updated_version" != "$ref" ]]; then
                            available_updates+=("module|$module_name|$ref|$updated_version|$file_path")
                            log "INFO" "Update available - Module: $module_name ($ref → $updated_version)"
                        fi
                    fi
                fi
            fi
        done < <(extract_module_versions "$file")
        
        # Check provider updates
        while IFS= read -r provider_info; do
            if [[ -n "$provider_info" ]]; then
                IFS='|' read -r provider_name source version file_path <<< "$provider_info"
                
                local latest_version
                latest_version=$(get_provider_latest_version "$source")
                
                if [[ $? -eq 0 && "$latest_version" != "$version" ]]; then
                    local updated_version
                    updated_version=$(apply_version_strategy "$version" "$latest_version" "$DEFAULT_STRATEGY")
                    
                    if [[ "$updated_version" != "$version" ]]; then
                        available_updates+=("provider|$provider_name|$version|$updated_version|$file_path")
                        log "INFO" "Update available - Provider: $provider_name ($version → $updated_version)"
                    fi
                fi
            fi
        done < <(extract_provider_versions "$file")
    done
    
    if [[ ${#available_updates[@]} -eq 0 ]]; then
        log "INFO" "No updates available"
        return 0
    fi
    
    log "INFO" "Found ${#available_updates[@]} available updates"
    
    if [[ "$dry_run" == "true" ]]; then
        log "INFO" "Dry run mode - no changes will be applied"
        for update in "${available_updates[@]}"; do
            IFS='|' read -r type name old_version new_version file <<< "$update"
            log "INFO" "Would update $type $name from $old_version to $new_version in $file"
        done
    fi
    
    # Store updates for processing
    printf '%s\n' "${available_updates[@]}" > "${TEMP_DIR}/available_updates.txt"
    
    return 0
}

apply_updates() {
    local updates_file="${TEMP_DIR}/available_updates.txt"
    local validate="${1:-false}"
    local create_pr="${2:-false}"
    
    if [[ ! -f "$updates_file" ]]; then
        log "ERROR" "No updates file found. Run check command first."
        return 1
    fi
    
    local applied_updates=()
    local failed_updates=()
    
    while IFS= read -r update; do
        if [[ -n "$update" ]]; then
            IFS='|' read -r type name old_version new_version file <<< "$update"
            
            case "$type" in
                "module")
                    if update_module_version "$file" "$name" "$old_version" "$new_version"; then
                        applied_updates+=("$update")
                    else
                        failed_updates+=("$update")
                    fi
                    ;;
                "provider")
                    if update_provider_version "$file" "$name" "$old_version" "$new_version"; then
                        applied_updates+=("$update")
                    else
                        failed_updates+=("$update")
                    fi
                    ;;
            esac
        fi
    done < "$updates_file"
    
    log "INFO" "Applied ${#applied_updates[@]} updates, ${#failed_updates[@]} failed"
    
    # Validate if requested
    if [[ "$validate" == "true" && ${#applied_updates[@]} -gt 0 ]]; then
        log "INFO" "Running validation..."
        
        local unique_dirs=()
        for update in "${applied_updates[@]}"; do
            IFS='|' read -r _ _ _ _ file <<< "$update"
            local dir
            dir=$(dirname "$file")
            if [[ ! " ${unique_dirs[*]} " =~ " ${dir} " ]]; then
                unique_dirs+=("$dir")
            fi
        done
        
        for dir in "${unique_dirs[@]}"; do
            if ! validate_terraform "$dir"; then
                log "ERROR" "Validation failed for: $dir"
                return 1
            fi
        done
    fi
    
    # Generate reports
    if [[ ${#applied_updates[@]} -gt 0 ]]; then
        generate_update_report "${applied_updates[@]}"
        generate_changelog "${applied_updates[@]}"
    fi
    
    # Create PR if requested
    if [[ "$create_pr" == "true" && ${#applied_updates[@]} -gt 0 ]]; then
        local pr_title="Update Terraform dependencies"
        local pr_body="Automated dependency updates:

$(for update in "${applied_updates[@]}"; do
    IFS='|' read -r type name old_version new_version _ <<< "$update"
    echo "- $type $name: $old_version → $new_version"
done)

See attached reports for details."
        
        create_pull_request "$pr_title" "$pr_body"
    fi
    
    return 0
}

# Main execution
main() {
    local command=""
    local config_file=""
    local strategy=""
    local dry_run=false
    local force=false
    local backup=false
    local validate=false
    local create_pr=false
    local target_path=""
    local exclude_pattern=""
    local max_age=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -s|--strategy)
                strategy="$2"
                shift 2
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -b|--backup)
                backup=true
                shift
                ;;
            -v|--validate)
                validate=true
                shift
                ;;
            -p|--create-pr)
                create_pr=true
                shift
                ;;
            -t|--target)
                target_path="$2"
                shift 2
                ;;
            -e|--exclude)
                exclude_pattern="$2"
                shift 2
                ;;
            -m|--max-age)
                max_age="$2"
                shift 2
                ;;
            --github-token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            check|update|providers|modules|validate|report|restore)
                command="$1"
                shift
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set default command
    if [[ -z "$command" ]]; then
        command="check"
    fi
    
    # Load configuration
    load_config "$config_file"
    
    # Override strategy if provided
    if [[ -n "$strategy" ]]; then
        DEFAULT_STRATEGY="$strategy"
    fi
    
    # Set target path
    if [[ -n "$target_path" ]]; then
        if [[ ! -d "$target_path" ]]; then
            error_exit "Target path does not exist: $target_path"
        fi
    else
        target_path="$PROJECT_ROOT"
    fi
    
    # Add exclude pattern if provided
    if [[ -n "$exclude_pattern" ]]; then
        EXCLUDED_PATHS+=("$exclude_pattern")
    fi
    
    log "INFO" "Starting Terraform Dependency Updater"
    log "INFO" "Command: $command"
    log "INFO" "Strategy: $DEFAULT_STRATEGY"
    log "INFO" "Target: $target_path"
    log "INFO" "Dry run: $dry_run"
    
    # Check prerequisites
    check_prerequisites
    
    # Create backup if requested or auto-backup is enabled
    local backup_path=""
    if [[ "$backup" == "true" || "$AUTO_BACKUP" == "true" ]] && [[ "$command" == "update" || "$command" == "modules" || "$command" == "providers" ]]; then
        backup_path=$(create_backup)
    fi
    
    # Execute command
    case "$command" in
        "check")
            check_for_updates "$target_path" true
            ;;
        "update")
            check_for_updates "$target_path" "$dry_run"
            if [[ "$dry_run" == "false" ]]; then
                apply_updates "$validate" "$create_pr"
            fi
            ;;
        "providers")
            log "INFO" "Provider-only updates not yet implemented"
            # TODO: Implement provider-only updates
            ;;
        "modules")
            log "INFO" "Module-only updates not yet implemented"
            # TODO: Implement module-only updates
            ;;
        "validate")
            validate_terraform "$target_path"
            ;;
        "report")
            if [[ -f "${TEMP_DIR}/available_updates.txt" ]]; then
                updates=()
                while IFS= read -r line; do
                    updates+=("$line")
                done < "${TEMP_DIR}/available_updates.txt"
                generate_update_report "${updates[@]}"
            else
                log "ERROR" "No update data found. Run check or update command first."
            fi
            ;;
        "restore")
            if [[ -n "$backup_path" ]]; then
                restore_from_backup "$backup_path"
            else
                log "ERROR" "No backup path specified for restore"
                exit 1
            fi
            ;;
        *)
            log "ERROR" "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
    
    log "INFO" "Terraform Dependency Updater completed"
}

# Script entry point
if [[ "${(%):-%N}" == "${0}" ]]; then
    main "$@"
fi