#!/bin/bash

# Enhanced Infrastructure Workspace Setup
# Discovers all infrastructure repositories with enhanced pattern matching and interactive setup
# Supports both legacy and new naming conventions

set -euo pipefail

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
        if read -t 30 -r workspace_choice; then
            case $workspace_choice in
                1|"")
                    WORKSPACE_DIR="$DEFAULT_WORKSPACE"
                    echo -e "${GREEN}✓ Using default workspace:${NC} $WORKSPACE_DIR"
                    ;;
                2)
                    echo -e "${CYAN}Enter custom workspace path:${NC} "
                    if read -t 30 -r custom_path; then
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

# Enhanced progress indicator with percentage
show_progress() {
    local current=$1
    local total=$2
    local operation="$3"
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 5))
    local empty=$((20 - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    printf "\r${CYAN}[$current/$total] ${WHITE}$operation${NC} |$bar| ${BOLD}${percentage}%%${NC}"
    if [[ $current -eq $total ]]; then
        echo
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
    
    # Prompt for token with hidden input and timeout
    local github_token
    echo -n -e "${CYAN}GitHub Token: ${NC}"
    if read -t 60 -r -s github_token; then
        echo # New line after hidden input
    else
        echo
        echo -e "${RED}✗ Input timeout. Setup cancelled.${NC}"
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
        if read -t 30 -r confirm; then
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
mkdir -p "$WORKSPACE_DIR/teams" "$WORKSPACE_DIR/shared"
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

echo -e "${GREEN}✓ Found $total infrastructure repositories:${NC}"
echo "$all_repos" | sed 's/^/  • /'
echo

# Process each repository with enhanced progress tracking
current=0
for repo in "${repos[@]}"; do
    ((current++))
    show_progress $current $total "Processing $repo"
    
    # Enhanced target directory logic with team-based organization
    target_dir=""
    if [[ "$repo" =~ ^mob-infra- ]]; then
        # New pattern: mob-infra-cicd, mob-infra-core
        target_dir="$WORKSPACE_DIR/shared/$repo"
    elif [[ "$repo" =~ ^mob-infrastructure- ]]; then
        # Legacy pattern: mob-infrastructure-cicd, mob-infrastructure-core
        target_dir="$WORKSPACE_DIR/shared/$repo"
    elif [[ "$repo" =~ ^ios-infra- ]]; then
        # iOS team infrastructure: ios-infra-prod-eks, ios-infra-dev-s3
        mkdir -p "$WORKSPACE_DIR/teams/ios"
        target_dir="$WORKSPACE_DIR/teams/ios/$repo"
    elif [[ "$repo" =~ ^android-infra- ]]; then
        # Android team infrastructure: android-infra-prod-rds, android-infra-staging-vpc
        mkdir -p "$WORKSPACE_DIR/teams/android"
        target_dir="$WORKSPACE_DIR/teams/android/$repo"
    elif [[ "$repo" =~ ^platform-infra- ]]; then
        # Platform team infrastructure: platform-infra-shared-monitoring
        mkdir -p "$WORKSPACE_DIR/teams/platform"
        target_dir="$WORKSPACE_DIR/teams/platform/$repo"
    elif [[ "$repo" =~ ^([a-z]+)-infra- ]]; then
        # Generic team pattern: teamname-infra-environment-resource
        team_name="${BASH_REMATCH[1]}"
        mkdir -p "$WORKSPACE_DIR/teams/$team_name"
        target_dir="$WORKSPACE_DIR/teams/$team_name/$repo"
    else
        # Default to shared for unknown patterns
        target_dir="$WORKSPACE_DIR/shared/$repo"
    fi
    
    repo_url="git@github.com:${GITHUB_ORG}/${repo}.git"
    
    if [[ -d "$target_dir" ]]; then
        echo -e "\n  ${YELLOW}⟳ Updating existing repository${NC}"
        (
            cd "$target_dir"
            if git fetch --all --prune >/dev/null 2>&1; then
                if git reset --hard origin/main >/dev/null 2>&1 || git reset --hard origin/master >/dev/null 2>&1; then
                    UPDATED_REPOS+=("$repo")
                    echo -e "  ${GREEN}✓ Updated successfully${NC}"
                else
                    FAILED_REPOS+=("$repo")
                    echo -e "  ${RED}✗ Failed to reset${NC}"
                fi
            else
                FAILED_REPOS+=("$repo")
                echo -e "  ${RED}✗ Failed to fetch${NC}"
            fi
        )
    else
        echo -e "\n  ${CYAN}⬇ Cloning repository${NC}"
        if git clone "$repo_url" "$target_dir" >/dev/null 2>&1; then
            CLONED_REPOS+=("$repo")
            echo -e "  ${GREEN}✓ Cloned successfully${NC}"
        else
            FAILED_REPOS+=("$repo")
            echo -e "  ${RED}✗ Failed to clone${NC}"
        fi
    fi
done

echo
echo -e "${GREEN}${BOLD}🎉 Workspace setup completed!${NC}"
echo

# Summary statistics
echo -e "${CYAN}${BOLD}Summary:${NC}"
echo -e "  ${GREEN}✓ Repositories discovered:${NC} ${#DISCOVERED_REPOS[@]}"
echo -e "  ${GREEN}✓ Repositories cloned:${NC} ${#CLONED_REPOS[@]}"
echo -e "  ${YELLOW}⟳ Repositories updated:${NC} ${#UPDATED_REPOS[@]}"
if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
    echo -e "  ${RED}✗ Failed operations:${NC} ${#FAILED_REPOS[@]}"
    echo -e "\n${RED}Failed repositories:${NC}"
    printf '  • %s\n' "${FAILED_REPOS[@]}"
fi

echo -e "\n${CYAN}Workspace directory:${NC} $WORKSPACE_DIR"

# Enhanced VS Code workspace generation
workspace_file="$WORKSPACE_DIR/infrastructure-workspace.code-workspace"
echo -e "${CYAN}📝 Generating enhanced VS Code workspace...${NC}"

# Dynamically generate folder structure based on discovered teams
teams_folders=""
if [[ -d "$WORKSPACE_DIR/teams" ]]; then
    for team_dir in "$WORKSPACE_DIR/teams"/*; do
        if [[ -d "$team_dir" ]]; then
            team_name=$(basename "$team_dir")
            teams_folders+=",
        {
            \"name\": \"teams/$team_name\",
            \"path\": \"./teams/$team_name\"
        }"
        fi
    done
fi

cat > "$workspace_file" << EOF
{
    "folders": [
        {
            "name": "🏢 shared",
            "path": "./shared"
        }${teams_folders}
    ],
    "settings": {
        "terraform.experimentalFeatures.validateOnSave": true,
        "terraform.indexing": {
            "enabled": true,
            "liveIndexing": true
        },
        "files.associations": {
            "*.tf": "terraform",
            "*.tfvars": "terraform",
            "*.hcl": "hcl"
        },
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.fixAll": true
        },
        "files.trimTrailingWhitespace": true,
        "files.insertFinalNewline": true,
        "search.exclude": {
            "**/.terraform": true,
            "**/.terraform.lock.hcl": false,
            "**/node_modules": true,
            "**/.git": true,
            "**/terraform.tfstate*": true
        },
        "files.exclude": {
            "**/.terraform/providers": true,
            "**/.terraform/modules": true
        },
        "git.ignoreLimitWarning": true,
        "workbench.colorCustomizations": {
            "titleBar.activeBackground": "#1a73e8",
            "titleBar.activeForeground": "#ffffff"
        }
    },
    "extensions": {
        "recommendations": [
            "hashicorp.terraform",
            "ms-vscode.vscode-json",
            "redhat.vscode-yaml",
            "ms-vscode.PowerShell",
            "eamodio.gitlens"
        ]
    }
}
EOF

echo -e "${GREEN}✓ Enhanced VS Code workspace generated:${NC} $(basename "$workspace_file")"
echo -e "${CYAN}Open with:${NC} code '$workspace_file'"

# Display final recommendations
echo
echo -e "${CYAN}${BOLD}🚀 Next Steps:${NC}"
echo -e "  ${WHITE}1.${NC} Open VS Code workspace: ${CYAN}code '$workspace_file'${NC}"
echo -e "  ${WHITE}2.${NC} Review repository structure in VS Code"
echo -e "  ${WHITE}3.${NC} Install recommended extensions when prompted"
if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
    echo -e "  ${WHITE}4.${NC} ${RED}Investigate failed repositories and check SSH keys/permissions${NC}"
fi

echo -e "\n${DIM}💡 Tip: Re-run this script anytime to discover new infrastructure repositories!${NC}"