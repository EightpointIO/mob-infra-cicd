#!/usr/bin/env bash

# Enhanced Infrastructure Workspace Setup
# Discovers all infrastructure repositories with enhanced pattern matching and interactive setup
# Supports both legacy and new naming conventions

set -eo pipefail

# Color definitions
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly WHITE='\033[1;37m'
readonly DIM='\033[2m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_WORKSPACE="/Users/$(whoami)/Developer/infrastructure"
readonly GITHUB_ORG="${1:-EightpointIO}"
readonly NON_INTERACTIVE="${NON_INTERACTIVE:-false}"
readonly SKIP_AUTH_PROMPT="${SKIP_AUTH_PROMPT:-false}"

# Progress tracking
declare -a DISCOVERED_REPOS=()
declare -a CLONED_REPOS=()
declare -a UPDATED_REPOS=()
declare -a FAILED_REPOS=()

# Interactive workspace selection
select_workspace() {
    echo -e "${CYAN}${BOLD}Infrastructure Workspace Setup${NC}"
    echo -e "${CYAN}════════════════════════════════${NC}"
    echo
    
    # Non-interactive mode: use default workspace
    if [[ "$NON_INTERACTIVE" = "true" ]]; then
        WORKSPACE_DIR="$DEFAULT_WORKSPACE"
        echo -e "${GREEN}✓ Using default workspace (non-interactive):${NC} $WORKSPACE_DIR"
    else
        echo -e "${WHITE}Where would you like to set up the infrastructure workspace?${NC}"
        echo
        echo -e "  ${GREEN}1.${NC} Default location: ${CYAN}$DEFAULT_WORKSPACE${NC}"
        echo -e "  ${GREEN}2.${NC} Custom location"
        echo
        echo -e "${DIM}Choose an option (1-2, default: 1):${NC} "
        
        # Use timeout for read to avoid hanging
        if read -t 30 -r workspace_choice < /dev/tty; then
            case $workspace_choice in
                1|"")
                    WORKSPACE_DIR="$DEFAULT_WORKSPACE"
                    echo -e "${GREEN}✓ Using default workspace:${NC} $WORKSPACE_DIR"
                    ;;
                2)
                    echo -e "${CYAN}Enter custom workspace path:${NC} "
                    if read -t 30 -r custom_path < /dev/tty; then
                        if [[ -z "$custom_path" ]]; then
                            echo -e "${YELLOW}⚠ No path provided, using default${NC}"
                            WORKSPACE_DIR="$DEFAULT_WORKSPACE"
                        else
                            # Expand ~ to home directory
                            custom_path="${custom_path/#\~/$HOME}"
                            # Ensure absolute path
                            if [[ ! "$custom_path" = /* ]]; then
                                custom_path="$HOME/$custom_path"
                            fi
                            WORKSPACE_DIR="$custom_path"
                            echo -e "${GREEN}✓ Using custom workspace:${NC} $WORKSPACE_DIR"
                        fi
                    else
                        echo -e "${YELLOW}⚠ Input timeout, using default${NC}"
                        WORKSPACE_DIR="$DEFAULT_WORKSPACE"
                    fi
                    ;;
                *)
                    echo -e "${YELLOW}⚠ Invalid choice, using default${NC}"
                    WORKSPACE_DIR="$DEFAULT_WORKSPACE"
                    ;;
            esac
        else
            echo -e "${YELLOW}⚠ Input timeout, using default workspace${NC}"
            WORKSPACE_DIR="$DEFAULT_WORKSPACE"
        fi
    fi
    
    # Ensure the workspace directory exists
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        echo -e "${CYAN}Creating workspace directory...${NC}"
        mkdir -p "$WORKSPACE_DIR"
        echo -e "${GREEN}✓ Workspace directory created${NC}"
    else
        echo -e "${YELLOW}⚠ Workspace directory already exists${NC}"
        echo -e "${CYAN}ℹ Contents will be preserved and updated${NC}"
    fi
    echo
}

# Simple overall progress indicator that updates in place
show_overall_progress() {
    local current=$1
    local total=$2
    
    # Cap current at total to prevent overflow
    if [[ $current -gt $total ]]; then
        current=$total
    fi
    
    local percentage=$((current * 100 / total))
    # Cap percentage at 100%
    if [[ $percentage -gt 100 ]]; then
        percentage=100
    fi
    
    # Fixed bar length of 40 characters
    local filled=$((percentage * 40 / 100))
    local empty=$((40 - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    # Simple clean progress bar with fixed width
    printf "\r\033[2K${CYAN}Processing repositories${NC} |${bar}| ${BOLD}${GREEN}${percentage}%%${NC} ${DIM}($current/$total)${NC}"
    
    if [[ $current -eq $total ]]; then
        echo -e " ${GREEN}✓ Complete${NC}"
    fi
}

# Validate GitHub token format
validate_github_token() {
    local token="$1"
    
    # Check for various GitHub token formats
    if [[ "$token" =~ ^ghp_[a-zA-Z0-9]{36}$ ]]; then
        echo "classic-personal"
    elif [[ "$token" =~ ^ghs_[a-zA-Z0-9]{36}$ ]]; then
        echo "classic-server"
    elif [[ "$token" =~ ^github_pat_[a-zA-Z0-9_]{82}$ ]]; then
        echo "fine-grained"
    elif [[ "$token" =~ ^[a-fA-F0-9]{40}$ ]]; then
        echo "legacy-personal"
    else
        echo "unknown"
    fi
}

# Enhanced GitHub authentication setup
setup_github_auth() {
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        local token_type=$(validate_github_token "$GITHUB_TOKEN")
        echo -e "${GREEN}✓ Using existing GITHUB_TOKEN${NC} ${DIM}($token_type)${NC}"
        return 0
    fi
    
    # Skip auth prompt if handled by orchestrator
    if [[ "$SKIP_AUTH_PROMPT" = "true" ]]; then
        echo -e "${RED}✗ GITHUB_TOKEN environment variable required${NC}"
        echo -e "${CYAN}ℹ Please set GITHUB_TOKEN and retry${NC}"
        return 1
    fi
    
    # Non-interactive mode: require GITHUB_TOKEN to be set
    if [[ "$NON_INTERACTIVE" = "true" ]]; then
        echo -e "${RED}✗ GITHUB_TOKEN environment variable required in non-interactive mode${NC}"
        echo -e "${CYAN}ℹ Please set GITHUB_TOKEN and retry${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}⚠ GITHUB_TOKEN environment variable not set${NC}"
    echo -e "${CYAN}Repository discovery requires GitHub authentication${NC}"
    echo
    echo -e "${BOLD}GitHub Token Information:${NC}"
    echo -e "${DIM}• Classic tokens: https://github.com/settings/tokens${NC}"
    echo -e "${DIM}• Fine-grained tokens: https://github.com/settings/personal-access-tokens/new${NC}"
    echo -e "${DIM}• Required scope: 'repo' access for repository operations${NC}"
    echo
    echo -e "${WHITE}Please enter your GitHub Personal Access Token:${NC}"
    echo -e "${DIM}(Token will be hidden as you type and not logged)${NC}"
    
    # Prompt for token with hidden input and extended timeout
    local github_token
    echo -n -e "${CYAN}GitHub Token: ${NC}"
    
    # Try different input methods for better compatibility
    if [[ -t 0 ]]; then
        # Standard terminal input
        if read -t 120 -r -s github_token < /dev/tty; then
            echo # New line after hidden input
        else
            echo
            echo -e "${RED}✗ Input timeout (120 seconds). Setup cancelled.${NC}"
            echo -e "${YELLOW}💡 Tip: Set GITHUB_TOKEN environment variable to skip this prompt${NC}"
            return 1
        fi
    else
        # Fallback for non-interactive environments
        echo -e "${RED}✗ Non-interactive environment detected. Please set GITHUB_TOKEN environment variable.${NC}"
        return 1
    fi
    
    # Validate token is not empty
    if [[ -z "$github_token" ]]; then
        echo -e "${RED}✗ No token provided. Setup cancelled.${NC}"
        return 1
    fi
    
    # Validate token format
    local token_type=$(validate_github_token "$github_token")
    if [[ "$token_type" == "unknown" ]]; then
        echo -e "${YELLOW}⚠ Token format doesn't match expected GitHub patterns${NC}"
        echo -e "${DIM}Expected formats: ghp_..., ghs_..., github_pat_..., or 40-char hex${NC}"
        echo -e "${WHITE}Continue anyway? (y/N):${NC} "
        if read -t 30 -r confirm < /dev/tty; then
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo -e "${CYAN}ℹ Setup cancelled${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}⚠ Input timeout, cancelling setup${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Valid GitHub token detected${NC} ${DIM}($token_type)${NC}"
    fi
    
    # Export token for this session
    export GITHUB_TOKEN="$github_token"
    
    # Clear the local variable for security
    unset github_token
    return 0
}

# Call workspace and auth setup
select_workspace
if ! setup_github_auth; then
    exit 1
fi

echo -e "${CYAN}${BOLD}Dynamic Infrastructure Repository Discovery${NC}"
echo -e "${CYAN}Organization:${NC} $GITHUB_ORG"
echo -e "${CYAN}Workspace:${NC} $WORKSPACE_DIR"
echo

# Check for GitHub token
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo -e "${RED}✗ Error: GITHUB_TOKEN environment variable is required${NC}"
    exit 1
fi

# Create base directory structure
mkdir -p "$WORKSPACE_DIR/teams" "$WORKSPACE_DIR/shared" "$SCRIPT_DIR/temp"
echo -e "${GREEN}✓ Base directory structure ready${NC}"
echo

echo -e "${CYAN}🔍 Discovering infrastructure repositories...${NC}"

# Determine authentication header based on token format
auth_header="Authorization: token $GITHUB_TOKEN"
if [[ "$GITHUB_TOKEN" =~ ^github_pat_ ]]; then
    auth_header="Authorization: Bearer $GITHUB_TOKEN"
fi

# Fetch all repositories and filter for infrastructure with enhanced patterns
all_repos=""
page=1
total_repos_checked=0

while true; do
    echo -e "${DIM}Scanning page $page...${NC}"
    
    page_repos=$(curl -s -H "$auth_header" \
                     -H "Accept: application/vnd.github.v3+json" \
                     "https://api.github.com/orgs/$GITHUB_ORG/repos?per_page=100&page=$page" | \
                 jq -r '.[] | .name' 2>/dev/null || true)
    
    if [[ -z "$page_repos" ]]; then
        break
    fi
    
    repo_count=$(echo "$page_repos" | wc -l)
    total_repos_checked=$((total_repos_checked + repo_count))
    
    # Enhanced pattern matching for infrastructure repos
    infra_repos=$(echo "$page_repos" | grep -E '^(mob-infra-|mob-infrastructure-|[a-z]+-infra-|[a-z]+-infrastructure-)' || true)
    
    if [[ -n "$infra_repos" ]]; then
        if [[ -n "$all_repos" ]]; then
            all_repos="$all_repos"$'\n'"$infra_repos"
        else
            all_repos="$infra_repos"
        fi
    fi
    
    ((page++))
    # Safety limit to prevent infinite loops
    [[ $page -gt 20 ]] && break
done

echo -e "${CYAN}✓ Scanned $total_repos_checked repositories${NC}"

if [[ -z "$all_repos" ]]; then
    echo -e "${RED}✗ No infrastructure repositories found${NC}"
    echo -e "${YELLOW}⚠ Expected patterns: mob-infra-*, mob-infrastructure-*, team-infra-*${NC}"
    exit 1
fi

# Convert to array and display discovered repos
repos=()
while IFS= read -r repo; do
    [[ -n "$repo" ]] && repos+=("$repo")
done <<< "$all_repos"

DISCOVERED_REPOS=("${repos[@]}")
total=${#repos[@]}

echo -e "${GREEN}✓ Found $total infrastructure repositories${NC}"
echo

# Use simple arrays for compatibility with older bash versions
declare -a repo_list=("${repos[@]}")
declare -a status_list=()
declare -a org_info_list=()

# Function to determine organization info for a repo
get_org_info() {
    local repo="$1"
    if [[ "$repo" =~ ^mob-infra- ]] || [[ "$repo" =~ ^mob-infrastructure- ]]; then
        echo "shared/$repo"
        return
    fi
    
    if [[ "$repo" =~ ^([a-z]+)-infra-(global|dev|prod|staging)-(.+)$ ]]; then
        echo "teams/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/${BASH_REMATCH[3]}"
        return
    fi
    
    if [[ "$repo" =~ ^([a-z]+)-infra-(.+)$ ]]; then
        echo "teams/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        return
    fi
    
    echo "shared/$repo"
}

# Initialize status and org info arrays
for repo in "${repos[@]}"; do
    status_list+=("⏰")
    org_info_list+=("$(get_org_info "$repo")")
done

# Helper functions to get/set status by repo name
get_repo_index() {
    local search_repo="$1"
    local index=0
    for repo in "${repo_list[@]}"; do
        if [[ "$repo" == "$search_repo" ]]; then
            echo $index
            return
        fi
        ((index++))
    done
    echo -1
}

set_repo_status() {
    local repo="$1"
    local new_status="$2"
    local index=$(get_repo_index "$repo")
    if [[ $index -ge 0 ]]; then
        status_list[$index]="$new_status"
    fi
}

get_repo_status() {
    local repo="$1"
    local status_file="$SCRIPT_DIR/temp/status_${repo//[^a-zA-Z0-9]/_}"
    
    # Check if status file exists and read from it
    if [[ -f "$status_file" ]]; then
        cat "$status_file"
    else
        # Fall back to array-based status
        local index=$(get_repo_index "$repo")
        if [[ $index -ge 0 ]]; then
            echo "${status_list[$index]}"
        else
            echo "⏰"
        fi
    fi
}

get_repo_org_info() {
    local repo="$1"
    local index=$(get_repo_index "$repo")
    if [[ $index -ge 0 ]]; then
        echo "${org_info_list[$index]}"
    else
        echo "shared/$repo"
    fi
}

# Function to display the repository list with status
display_repo_list() {
    # Move cursor up by number of repos + 3 lines (header + blank lines)
    if [[ "${1:-}" != "first" ]]; then
        printf "\033[%dA" $((total + 3))
    fi
    
    echo -e "${CYAN}${BOLD}📦 Repository Processing Status:${NC}"
    echo
    
    local index=0
    for repo in "${repo_list[@]}"; do
        local status=$(get_repo_status "$repo")
        local org_info="${org_info_list[$index]}"
        printf "  %s ${WHITE}%s${NC} ${DIM}→ %s${NC}\n" "$status" "$repo" "$org_info"
        ((index++))
    done
    echo
}

# Process repository function with file-based status tracking for parallel processing
process_repo_simple() {
    local repo="$1"
    local workspace_dir="$2"
    local github_org="$3"
    
    # Create a status file for this repo in temp directory
    local status_file="$SCRIPT_DIR/temp/status_${repo//[^a-zA-Z0-9]/_}"
    
    # Update status to processing
    echo "🔄" > "$status_file"
    
    # Determine target directory
    local org_info=$(get_repo_org_info "$repo")
    local target_dir="$workspace_dir/${org_info}"
    
    # Create directory structure
    mkdir -p "$(dirname "$target_dir")"
    
    local repo_url="git@github.com:${github_org}/${repo}.git"
    
    # Process repository
    if [[ -d "$target_dir" ]]; then
        # Repository exists, update it
        if (cd "$target_dir" && git fetch --all --prune >/dev/null 2>&1 && 
            (git reset --hard origin/main >/dev/null 2>&1 || git reset --hard origin/master >/dev/null 2>&1)); then
            echo "✅" > "$status_file"
        else
            echo "❌" > "$status_file"
        fi
    else
        # Repository doesn't exist, clone it
        if git clone "$repo_url" "$target_dir" >/dev/null 2>&1; then
            echo "✅" > "$status_file"
        else
            echo "❌" > "$status_file"
        fi
    fi
}

# Display initial list
display_repo_list "first"

# Start background processes with debugging
echo -e "${CYAN}Starting ${#repos[@]} background processes...${NC}"

for repo in "${repos[@]}"; do
    process_repo_simple "$repo" "$WORKSPACE_DIR" "$GITHUB_ORG" &
done

echo -e "${CYAN}All processes started. Monitoring progress...${NC}"

# Monitor progress and update display
max_iterations=300  # 5 minutes timeout
iteration=0

while true; do
    # Count completed jobs
    active_jobs=$(jobs -r | wc -l)
    
    # Update display
    display_repo_list
    
    # Debug: Show active jobs count
    echo -e "${DIM}Active jobs: $active_jobs${NC}"
    
    # Check if all done
    if [[ $active_jobs -eq 0 ]]; then
        echo -e "${GREEN}All background processes completed${NC}"
        break
    fi
    
    # Timeout protection
    ((iteration++))
    if [[ $iteration -gt $max_iterations ]]; then
        echo -e "${YELLOW}Timeout reached, stopping monitoring${NC}"
        break
    fi
    
    sleep 1
done

# Wait for any remaining processes
wait

# Generate summary from status tracking
echo
echo -e "${GREEN}${BOLD}🎉 Repository processing completed!${NC}"
echo

# Count results by status
successful_count=0
failed_count=0
SUCCESSFUL_REPOS=()
FAILED_REPOS=()

index=0
for repo in "${repo_list[@]}"; do
    status=$(get_repo_status "$repo")
    org_info="${org_info_list[$index]}"
    
    if [[ "$status" == "✅" ]]; then
        ((successful_count++))
        SUCCESSFUL_REPOS+=("$repo → $org_info")
    elif [[ "$status" == "❌" ]]; then
        ((failed_count++))
        FAILED_REPOS+=("$repo")
    fi
    ((index++))
done

# Enhanced summary
echo -e "${CYAN}${BOLD}📊 Processing Summary:${NC}"
echo -e "  ${GREEN}✓ Total repositories:${NC} $total"
echo -e "  ${GREEN}✓ Successfully processed:${NC} $successful_count"
if [[ $failed_count -gt 0 ]]; then
    echo -e "  ${RED}❌ Failed operations:${NC} $failed_count"
fi

# Show successful operations
if [[ ${#SUCCESSFUL_REPOS[@]} -gt 0 ]]; then
    echo -e "\n${GREEN}${BOLD}✅ Successfully Processed:${NC}"
    printf '  • %s\n' "${SUCCESSFUL_REPOS[@]}"
fi

# Show failed operations
if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
    echo -e "\n${RED}${BOLD}❌ Failed:${NC}"
    printf '  • %s\n' "${FAILED_REPOS[@]}"
    echo -e "\n${YELLOW}💡 Check SSH keys and repository permissions for failed repos${NC}"
fi

echo -e "\n${CYAN}Workspace directory:${NC} $WORKSPACE_DIR"

# Create symlink to VS Code workspace file
workspace_file="$WORKSPACE_DIR/infrastructure-workspace.code-workspace"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_template="$script_dir/../workspace/infrastructure-workspace.code-workspace"
echo -e "${CYAN}📝 Creating workspace symlink...${NC}"

# Skip if workspace file already exists (to preserve existing setup)
if [[ -f "$workspace_file" ]] || [[ -L "$workspace_file" ]]; then
    echo -e "${YELLOW}⚠️  Workspace file already exists, skipping to preserve existing setup${NC}"
elif [[ -f "$workspace_template" ]]; then
    # Create symlink to the workspace template
    ln -s "shared/mob-infra-cicd/workspace/infrastructure-workspace.code-workspace" "$workspace_file"
else
    echo -e "${RED}❌ Workspace template not found: $workspace_template${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Enhanced VS Code workspace generated:${NC} $(basename "$workspace_file")"
echo -e "${CYAN}Open with:${NC} code '$workspace_file'"

# Copy important files to workspace root for easy access
echo -e "${CYAN}📋 Copying important files to workspace root...${NC}"

# Copy README.md from the infrastructure root if it exists
readme_source="$WORKSPACE_DIR/README.md"
if [[ -f "$readme_source" ]]; then
    echo -e "${GREEN}✓ README.md already exists in workspace root${NC}"
else
    # Look for README.md in common locations
    possible_readmes=(
        "$WORKSPACE_DIR/shared/mob-infra-cicd/README.md"
        "$WORKSPACE_DIR/shared/mob-infrastructure-cicd/README.md"
        "/Users/$(whoami)/Developer/infrastructure/README.md"
    )
    
    readme_copied=false
    for readme_path in "${possible_readmes[@]}"; do
        if [[ -f "$readme_path" ]]; then
            cp "$readme_path" "$WORKSPACE_DIR/README.md"
            echo -e "${GREEN}✓ README.md copied to workspace root${NC}"
            echo -e "  ${DIM}Source: $readme_path${NC}"
            readme_copied=true
            break
        fi
    done
    
    if [[ "$readme_copied" = false ]]; then
        echo -e "${YELLOW}⚠ README.md not found in expected locations${NC}"
        echo -e "${DIM}  Expected locations: ${possible_readmes[*]}${NC}"
    fi
fi

# Copy the main VS Code workspace file to root (keep the descriptive name)
workspace_root_file="$WORKSPACE_DIR/infrastructure-workspace.code-workspace"
if [[ "$workspace_file" != "$workspace_root_file" ]]; then
    cp "$workspace_file" "$workspace_root_file"
    echo -e "${GREEN}✓ VS Code workspace copied to root:${NC} infrastructure-workspace.code-workspace"
fi

# Display final recommendations
echo
echo -e "${CYAN}${BOLD}🚀 Next Steps:${NC}"
echo -e "  ${WHITE}1.${NC} Open VS Code workspace:"
echo -e "     ${CYAN}code '$workspace_root_file'${NC} ${DIM}(convenient root location)${NC}"
echo -e "     ${CYAN}code '$workspace_file'${NC} ${DIM}(original location)${NC}"
echo -e "  ${WHITE}2.${NC} Review repository structure in VS Code"
echo -e "  ${WHITE}3.${NC} Install recommended extensions when prompted"
echo -e "  ${WHITE}4.${NC} Check ${CYAN}README.md${NC} in workspace root for documentation"
if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
    echo -e "  ${WHITE}5.${NC} ${RED}Investigate failed repositories and check SSH keys/permissions${NC}"
fi

echo -e "\n${CYAN}📁 Workspace Files:${NC}"
echo -e "  ${WHITE}•${NC} ${CYAN}README.md${NC} - Project documentation"
echo -e "  ${WHITE}•${NC} ${CYAN}infrastructure-workspace.code-workspace${NC} - VS Code workspace"

echo -e "\n${DIM}💡 Tip: Re-run this script anytime to discover new infrastructure repositories!${NC}"

# Cleanup temp status files
if [[ -d "$SCRIPT_DIR/temp" ]]; then
    rm -f "$SCRIPT_DIR/temp/status_"*
fi