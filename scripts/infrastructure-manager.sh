#!/usr/bin/env zsh

# Infrastructure Manager - Simplified Orchestration Script
# Core infrastructure management operations with clean interface
# Created: $(date +%Y-%m-%d)

set -euo pipefail

# Version and metadata
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="Infrastructure Manager"

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color

# Unicode symbols
readonly CHECK_MARK="✓"
readonly CROSS_MARK="✗"
readonly WARNING_SIGN="⚠"
readonly INFO_SIGN="ℹ"

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
readonly BULK_OPERATIONS_SCRIPT="${SCRIPT_DIR}/bulk-operations.sh"
readonly WORKSPACE_SETUP_SCRIPT="${SCRIPT_DIR}/enhanced-workspace-setup.sh"

# Simple operation tracking
TOTAL_OPERATIONS=0
SUCCESSFUL_OPERATIONS=0
FAILED_OPERATIONS_COUNT=0

# Initialize environment
init_environment() {
    # Verify required scripts exist
    [[ ! -f "$BULK_OPERATIONS_SCRIPT" ]] && {
        print_error "Missing bulk-operations.sh script"
        exit 1
    }
    [[ ! -f "$WORKSPACE_SETUP_SCRIPT" ]] && {
        print_error "Missing enhanced-workspace-setup.sh script"
        exit 1
    }
    
    # Check for required system utilities
    command -v git >/dev/null 2>&1 || {
        print_error "Git is required but not installed"
        exit 1
    }
}

# Simple printing functions
print_header() {
    local text="$1"
    local border="$(printf '═%.0s' {1..60})"
    echo -e "\n${BLUE}${border}${NC}"
    echo -e "${WHITE}${BOLD}  $text${NC}"
    echo -e "${BLUE}${border}${NC}\n"
}

print_section() {
    local text="$1"
    echo -e "\n${CYAN}${BOLD}▶ $text${NC}"
}

print_success() {
    local text="$1"
    echo -e "${GREEN}${CHECK_MARK}${NC} $text"
}

print_error() {
    local text="$1"
    echo -e "${RED}${CROSS_MARK}${NC} $text" >&2
}

print_warning() {
    local text="$1"
    echo -e "${YELLOW}${WARNING_SIGN}${NC} $text"
}

print_info() {
    local text="$1"
    echo -e "${BLUE}${INFO_SIGN}${NC} $text"
}

# Simple operation tracking
track_operation() {
    local operation="$1"
    local op_status="$2"
    
    ((TOTAL_OPERATIONS++))
    if [[ "$op_status" == "success" ]]; then
        ((SUCCESSFUL_OPERATIONS++))
    else
        ((FAILED_OPERATIONS_COUNT++))
    fi
}

# Execute script with simple error handling
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
        chmod +x "$script_path"
    fi
    
    print_section "Executing $script_name"
    
    if [[ -n "$args" ]]; then
        if eval "$script_path $args"; then
            print_success "$script_name completed successfully"
            track_operation "$script_name" "success"
            return 0
        else
            print_error "$script_name failed"
            track_operation "$script_name" "failed"
            return 1
        fi
    else
        if "$script_path"; then
            print_success "$script_name completed successfully"
            track_operation "$script_name" "success"
            return 0
        else
            print_error "$script_name failed"
            track_operation "$script_name" "failed"
            return 1
        fi
    fi
}

