# Infrastructure Manager 🚀

The ultimate infrastructure management tool that coordinates all infrastructure operations through a single, powerful interface.

## Overview

Infrastructure Manager is a comprehensive orchestration script that provides:

- **Single Entry Point** - One command to rule them all
- **Interactive Menu System** - Beautiful, user-friendly interface
- **CLI Automation Support** - Perfect for CI/CD pipelines
- **Intelligent Workflow Coordination** - Automated multi-step processes
- **Dependency Management** - Smart prerequisite handling
- **Session Tracking** - Complete operation history and metrics
- **Multi-format Reporting** - Executive summaries and detailed reports

## Features

### 🎯 Core Operations
- **Quick Health Check** - Fast infrastructure validation
- **Comprehensive Health Report** - Detailed analysis with visualizations
- **Security & Compliance** - Full security audit and compliance checking
- **Dependency Updates** - Intelligent module and provider updates
- **Bulk Operations** - Parallel execution of operations across modules
- **Maintenance Check** - Complete infrastructure maintenance

### 🔄 Workflow Automation
- **Complete Setup Workflow** - End-to-end infrastructure setup
- **Daily Maintenance Workflow** - Automated daily health checks
- **Weekly Report Workflow** - Comprehensive weekly reports

### 🛠 Utilities
- **Recent Reports Viewer** - Easy access to generated reports
- **Session Summary** - Real-time operation tracking
- **System Status** - Infrastructure manager health check
- **Help & Examples** - Comprehensive documentation

## Quick Start

### Interactive Mode (Recommended)
```bash
./scripts/infrastructure-manager.sh
```

This launches the beautiful interactive menu system with all options clearly displayed.

### CLI Automation Mode
```bash
# Quick health check
./scripts/infrastructure-manager.sh --health

# Comprehensive report
./scripts/infrastructure-manager.sh --report

# Security compliance check
./scripts/infrastructure-manager.sh --compliance

# Update dependencies
./scripts/infrastructure-manager.sh --dependencies

# Complete setup workflow
./scripts/infrastructure-manager.sh --setup

# Daily maintenance
./scripts/infrastructure-manager.sh --daily

# Weekly reports
./scripts/infrastructure-manager.sh --weekly
```

## Command Reference

### Core Operations
| Command | Description | Use Case |
|---------|-------------|----------|
| `--health` | Quick health check | CI/CD validation |
| `--report` | Comprehensive health report | Weekly reviews |
| `--compliance` | Security & compliance check | Audit requirements |
| `--dependencies` | Update dependencies | Maintenance windows |
| `--maintenance` | Full maintenance check | Monthly deep-dive |
| `--bulk-format` | Bulk Terraform formatting | Code cleanup |

### Workflows
| Command | Description | Duration | Frequency |
|---------|-------------|----------|-----------|
| `--setup` | Complete setup workflow | 5-10 min | New environments |
| `--daily` | Daily maintenance workflow | 2-3 min | Daily automation |
| `--weekly` | Weekly report workflow | 5-8 min | Weekly reports |

### Utilities
| Command | Description | Output |
|---------|-------------|--------|
| `--status` | System status check | Console |
| `--reports` | View recent reports | Interactive |
| `--summary` | Session summary | Console |
| `--version` | Version information | Console |
| `--help` | Complete help | Console |

## Integration Examples

### GitHub Actions
```yaml
name: Infrastructure Health Check
on:
  schedule:
    - cron: '0 8 * * *'  # Daily at 8 AM
  push:
    branches: [main]

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Health Check
        run: |
          chmod +x ./scripts/infrastructure-manager.sh
          ./scripts/infrastructure-manager.sh --health
      - name: Upload Reports
        uses: actions/upload-artifact@v3
        with:
          name: health-reports
          path: reports/
```

### Jenkins Pipeline
```groovy
pipeline {
    agent any
    triggers {
        cron('0 2 * * *') // Daily at 2 AM
    }
    stages {
        stage('Infrastructure Health') {
            steps {
                sh './scripts/infrastructure-manager.sh --daily'
            }
        }
        stage('Archive Reports') {
            steps {
                archiveArtifacts artifacts: 'reports/**/*', fingerprint: true
            }
        }
    }
}
```

