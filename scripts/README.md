# Infrastructure Maintenance Scripts

This directory contains scripts for maintaining and monitoring your Terraform infrastructure repository.

## maintenance-check.sh

A comprehensive maintenance and health check script for Terraform infrastructure repositories.

### Features

The script performs the following checks:

1. **Infrastructure Health Checking**
   - Large .terraform directories detection
   - Exposed state files verification
   - Backend configuration validation
   - Provider version constraints checking

2. **Security Scanning**
   - Hardcoded secrets/passwords detection
   - Insecure configuration patterns
   - File permissions verification

3. **Module Version Consistency**
   - Module version consistency across configurations
   - Unversioned module detection

4. **Git Configuration**
   - .gitignore completeness verification
   - Tracked sensitive files detection

5. **Code Quality**
   - Terraform formatting checks
   - Indentation consistency verification

6. **Repository Monitoring**
   - Repository size analysis
   - Large file detection
   - Directory size monitoring

7. **Performance Metrics**
   - Resource count statistics
   - Complexity analysis
   - File size monitoring

8. **Cleanup Recommendations**
   - Temporary file identification
   - Old log file detection
   - Unused variable analysis
   - Code duplication detection

### Usage

```bash
# Run all checks (default)
./scripts/maintenance-check.sh

# Run specific checks
./scripts/maintenance-check.sh --security
./scripts/maintenance-check.sh --infrastructure
./scripts/maintenance-check.sh --modules

# Run multiple specific checks
./scripts/maintenance-check.sh -i -s -f

# Get help
./scripts/maintenance-check.sh --help
```

### Command Line Options

- `-a, --all` - Run all checks (default)
- `-i, --infrastructure` - Infrastructure health check only
- `-s, --security` - Security scanning only
- `-m, --modules` - Module version consistency check only
- `-f, --format` - Terraform formatting check only
- `-g, --gitignore` - .gitignore completeness check only
- `-r, --repository` - Repository size monitoring only
- `-p, --performance` - Performance metrics collection only
- `-c, --cleanup` - Cleanup recommendations only
- `-h, --help` - Show help message

### Output

The script provides:

1. **Colored Console Output** - Real-time progress with color-coded results
2. **Progress Indicators** - Visual progress bars during execution
3. **Detailed Log File** - Complete execution log at `scripts/maintenance-check.log`
4. **Summary Report** - Timestamped report at `scripts/maintenance-report-YYYYMMDD-HHMMSS.txt`

### Output Interpretation

- ✓ **Green checkmarks** - Passed checks
- ⚠ **Yellow warnings** - Issues that should be addressed but aren't critical
- ✗ **Red errors** - Critical issues that need immediate attention
- ℹ **Blue info** - Informational messages
- 💡 **Purple recommendations** - Suggested improvements

### Health Score

The script calculates an overall health score based on:
- Failed checks (10 points deduction each)
- Warning checks (3 points deduction each)

Score interpretation:
- **90-100**: Excellent - Repository is well-maintained
- **75-89**: Good - Minor issues to address
- **50-74**: Fair - Several improvements needed
- **<50**: Needs Attention - Significant issues require immediate action

### Requirements

- Bash 4.0+ (for associative arrays)
- Standard Unix utilities (find, grep, du, wc, etc.)
- Terraform CLI (optional, for formatting checks)
- Git (optional, for repository-specific checks)

### Integration

This script can be integrated into:

1. **CI/CD Pipelines** - Run as part of your build process
2. **Git Hooks** - Execute before commits or pushes
3. **Scheduled Jobs** - Regular health monitoring via cron
4. **Development Workflow** - Manual execution during development

### Example Integration

#### GitHub Actions
```yaml
- name: Run Infrastructure Health Check
  run: |
    chmod +x ./scripts/maintenance-check.sh
    ./scripts/maintenance-check.sh --all
```

#### Pre-commit Hook
```bash
#!/bin/bash
./scripts/maintenance-check.sh -s -f
```

#### Cron Job
```bash
# Run daily at 2 AM
0 2 * * * cd /path/to/repo && ./scripts/maintenance-check.sh --all > /dev/null
```

### Customization

The script can be customized by modifying:

- **Secret patterns** in the `secret_patterns` array
- **Insecure configuration patterns** in the `insecure_patterns` array
- **Required .gitignore patterns** in the `required_patterns` array
- **Thresholds** for file sizes, complexity metrics, etc.

### Troubleshooting

1. **Permission Denied**: Ensure the script is executable with `chmod +x maintenance-check.sh`
2. **Command Not Found**: Verify all required utilities are installed
3. **Large Repository Timeout**: Run specific checks individually for large repositories
4. **False Positives**: Review and customize detection patterns as needed

### Contributing

To add new checks:

1. Create a new function following the naming pattern `check_*`
2. Add appropriate `print_*` calls for results
3. Include the function in the main execution flow
4. Add command-line option support
5. Update this documentation