# Terraform Dependency Updater

A comprehensive script for intelligently updating Terraform module versions, provider versions, and GitHub releases with safety checks, validation, and comprehensive reporting.

## Features

- **Intelligent Version Updates**: Supports multiple version pinning strategies (patch, minor, major, exact)
- **Safety Checks**: Creates backups, validates configurations, and checks for breaking changes
- **GitHub Integration**: Automatically fetches latest releases from GitHub repositories
- **Provider Updates**: Updates Terraform provider versions using the Terraform Registry API
- **Comprehensive Reporting**: Generates detailed update reports and changelogs
- **Git Integration**: Creates pull requests with detailed change descriptions
- **Validation**: Runs `terraform validate` and `terraform plan` to ensure updates don't break infrastructure
- **Flexible Configuration**: Customizable through configuration files and command-line options

## Installation

1. Ensure the script is executable:
   ```bash
   chmod +x scripts/dependency-updater.sh
   ```

2. Install required dependencies:
   ```bash
   # Required tools
   terraform  # For validation
   git        # For version control
   jq         # For JSON parsing
   curl       # For API requests
   
   # Optional but recommended
   gh         # GitHub CLI for PR creation
   hcl2json   # For better HCL parsing
   tflint     # For additional validation
   checkov    # For security checks
   ```

## Usage

### Basic Commands

```bash
# Check for available updates
./scripts/dependency-updater.sh check

# Preview updates without applying (dry run)
./scripts/dependency-updater.sh update --dry-run

# Update dependencies with validation
./scripts/dependency-updater.sh update --validate

# Update with backup and create PR
./scripts/dependency-updater.sh update --backup --create-pr

# Update only providers
./scripts/dependency-updater.sh providers

# Update only modules
./scripts/dependency-updater.sh modules

# Validate current configuration
./scripts/dependency-updater.sh validate

# Generate update report
./scripts/dependency-updater.sh report

# Restore from backup
./scripts/dependency-updater.sh restore --backup-path /path/to/backup
```

### Advanced Usage

```bash
# Use specific version strategy
./scripts/dependency-updater.sh update --strategy minor

# Target specific directory
./scripts/dependency-updater.sh update --target teams/ios/dev

# Exclude test directories
./scripts/dependency-updater.sh update --exclude "**/test/**"

# Use custom configuration
./scripts/dependency-updater.sh update --config custom.config

# Force updates without confirmation
./scripts/dependency-updater.sh update --force

# Update only if versions are older than 30 days
./scripts/dependency-updater.sh update --max-age 30
```

## Configuration

Create `scripts/dependency-updater.config` to customize behavior:

```bash
# Version pinning strategy (patch|minor|major|exact)
DEFAULT_STRATEGY=minor

# Automatic backup creation
AUTO_BACKUP=true

# Automatic validation after updates
AUTO_VALIDATE=true

# GitHub organization
GITHUB_ORG=EightpointIO

# Excluded paths
EXCLUDED_PATHS=(
    "**/test/**"
    "**/examples/**"
)
```

## Version Strategies

- **patch**: Only update patch versions (1.0.0 → 1.0.1)
- **minor**: Update minor and patch versions (1.0.0 → 1.1.0)
- **major**: Update to any newer version (1.0.0 → 2.0.0)
- **exact**: Keep exact version, no updates

## Safety Features

### Automatic Backups
- Creates timestamped backups before making changes
- Stores backup manifest with git commit information
- Provides restore functionality

### Validation
- Runs `terraform init` if needed
- Executes `terraform validate` on modified configurations
- Performs `terraform plan` to check for unexpected changes
- Configurable timeout for validation operations

### Change Detection
- Parses Terraform files to extract current versions
- Compares with latest available versions
- Applies version strategy constraints
- Only updates when beneficial

## GitHub Integration

### API Usage
- Fetches latest releases from GitHub repositories
- Respects rate limiting with automatic retries
- Supports GitHub token authentication
- Falls back gracefully when API is unavailable

### Pull Request Creation
- Creates feature branches with descriptive names
- Generates detailed PR descriptions
- Includes update summaries and validation results
- Links to generated reports

## Reporting

### Update Reports
Generated in `scripts/reports/update-report-{timestamp}.md`:
- Summary of all updates applied
- Before/after version comparisons
- Validation results
- Recommendations for testing

### Changelogs
Generated in `scripts/reports/changelog-{timestamp}.md`:
- Structured changelog format
- Grouped by update type (modules, providers)
- Version change details

## File Structure

```
scripts/
├── dependency-updater.sh          # Main script
├── dependency-updater.config      # Configuration file
├── logs/                          # Execution logs
├── backups/                       # Automatic backups
├── temp/                          # Temporary files
└── reports/                       # Generated reports
```

## Examples

### Example 1: Daily Dependency Check
```bash
#!/bin/bash
# Add to cron for daily checks
cd /path/to/infrastructure
./scripts/dependency-updater.sh check > daily-check.log 2>&1
```

### Example 2: Staged Update Process
```bash
# 1. Check what's available
./scripts/dependency-updater.sh check

# 2. Preview changes
./scripts/dependency-updater.sh update --dry-run

# 3. Update development environment first
./scripts/dependency-updater.sh update --target teams/*/dev --validate

# 4. Update staging with PR creation
./scripts/dependency-updater.sh update --target teams/*/staging --create-pr
```

### Example 3: Emergency Security Update
```bash
# Force major version updates for security patches
./scripts/dependency-updater.sh update \
    --strategy major \
    --force \
    --validate \
    --create-pr \
    --backup
```

## Troubleshooting

### Common Issues

1. **Terraform Init Failures**
   ```bash
   # Clean terraform state and retry
   rm -rf .terraform .terraform.lock.hcl
   ./scripts/dependency-updater.sh validate
   ```

2. **GitHub API Rate Limiting**
   ```bash
   # Set GitHub token
   export GITHUB_TOKEN=your_token_here
   ./scripts/dependency-updater.sh update
   ```

3. **Validation Timeouts**
   ```bash
   # Increase timeout in config
   VALIDATION_TIMEOUT=600
   ```

### Log Analysis
```bash
# View latest log
tail -f scripts/logs/dependency-updater-*.log

# Search for errors
grep -i error scripts/logs/dependency-updater-*.log

# Check validation results
grep -A 5 -B 5 "validation" scripts/logs/dependency-updater-*.log
```

## Best Practices

1. **Testing Strategy**
   - Always test updates in development environments first
   - Use `--dry-run` to preview changes
   - Review generated reports before deploying

2. **Version Management**
   - Use `minor` strategy for most updates
   - Use `patch` for production environments
   - Review major version updates manually

3. **Automation**
   - Run regular checks (daily/weekly)
   - Automate development environment updates
   - Require manual approval for production

4. **Monitoring**
   - Monitor infrastructure after updates
   - Keep backup retention policy
   - Track update frequency and success rates

## Security Considerations

- Always validate GitHub sources for modules
- Review provider updates for breaking changes
- Use signed commits for automated updates
- Implement approval workflows for critical paths
- Monitor for supply chain attacks

## Contributing

To enhance the dependency updater:

1. Add new version strategies in `apply_version_strategy()`
2. Implement additional validation checks
3. Add support for new Terraform features
4. Enhance reporting capabilities
5. Add integration with other tools (Slack, JIRA, etc.)

## License

This script is part of the infrastructure management toolkit and follows the same licensing as the parent project.