# Simplified interactive menu system
show_main_menu() {
    clear
    print_header "🚀 Infrastructure Manager v$SCRIPT_VERSION"
    
    echo -e "${WHITE}Simple infrastructure management operations${NC}"
    echo -e "${DIM}Project: $(basename "$PROJECT_ROOT")${NC}\n"
    
    echo -e "${BOLD}Core Operations:${NC}"
    echo -e "  ${GREEN}1.${NC} 📁 Workspace Setup"
    echo -e "  ${GREEN}2.${NC} ⬇️  Pull All Repositories"
    echo -e "  ${GREEN}3.${NC} 📝 Commit & Push Changes"
    echo -e "  ${GREEN}4.${NC} 🔧 Format Terraform Files"
    
    echo -e "\n${CYAN}Git References:${NC}"
    echo -e "  ${GREEN}5.${NC} 📊 Show Reference Summary"
    echo -e "  ${GREEN}6.${NC} 🔄 Check for Drift"
    echo -e "  ${GREEN}7.${NC} ⬆️  Update References"
    
    echo -e "\n  ${RED}0.${NC} Exit"
    
    echo -e "\n${DIM}Choose an option (0-7):${NC} "
}

# Core operation functions
operation_git_pull() {
    print_header "⬇️ Pull All Repositories"
    print_info "Pulling latest changes from all repositories..."
    execute_script "$BULK_OPERATIONS_SCRIPT" "Git Pull All" "git-pull-all"
}

operation_git_commit_push() {
    print_header "📝 Commit & Push Changes"
    print_info "Committing and pushing changes to all repositories..."
    
    echo -e "\n${BLUE}Enter commit message:${NC} "
    read -r commit_message
    
    if [[ -z "$commit_message" ]]; then
        print_error "Commit message is required"
        return 1
    fi
    
    execute_script "$BULK_OPERATIONS_SCRIPT" "Git Commit & Push" "git-commit-push \"$commit_message\""
}

operation_terraform_format() {
    print_header "🔧 Format Terraform Files"
    print_info "Formatting all Terraform files..."
    execute_script "$BULK_OPERATIONS_SCRIPT" "Terraform Format" "tf-fmt"
}

operation_git_ref_summary() {
    print_header "📊 Git Reference Summary"
    print_info "Showing current git references across all repositories..."
    execute_script "$BULK_OPERATIONS_SCRIPT" "Git Reference Summary" "git-ref-summary"
}

operation_git_ref_drift() {
    print_header "🔄 Check for Reference Drift"
    print_info "Checking for outdated git references..."
    execute_script "$BULK_OPERATIONS_SCRIPT" "Git Reference Drift Detection" "git-ref-drift"
}

operation_git_ref_update() {
    print_header "⬆️ Update Git References"
    print_info "Updating git references to specific version..."
    
    echo -e "\n${BLUE}Enter target version (e.g., v1.0.6):${NC} "
    read -r target_version
    
    if [[ -z "$target_version" ]]; then
        print_error "Target version is required"
        return 1
    fi
    
    execute_script "$BULK_OPERATIONS_SCRIPT" "Git Reference Update" "git-ref-update $target_version"
}

operation_workspace_setup() {
    print_header "📁 Workspace Setup"
    print_info "Setting up infrastructure workspace with dynamic repository discovery..."
    print_info "Features: Interactive workspace selection, team-based organization, GitHub token auth"
    
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
    
    # Execute the workspace setup script
    print_section "Starting Workspace Setup"
    if [[ ! -f "$WORKSPACE_SETUP_SCRIPT" ]]; then
        print_error "Script not found: $WORKSPACE_SETUP_SCRIPT"
        track_operation "Workspace Setup" "failed"
        return 1
    fi
    
    if [[ ! -x "$WORKSPACE_SETUP_SCRIPT" ]]; then
        chmod +x "$WORKSPACE_SETUP_SCRIPT"
    fi
    
    # Run the workspace setup script directly
    if "$WORKSPACE_SETUP_SCRIPT"; then
        print_success "Workspace Setup completed successfully"
        track_operation "Workspace Setup" "success"
        return 0
    else
        print_error "Workspace Setup failed"
        track_operation "Workspace Setup" "failed"
        return 1
    fi
}

