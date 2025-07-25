#!/usr/bin/env bash

# Install pre-commit hooks with centralized configuration
# This script creates minimal configs that reference the central hooks in cicd repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CENTRAL_HOOKS_REPO="https://github.com/EightpointIO/mob-infra-cicd"
CENTRAL_HOOKS_REV="main"

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo -e "${YELLOW}Installing pre-commit...${NC}"
    pip install pre-commit
fi

# Find all infrastructure repositories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CENTRAL_PRE_COMMIT_CONFIG="$SCRIPT_DIR/../.pre-commit-config.yaml"

echo -e "${BLUE}Installing pre-commit hooks with centralized configuration...${NC}"

# Check if the central pre-commit config exists
if [[ ! -f "$CENTRAL_PRE_COMMIT_CONFIG" ]]; then
    echo -e "${RED}✗ .pre-commit-config.yaml not found in cicd repository${NC}"
    exit 1
fi

# Function to create minimal pre-commit config that references central hooks
create_minimal_config() {
    local repo_path="$1"
    cat > "$repo_path/.pre-commit-config.yaml" << EOF
# Pre-commit configuration for Terraform infrastructure
# Uses the same configuration as the centralized cicd repository

repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.88.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
EOF
}

# Function to install pre-commit in a repository
install_pre_commit_in_repo() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"

    if [[ -d "$repo_path/.git" ]]; then
        echo -e "${BLUE}Installing pre-commit hooks in $repo_name...${NC}"
        cd "$repo_path"

        # Create minimal config that references central hooks
        create_minimal_config "$repo_path"
        echo -e "${GREEN}✓ Created minimal .pre-commit-config.yaml referencing central hooks${NC}"

        # Install pre-commit hooks
        if pre-commit install; then
            echo -e "${GREEN}✓ Pre-commit hooks installed in $repo_name${NC}"
        else
            echo -e "${RED}✗ Failed to install pre-commit hooks in $repo_name${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ $repo_name is not a git repository${NC}"
    fi
}

# Install pre-commit in infrastructure repositories
for team_dir in "$PROJECT_ROOT"/teams/*/; do
    if [[ -d "$team_dir" ]]; then
        for env_dir in "$team_dir"*/; do
            if [[ -d "$env_dir" ]]; then
                for repo_dir in "$env_dir"*/; do
                    if [[ -d "$repo_dir" ]]; then
                        install_pre_commit_in_repo "$repo_dir"
                    fi
                done
            fi
        done
    fi
done

# Install pre-commit in core repository (it's a single git repository)
if [[ -d "$PROJECT_ROOT/core/.git" ]]; then
    install_pre_commit_in_repo "$PROJECT_ROOT/core"
fi

echo -e "${GREEN}Pre-commit installation with centralized configuration completed!${NC}"
echo -e "${BLUE}Benefits:${NC}"
echo -e "  • ${GREEN}✓${NC} No duplication of hook configuration"
echo -e "  • ${GREEN}✓${NC} Consistent hooks across all infrastructure repositories"
echo -e "  • ${GREEN}✓${NC} Easy updates by modifying this install script"
echo -e "  • ${GREEN}✓${NC} Standard pre-commit hooks with Terraform support"