### Cron Jobs
```bash
# Daily health check at 2 AM
0 2 * * * cd /path/to/project && ./scripts/infrastructure-manager.sh --daily >/dev/null 2>&1

# Weekly comprehensive report on Sundays at 8 AM
0 8 * * 0 cd /path/to/project && ./scripts/infrastructure-manager.sh --weekly >/dev/null 2>&1

# Quick health check every 4 hours during business hours
0 8,12,16 * * 1-5 cd /path/to/project && ./scripts/infrastructure-manager.sh --health >/dev/null 2>&1
```

### Docker Integration
```dockerfile
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache bash terraform git curl jq

# Copy scripts
COPY scripts/ /app/scripts/
WORKDIR /app

# Make executable
RUN chmod +x /app/scripts/infrastructure-manager.sh

# Set entrypoint
ENTRYPOINT ["/app/scripts/infrastructure-manager.sh"]
```

Usage:
```bash
# Build image
docker build -t infrastructure-manager .

# Run health check
docker run --rm -v $(pwd):/app infrastructure-manager --health

# Interactive mode
docker run --rm -it -v $(pwd):/app infrastructure-manager
```

## Advanced Usage

### Workflow Customization

The Infrastructure Manager supports custom workflows through environment variables:

```bash
# Skip certain checks
export SKIP_SECURITY_CHECK=true
export SKIP_DEPENDENCY_UPDATE=true
./scripts/infrastructure-manager.sh --setup

# Custom report formats
export REPORT_FORMAT=html
export INCLUDE_TRENDS=true
./scripts/infrastructure-manager.sh --report

# Notification settings
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export NOTIFY_ON_FAILURE=true
./scripts/infrastructure-manager.sh --daily
```

### Parallel Execution

For large infrastructures, enable parallel execution:

```bash
# Set maximum parallel jobs
export MAX_PARALLEL_JOBS=16
./scripts/infrastructure-manager.sh --bulk-format

# Enable parallel workflows
export ENABLE_PARALLEL_WORKFLOWS=true
./scripts/infrastructure-manager.sh --setup
```

### Output Customization

Control output verbosity and formatting:

```bash
# Quiet mode (minimal output)
./scripts/infrastructure-manager.sh --health --quiet

# Verbose mode (detailed logging)
./scripts/infrastructure-manager.sh --compliance --verbose

# JSON output for automation
./scripts/infrastructure-manager.sh --status --json
```

## Monitoring and Alerting

### Built-in Monitoring

Infrastructure Manager tracks:
- Operation success/failure rates
- Execution duration and performance
- Resource usage and system health
- Security compliance status
- Dependency update status

### Alert Integration

Configure alerts for various scenarios:

```bash
# Slack notifications
export SLACK_WEBHOOK_URL="your-webhook-url"
export ALERT_ON_FAILURE=true
export ALERT_ON_SUCCESS=false

# Email notifications (requires sendmail/smtp setup)
export EMAIL_RECIPIENTS="admin@company.com,team@company.com"
export SMTP_SERVER="smtp.company.com"

# PagerDuty integration
export PAGERDUTY_INTEGRATION_KEY="your-key"
export ALERT_CRITICAL_FAILURES=true
```

## File Structure

```
scripts/
├── infrastructure-manager.sh          # Main orchestration script
├── maintenance-check.sh               # Infrastructure maintenance
├── health-reporter.sh                 # Health reporting system
├── compliance-checker.sh              # Security & compliance
├── dependency-updater.sh              # Dependency management
├── bulk-operations.sh                 # Bulk operations
├── logs/                             # Session logs
│   └── infrastructure-manager-*.log
└── temp/                             # Temporary files
    └── session-data/

reports/                              # Generated reports
├── health-report-*.md               # Health reports
├── executive-summary-*.md           # Executive summaries
├── daily-summary-*.md              # Daily summaries
└── compliance-report-*.json        # Compliance reports
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   chmod +x ./scripts/infrastructure-manager.sh
   ```