# Simple session summary
session_summary() {
    print_header "📈 Session Summary"
    
    echo -e "${BOLD}Operations Summary:${NC}"
    echo -e "  Total Operations: ${CYAN}$TOTAL_OPERATIONS${NC}"
    echo -e "  Successful: ${GREEN}$SUCCESSFUL_OPERATIONS${NC}"
    echo -e "  Failed: ${RED}$FAILED_OPERATIONS_COUNT${NC}"
    
    if [[ $TOTAL_OPERATIONS -gt 0 ]]; then
        local success_rate=$(( (SUCCESSFUL_OPERATIONS * 100) / TOTAL_OPERATIONS ))
        echo -e "  Success Rate: ${CYAN}${success_rate}%${NC}"
    fi
}

# CLI argument handling
handle_cli_args() {
    case "${1:-}" in
        --workspace)
            operation_workspace_setup
            ;;
        --pull)
            operation_git_pull
            ;;
        --commit-push)
            local message="${2:-}"
            if [[ -z "$message" ]]; then
                print_error "Commit message required for --commit-push"
                exit 1
            fi
            execute_script "$BULK_OPERATIONS_SCRIPT" "Git Commit & Push" "git-commit-push \"$message\""
            ;;
        --terraform-format|--tf-fmt)
            operation_terraform_format
            ;;
        --git-ref-summary)
            operation_git_ref_summary
            ;;
        --git-ref-drift)
            operation_git_ref_drift
            ;;
        --git-ref-update)
            local version="${2:-}"
            if [[ -z "$version" ]]; then
                print_error "Version required for --git-ref-update"
                exit 1
            fi
            execute_script "$BULK_OPERATIONS_SCRIPT" "Git Reference Update" "git-ref-update $version"
            ;;
        --version)
            echo -e "${BOLD}Infrastructure Manager${NC} v${CYAN}$SCRIPT_VERSION${NC}"
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

# Help function
show_help() {
    print_header "❓ Help & Examples"
    
    echo -e "${BOLD}Infrastructure Manager Help${NC}\n"
    
    echo -e "${BOLD}USAGE:${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} [OPTIONS]"
    
    echo -e "\n${BOLD}INTERACTIVE MODE:${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC}                    # Launch interactive menu"
    
    echo -e "\n${BOLD}CLI AUTOMATION:${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --workspace       # Setup infrastructure workspace"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --pull            # Pull all repositories"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --commit-push \"msg\"# Commit and push changes"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --tf-fmt          # Format Terraform files"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --git-ref-summary # Show git reference summary"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --git-ref-drift   # Check for outdated references"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --git-ref-update v1.0.6 # Update git references"
    
    echo -e "\n${BOLD}EXAMPLES:${NC}"
    echo -e "  ${DIM}# Setup workspace${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --workspace"
    
    echo -e "\n  ${DIM}# Pull all repositories${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --pull"
    
    echo -e "\n  ${DIM}# Commit and push changes${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --commit-push \"Update configurations\""
    
    echo -e "\n  ${DIM}# Format Terraform files${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --tf-fmt"
    
    echo -e "\n  ${DIM}# Check git reference drift${NC}"
    echo -e "  ${CYAN}./scripts/infrastructure-manager.sh${NC} --git-ref-drift"
    
    echo -e "\n${BLUE}💡${NC} ${DIM}Pro tip: Use the interactive menu for guided operations!${NC}"
}

# Interactive menu loop
interactive_mode() {
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) operation_workspace_setup ;;
            2) operation_git_pull ;;
            3) operation_git_commit_push ;;
            4) operation_terraform_format ;;
            5) operation_git_ref_summary ;;
            6) operation_git_ref_drift ;;
            7) operation_git_ref_update ;;
            0)
                print_info "Thank you for using Infrastructure Manager!"
                session_summary
                break
                ;;
            *)
                print_error "Invalid choice. Please select 0-7."
                sleep 1
                ;;
        esac
        
        if [[ $choice != 0 ]]; then
            echo -e "\n${DIM}Press Enter to continue...${NC}"
            read -r
        fi
    done
}

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
}

# Execute main function with all arguments
main "$@"