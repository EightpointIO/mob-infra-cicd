# Bulk Operations Script - Usage Examples

This document provides practical examples of using the `bulk-operations.sh` script for various infrastructure management tasks.

## Getting Started

```bash
# Make the script executable (first time only)
chmod +x scripts/bulk-operations.sh

# Show all available commands
./scripts/bulk-operations.sh --help
```

## Common Workflows

### 1. Daily Infrastructure Check

```bash
# Check the status of all Git repositories
./scripts/bulk-operations.sh git-status

# Example output:
# Found 3 Git repositories
# Repository: mob-infrastructure-cicd - Clean working directory
# Repository: mob-infrastructure-core - Untracked: TEST.md
# Repository: network - Modified: README.md
```

### 2. Terraform Maintenance

```bash
# Format all Terraform files
./scripts/bulk-operations.sh tf-fmt

# Validate all Terraform configurations
./scripts/bulk-operations.sh tf-validate

# Create plans for all configurations
./scripts/bulk-operations.sh tf-plan

# Do all terraform operations at once
./scripts/bulk-operations.sh tf-all
```

### 3. Security Review

```bash
# Run security scans (detects tools automatically)
./scripts/bulk-operations.sh security-scan

# Preview what would be scanned
./scripts/bulk-operations.sh security-scan --dry-run
```

### 4. Dependency Management

```bash
# Update dependencies in all projects
./scripts/bulk-operations.sh deps-update

# Preview dependency updates
./scripts/bulk-operations.sh deps-update --dry-run
```

### 5. Complete Maintenance Cycle

```bash
# Run comprehensive maintenance
./scripts/bulk-operations.sh maintenance

# With custom parallel jobs
./scripts/bulk-operations.sh maintenance --parallel 4

# Dry run to see what would be done
./scripts/bulk-operations.sh maintenance --dry-run
```

## Advanced Workflows

### 6. Git Workflow Automation

```bash
# Pull updates from all repositories
./scripts/bulk-operations.sh git-pull

# Commit changes with a message
./scripts/bulk-operations.sh git-commit "feat: update infrastructure configs"

# Push all committed changes
./scripts/bulk-operations.sh git-push

# Do all git operations in one command
./scripts/bulk-operations.sh git-all "feat: bulk infrastructure updates"
```

### 7. Parallel Processing Examples

```bash
# Default parallel processing (8 jobs)
./scripts/bulk-operations.sh tf-fmt

# Custom parallel job count
./scripts/bulk-operations.sh tf-fmt --parallel 12

# Conservative parallel processing (good for limited resources)
./scripts/bulk-operations.sh tf-fmt --parallel 2
```

### 8. Safety Features

```bash
# Preview operations without making changes
./scripts/bulk-operations.sh all --dry-run

# Run operations without creating backups (faster)
./scripts/bulk-operations.sh tf-fmt --no-backup

# Force operations even if warnings occur
./scripts/bulk-operations.sh tf-plan --force

# Rollback failed operations
./scripts/bulk-operations.sh rollback
```

## Real-World Scenarios

### Scenario 1: Weekly Infrastructure Review

```bash
#!/bin/bash
# weekly-review.sh

echo "=== Weekly Infrastructure Review ==="

# Check Git status
echo "Checking Git repositories..."
./scripts/bulk-operations.sh git-status

# Format and validate Terraform
echo "Terraform maintenance..."
./scripts/bulk-operations.sh tf-all

# Security scan
echo "Running security scans..."
./scripts/bulk-operations.sh security-scan

# Dependency updates
echo "Checking dependencies..."
./scripts/bulk-operations.sh deps-update --dry-run

echo "Review complete. Check logs for details."
```

### Scenario 2: Pre-Deployment Checks

```bash
#!/bin/bash
# pre-deployment.sh

echo "=== Pre-Deployment Validation ==="

# Ensure all terraform is formatted and valid
if ./scripts/bulk-operations.sh tf-all; then
    echo "✓ Terraform validation passed"
else
    echo "✗ Terraform validation failed"
    exit 1
fi

# Run security checks
if ./scripts/bulk-operations.sh security-scan; then
    echo "✓ Security scan passed"
else
    echo "⚠ Security issues detected, review required"
fi

echo "Pre-deployment checks complete"
```

