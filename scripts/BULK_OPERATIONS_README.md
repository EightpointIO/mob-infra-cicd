# Bulk Operations Script

The `bulk-operations.sh` script provides comprehensive bulk operations for Git repositories, Terraform configurations, security scanning, and dependency management with parallel execution, progress tracking, and rollback capabilities.

## Features

- **Parallel Execution**: Configurable parallel job execution for improved performance
- **Progress Tracking**: Real-time progress bars and status indicators
- **Colored Output**: Color-coded output for better readability
- **Comprehensive Logging**: Detailed logging with timestamps
- **Rollback Capabilities**: Backup and rollback functionality for failed operations
- **Dry Run Mode**: Preview operations without making changes
- **Cross-Platform**: Compatible with bash 3.2+ (macOS/Linux)

## Quick Start

```bash
# Make the script executable
chmod +x scripts/bulk-operations.sh

# Show help
./scripts/bulk-operations.sh --help

# Check status of all Git repositories
./scripts/bulk-operations.sh git-status

# Run maintenance tasks (format, validate, security scan)
./scripts/bulk-operations.sh maintenance --dry-run

# Full Git workflow with commit message
./scripts/bulk-operations.sh git-all "Update infrastructure configs"
```

## Available Operations

### Git Operations

| Command | Description |
|---------|-------------|
| `git-status` | Show status of all Git repositories |
| `git-pull` | Pull updates for all Git repositories |
| `git-commit "message"` | Commit changes to all Git repositories |
| `git-push` | Push changes for all Git repositories |
| `git-all "message"` | Pull, commit with message, and push for all repos |

### Terraform Operations

| Command | Description |
|---------|-------------|
| `tf-fmt` | Format all Terraform files |
| `tf-validate` | Validate all Terraform configurations |
| `tf-plan` | Create plans for all Terraform configurations |
| `tf-all` | Format, validate, and plan all Terraform configs |

### Security Operations

| Command | Description |
|---------|-------------|
| `security-scan` | Run security scans on all code |

### Dependency Operations

| Command | Description |
|---------|-------------|
| `deps-update` | Update dependencies in all projects |

### Bulk Operations

| Command | Description |
|---------|-------------|
| `all` | Run all operations (git, terraform, security, deps) |
| `maintenance` | Run maintenance tasks (format, validate, security) |
| `rollback` | Rollback all failed operations |

## Command Line Options

| Option | Description |
|--------|-------------|
| `--parallel N` | Set maximum parallel jobs (default: 8) |
| `--no-backup` | Skip creating backups |
| `--force` | Force operations even if warnings |
| `--dry-run` | Show what would be done without executing |
| `-h, --help` | Show help message |

## Examples

### Basic Operations

```bash
# Check Git status across all repositories
./scripts/bulk-operations.sh git-status

# Format all Terraform files
./scripts/bulk-operations.sh tf-fmt

# Run security scan
./scripts/bulk-operations.sh security-scan
```

### Advanced Operations

```bash
# Run maintenance with custom parallel jobs
./scripts/bulk-operations.sh maintenance --parallel 4

# Full Git workflow with commit message
./scripts/bulk-operations.sh git-all "feat: update terraform modules"

# Dry run to see what would be done
./scripts/bulk-operations.sh all --dry-run

# Format and validate Terraform with backups disabled
./scripts/bulk-operations.sh tf-all --no-backup
```

### Safety Operations

```bash
# Rollback failed operations
./scripts/bulk-operations.sh rollback

# Force operations even with warnings
./scripts/bulk-operations.sh tf-plan --force
```

## Directory Structure

The script creates the following directory structure:

```
scripts/
├── bulk-operations.sh          # Main script
├── logs/                       # Operation logs
│   └── bulk-operations-*.log
├── backups/                    # Operation backups
│   └── *-backup-*/
└── temp/                       # Temporary files
    ├── status-*/               # Operation status files
    ├── security-scans-*/       # Security scan results
    └── terraform-plans-*/      # Terraform plan files
```

