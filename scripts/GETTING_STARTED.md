# 🚀 Infrastructure Management Scripts - Getting Started

## 📍 Location
All infrastructure management scripts are now located in:
```
shared/mob-infrastructure-cicd/scripts/
```

## 🎯 Quick Start for Developers

### 1. **One-Click Infrastructure Management**
```bash
# From infrastructure root directory
./shared/mob-infrastructure-cicd/scripts/infrastructure-manager.sh
```

### 2. **Dynamic Repository Setup (New & Improved!)**
```bash
# Set your GitHub token
export GITHUB_TOKEN='your_github_token'

# Dynamic setup - discovers all repos automatically
./shared/mob-infrastructure-cicd/scripts/setup-workspace-dynamic.sh
```

### 3. **Create New Infrastructure Resources**
```bash
# Interactive mode - just follow the prompts!
./shared/mob-infrastructure-cicd/scripts/create-infrastructure-resource.sh

# Command line mode
./shared/mob-infrastructure-cicd/scripts/create-infrastructure-resource.sh -t ios -e dev -r monitoring
```

## 🔧 Daily Workflow Commands

### Quick Health Check
```bash
./shared/mob-infrastructure-cicd/scripts/infrastructure-manager.sh --health
```

### Daily Maintenance
```bash
./shared/mob-infrastructure-cicd/scripts/infrastructure-manager.sh --daily
```

### Weekly Reports
```bash
./shared/mob-infrastructure-cicd/scripts/infrastructure-manager.sh --weekly
```

## 📋 Available Scripts

| Script | Purpose | Key Features |
|--------|---------|-------------|
| `infrastructure-manager.sh` | **Master orchestrator** | Interactive menu, workflows, automation |
| `setup-workspace-dynamic.sh` | **Dynamic workspace setup** | GitHub API discovery, no hardcoded repos |
| `create-infrastructure-resource.sh` | **Create new resources** | Interactive, follows naming convention |
| `dynamic-repo-discovery.sh` | **Repository discovery** | GitHub API, pattern matching, caching |
| `health-reporter.sh` | **Health reporting** | Markdown, JSON, CSV, HTML reports |
| `compliance-checker.sh` | **Security compliance** | NIST, CIS, SOC2 standards |
| `maintenance-check.sh` | **Infrastructure health** | Security, performance, cleanup |
| `bulk-operations.sh` | **Bulk operations** | Git, Terraform, parallel processing |
| `dependency-updater.sh` | **Module updates** | Version management, smart updates |

## 🎨 Repository Naming Convention

The scripts automatically handle our naming convention:

### Standard Pattern
`{team}-infra-{environment}-{resource}`
- ✅ `ios-infra-dev-secrets`
- ✅ `android-infra-prod-eks`
- ✅ `ios-infra-global-route53`

### Exceptions
- ✅ `mob-infrastructure-cicd` (this repository!)
- ✅ `mob-infrastructure-core`

## 🔑 Setup Requirements

### GitHub Token (Required for API access)
```bash
# Create token at: https://github.com/settings/tokens
# Required scopes: repo, workflow
export GITHUB_TOKEN='ghp_your_token_here'

# Add to your shell profile for persistence
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.zshrc
```

### SSH Keys (Required for git operations)
```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to GitHub: https://github.com/settings/keys
```

## 🚀 New Developer Onboarding

### Complete Setup (Run Once)
```bash
# 1. Clone this repository
git clone https://github.com/EightpointIO/mob-infrastructure-cicd.git

# 2. Set up environment
export GITHUB_TOKEN='your_token'

# 3. Run complete setup
./scripts/infrastructure-manager.sh --setup
```

### Daily Usage
```bash
# Quick health check
./scripts/infrastructure-manager.sh --health

# Interactive menu for everything else
./scripts/infrastructure-manager.sh
```

## 📚 Documentation

Each script has comprehensive documentation:
- `INFRASTRUCTURE_MANAGER_README.md` - Master orchestrator guide
- `DYNAMIC_INFRASTRUCTURE_README.md` - Dynamic repository management
- `HEALTH_REPORTER_README.md` - Health reporting system
- `COMPLIANCE_CHECKER_README.md` - Security compliance
- And more...

## 🔗 Integration Examples

### CI/CD Pipeline
```yaml
# .github/workflows/infrastructure-check.yml
- name: Infrastructure Health Check
  run: ./shared/mob-infrastructure-cicd/scripts/infrastructure-manager.sh --health
```

### Daily Cron Job
```bash
# Add to crontab for daily maintenance
0 9 * * * cd /path/to/infrastructure && ./shared/mob-infrastructure-cicd/scripts/infrastructure-manager.sh --daily
```

## 🆘 Support

1. **Check Documentation**: Each script has detailed README files
2. **Run Help Commands**: All scripts support `--help`
3. **Interactive Mode**: Use `infrastructure-manager.sh` for guided experience
4. **Logs**: Check `scripts/logs/` for detailed operation logs

---

**🎉 Happy Infrastructure Management!** 

These scripts make managing complex infrastructure simple, safe, and efficient!