### Scenario 3: Onboarding New Team Member

```bash
#!/bin/bash
# onboard-developer.sh

echo "=== Setting up development environment ==="

# Check current state
./scripts/bulk-operations.sh git-status

# Ensure everything is formatted properly
./scripts/bulk-operations.sh tf-fmt

# Update all dependencies
./scripts/bulk-operations.sh deps-update

# Run validation to ensure environment works
./scripts/bulk-operations.sh tf-validate

echo "Development environment ready!"
```

## Output Interpretation

### Success Indicators
- **Green ✓**: Operation completed successfully
- **Progress bars**: Show real-time progress
- **Success rate**: Overall operation success percentage

### Warning Signs
- **Yellow ⚠**: Warnings that need attention
- **Orange text**: Important information
- **High parallel job failures**: May indicate system resource limits

### Error Handling
- **Red ✗**: Failed operations
- **Error logs**: Detailed information in log files
- **Rollback available**: Use `rollback` command for failed operations

## Performance Tips

### Optimize Parallel Jobs
```bash
# For powerful machines
./scripts/bulk-operations.sh all --parallel 16

# For resource-constrained environments
./scripts/bulk-operations.sh all --parallel 2

# Find optimal setting by testing
time ./scripts/bulk-operations.sh tf-fmt --parallel 4
time ./scripts/bulk-operations.sh tf-fmt --parallel 8
```

### Network Operations
```bash
# Git operations may be slower over VPN
./scripts/bulk-operations.sh git-pull --parallel 4

# Local operations can handle more parallelism
./scripts/bulk-operations.sh tf-fmt --parallel 12
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Permission Errors
```bash
# Make script executable
chmod +x scripts/bulk-operations.sh

# Check file permissions
ls -la scripts/bulk-operations.sh
```

#### 2. Tool Not Found
```bash
# Check if terraform is installed
which terraform

# Check terraform version
terraform version

# Install missing tools as needed
```

#### 3. Parallel Job Failures
```bash
# Reduce parallel jobs
./scripts/bulk-operations.sh maintenance --parallel 2

# Check system resources
top
df -h
```

#### 4. Git Authentication Issues
```bash
# Check git configuration
git config --list

# Test git access
git ls-remote origin
```

### Log Analysis
```bash
# View latest log
tail -f scripts/logs/bulk-operations-*.log

# Search for errors
grep -i error scripts/logs/bulk-operations-*.log

# Check operation status
ls -la scripts/temp/status-*/
```

## Integration Examples

### CI/CD Pipeline
```yaml
# .github/workflows/infrastructure.yml
name: Infrastructure Validation

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        
      - name: Run bulk validation
        run: |
          chmod +x scripts/bulk-operations.sh
          ./scripts/bulk-operations.sh tf-all
          ./scripts/bulk-operations.sh security-scan
```

### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running pre-commit validation..."

if ./scripts/bulk-operations.sh tf-fmt --dry-run | grep -q "Would format"; then
    echo "Terraform files need formatting. Running terraform fmt..."
    ./scripts/bulk-operations.sh tf-fmt
    echo "Files formatted. Please stage the changes and commit again."
    exit 1
fi

echo "Pre-commit validation passed"
```

### Cron Job for Maintenance
```bash
# Add to crontab: crontab -e
# Run maintenance every Sunday at 2 AM
0 2 * * 0 /path/to/infrastructure-test/scripts/bulk-operations.sh maintenance --no-backup
```

## Best Practices

1. **Always use dry-run first** for destructive operations
2. **Test with limited parallelism** before scaling up
3. **Monitor logs** for performance and error patterns
4. **Regular maintenance** prevents accumulation of issues
5. **Backup before major operations** (enabled by default)
6. **Use appropriate parallel settings** based on system resources
7. **Review security scan results** regularly
8. **Keep dependencies updated** but test thoroughly

## Getting Help

```bash
# Show detailed help
./scripts/bulk-operations.sh --help

# Check script version and configuration
head -20 scripts/bulk-operations.sh

# View recent logs
ls -la scripts/logs/ | tail -5
```

For more detailed information, see the `BULK_OPERATIONS_README.md` file.