2. **Missing Dependencies**
   ```bash
   # Check system status
   ./scripts/infrastructure-manager.sh --status
   
   # Install missing tools
   # On macOS:
   brew install terraform git jq
   # On Ubuntu/Debian:
   apt-get install terraform git jq
   ```

3. **Script Not Found**
   ```bash
   # Verify script location
   ls -la ./scripts/infrastructure-manager.sh
   
   # Check from project root
   cd /path/to/your/infrastructure/project
   ./scripts/infrastructure-manager.sh --status
   ```

4. **Long Execution Times**
   ```bash
   # Use parallel execution
   export MAX_PARALLEL_JOBS=8
   ./scripts/infrastructure-manager.sh --bulk-format
   
   # Run specific operations only
   ./scripts/infrastructure-manager.sh --health  # Faster than --report
   ```

### Debug Mode

Enable debug mode for detailed troubleshooting:

```bash
# Enable debug logging
export DEBUG=true
export VERBOSE=true
./scripts/infrastructure-manager.sh --health

# Check session log
tail -f ./scripts/logs/infrastructure-manager-*.log
```

### Performance Optimization

For large infrastructures:

1. **Increase Parallel Jobs**
   ```bash
   export MAX_PARALLEL_JOBS=16
   ```

2. **Skip Non-Essential Checks**
   ```bash
   export SKIP_PERFORMANCE_METRICS=true
   export QUICK_MODE=true
   ```

3. **Use Targeted Operations**
   ```bash
   # Instead of full maintenance
   ./scripts/infrastructure-manager.sh --health
   
   # Instead of comprehensive report
   ./scripts/infrastructure-manager.sh --report --format=summary
   ```

## Best Practices

### Daily Operations

1. **Morning Health Check**
   ```bash
   ./scripts/infrastructure-manager.sh --health
   ```

2. **End-of-Day Summary**
   ```bash
   ./scripts/infrastructure-manager.sh --summary
   ```

### Weekly Operations

1. **Comprehensive Review**
   ```bash
   ./scripts/infrastructure-manager.sh --weekly
   ```

2. **Dependency Updates**
   ```bash
   ./scripts/infrastructure-manager.sh --dependencies
   ```

### Monthly Operations

1. **Full Maintenance**
   ```bash
   ./scripts/infrastructure-manager.sh --maintenance
   ```

2. **Security Audit**
   ```bash
   ./scripts/infrastructure-manager.sh --compliance
   ```

### Emergency Response

1. **Quick Triage**
   ```bash
   ./scripts/infrastructure-manager.sh --health --quiet
   ./scripts/infrastructure-manager.sh --status
   ```

2. **Detailed Investigation**
   ```bash
   ./scripts/infrastructure-manager.sh --report
   ./scripts/infrastructure-manager.sh --compliance
   ```

## Contributing

To extend Infrastructure Manager:

1. **Add New Operations**
   - Create function: `operation_new_feature()`
   - Add menu option in `show_main_menu()`
   - Add CLI argument in `handle_cli_args()`

2. **Add New Workflows**
   - Create function: `workflow_custom_name()`
   - Define workflow steps
   - Add tracking and reporting

3. **Add Integrations**
   - Extend notification functions
   - Add new report formats
   - Integrate external tools

## Support

- **Documentation**: This README and built-in help (`--help`)
- **Logs**: Check session logs in `./scripts/logs/`
- **Status**: Use `--status` for system diagnostics
- **Interactive Help**: Use the interactive menu option 13

## Version History

- **v1.0.0** - Initial release with full orchestration capabilities
  - Interactive menu system
  - CLI automation support
  - Workflow automation
  - Session tracking and reporting
  - Integration examples

---

**Infrastructure Manager** - Making infrastructure management a joy! 🚀

*Created with ❤️ for infrastructure teams who value automation and reliability.*