## Supported Tools

### Security Scanning
- **checkov**: Infrastructure security scanning
- **tfsec**: Terraform security scanning
- **semgrep**: Code security analysis
- **bandit**: Python security linting

### Dependency Management
- **npm/yarn**: Node.js dependencies
- **pip**: Python dependencies
- **bundle**: Ruby dependencies
- **go**: Go modules
- **cargo**: Rust dependencies
- **composer**: PHP dependencies

## Configuration

### Parallel Jobs
Default: 8 parallel jobs
```bash
# Custom parallel job count
./scripts/bulk-operations.sh maintenance --parallel 12
```

### Environment Variables
The script respects standard tool configurations:
- Git: Uses global Git configuration
- Terraform: Uses current Terraform version
- Package managers: Use default configurations

## Output and Logging

### Console Output
- **Green ✓**: Successful operations
- **Red ✗**: Failed operations
- **Yellow ⚠**: Warnings
- **Blue ℹ**: Information
- **Purple ⟳**: Progress indicators
- **Cyan >>>**: Section headers

### Log Files
Detailed logs are saved to:
```
scripts/logs/bulk-operations-YYYYMMDD-HHMMSS.log
```

### Progress Tracking
Real-time progress bars show:
- Current operation
- Progress percentage
- Completed/Total operations

## Error Handling and Recovery

### Automatic Backups
Before making changes, the script creates backups of:
- Git repository state (stash, logs, status)
- Terraform lock files
- Other relevant state files

### Rollback Functionality
If operations fail, you can rollback using:
```bash
./scripts/bulk-operations.sh rollback
```

### Parallel Job Management
- Jobs are limited by `--parallel` setting
- Failed jobs are tracked and reported
- Cleanup handles interrupted operations

## Troubleshooting

### Common Issues

1. **Bash Version Error**
   ```bash
   # Check bash version
   bash --version
   # Requires bash 3.2+
   ```

2. **Permission Denied**
   ```bash
   chmod +x scripts/bulk-operations.sh
   ```

3. **Tool Not Found**
   ```bash
   # Install required tools
   # Terraform: https://terraform.io/downloads
   # Git: Should be pre-installed
   ```

4. **Parallel Job Limits**
   ```bash
   # Reduce parallel jobs if system resources are limited
   ./scripts/bulk-operations.sh maintenance --parallel 2
   ```

### Debug Mode
For debugging, check the log files:
```bash
tail -f scripts/logs/bulk-operations-*.log
```

### Cleanup
Clean up temp files and old logs:
```bash
# Remove old logs (older than 7 days)
find scripts/logs -name "*.log" -mtime +7 -delete

# Remove temp files
rm -rf scripts/temp/*
```

## Security Considerations

- **Credentials**: Never commit credentials to Git repositories
- **Backups**: Backup files may contain sensitive information
- **Parallel Execution**: Be cautious with API rate limits
- **Dry Run**: Always test with `--dry-run` first

## Integration

### CI/CD Integration
```yaml
# Example GitHub Actions integration
- name: Run bulk maintenance
  run: |
    ./scripts/bulk-operations.sh maintenance --no-backup
```

### Pre-commit Hooks
```bash
# Add to .pre-commit-config.yaml
- repo: local
  hooks:
    - id: bulk-terraform-fmt
      name: Terraform Format
      entry: ./scripts/bulk-operations.sh tf-fmt
```

## Performance Tips

1. **Parallel Jobs**: Adjust based on system resources
2. **Network Operations**: Git operations may be slower over network
3. **Large Repositories**: Consider excluding large directories
4. **Security Scans**: Can be time-consuming; run separately if needed

## Contributing

When modifying the script:
1. Test with various bash versions (3.2+)
2. Use `--dry-run` for testing
3. Add appropriate logging
4. Update this documentation

## License

This script is part of the infrastructure testing workspace and follows the same licensing terms as the parent project.