# Infrastructure Health Reporter

A comprehensive health reporting system for infrastructure projects that generates beautiful, actionable reports with visualizations, notifications, and multi-format output.

## Features

### 🔍 Comprehensive Health Assessment
- **Infrastructure Health**: Terraform validation, state management, configuration checks
- **Security Analysis**: Secret scanning, file permissions, insecure configurations
- **Performance Metrics**: Repository size, resource complexity, optimization recommendations
- **Compliance Checks**: Best practices, documentation, version constraints

### 📊 Multi-Format Reports
- **Markdown Report**: Detailed technical report with ASCII charts
- **HTML Report**: Interactive dashboard with Chart.js visualizations
- **JSON Report**: Machine-readable data for integrations
- **CSV Report**: Data export for spreadsheet analysis
- **Executive Summary**: High-level overview for management

### 🔔 Notifications & Integrations
- **Slack Notifications**: Automated alerts with health status
- **Email Reports**: Detailed summaries via email
- **Trend Tracking**: Historical health data with JSON storage
- **Custom Thresholds**: Configurable warning and critical levels

### 📈 Advanced Features
- **Progress Tracking**: Real-time progress bars during assessment
- **Health Scoring**: Weighted scoring system (0-100 scale)
- **Risk Assessment**: Business impact analysis with effort estimates
- **Actionable Recommendations**: Prioritized improvement suggestions

## Quick Start

### Basic Usage
```bash
# Run complete health assessment
./scripts/health-reporter.sh

# Run without notifications
./scripts/health-reporter.sh --no-slack --no-email

# Custom thresholds
./scripts/health-reporter.sh --critical-threshold 50 --warning-threshold 75
```

### Environment Setup
```bash
# Optional: Set Slack webhook for notifications
export SLACK_WEBHOOK_URL="https://hooks.slack.com/your-webhook"

# Optional: Set email recipients
export EMAIL_RECIPIENTS="admin@company.com,devops@company.com"
```

## Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--no-slack` | Disable Slack notifications | Enabled |
| `--no-email` | Disable email notifications | Disabled |
| `--no-charts` | Disable chart generation | Enabled |
| `--no-trends` | Disable trend tracking | Enabled |
| `--slack-webhook URL` | Set Slack webhook URL | `$SLACK_WEBHOOK_URL` |
| `--email-recipients LIST` | Set email recipients | `$EMAIL_RECIPIENTS` |
| `--critical-threshold N` | Critical health threshold | 60 |
| `--warning-threshold N` | Warning health threshold | 80 |
| `--output-dir DIR` | Custom output directory | `../reports` |
| `--quiet` | Suppress progress output | Verbose |
| `--help` | Show help message | - |

## Report Examples

### Health Scores
The system generates weighted health scores across four key areas:

```
Infrastructure       [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0/100
Security             [█████████████████████████████████████████████░░░░░] 90/100  
Performance          [███████████████████████████████████████████████░░░] 95/100
Compliance           [██████████████████████████████████████████░░░░░░░░] 84/100
```

### Executive Dashboard
| Metric | Score | Status | Priority |
|--------|-------|--------|----------|
| Infrastructure | 0/100 | ⚠️ Needs Attention | HIGH |
| Security | 90/100 | ✅ Secure | MEDIUM |
| Performance | 95/100 | ✅ Optimal | LOW |
| Compliance | 84/100 | ✅ Compliant | MEDIUM |

## Health Scoring System

### Scoring Methodology
- **Infrastructure (30%)**: Terraform validation, state management, configuration
- **Security (30%)**: Vulnerability scanning, secret detection, permissions
- **Performance (20%)**: Repository size, complexity, resource optimization
- **Compliance (20%)**: Best practices, documentation, standards adherence

### Health Status Levels
- **90-100**: 🟢 Excellent - Optimal performance
- **80-89**: 🟡 Good - Minor improvements needed
- **60-79**: 🟠 Fair - Attention required
- **0-59**: 🔴 Critical - Immediate action needed

## Integration Guide

### Slack Integration
```bash
# Set webhook URL
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Run with Slack notifications
./scripts/health-reporter.sh
```

### Email Integration
```bash
# Configure email recipients
export EMAIL_RECIPIENTS="admin@company.com,team@company.com"

# Enable email notifications
./scripts/health-reporter.sh --email-recipients "$EMAIL_RECIPIENTS"
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Infrastructure Health Check
  run: |
    ./scripts/health-reporter.sh --no-email
    if [ $? -eq 2 ]; then
      echo "Critical health issues detected!"
      exit 1
    fi
```

## Output Files

### Report Locations
All reports are generated in the `reports/` directory with timestamps:

- `health-report-YYYYMMDD-HHMMSS.md` - Markdown report
- `health-report-YYYYMMDD-HHMMSS.json` - JSON data
- `health-report-YYYYMMDD-HHMMSS.csv` - CSV export
- `health-report-YYYYMMDD-HHMMSS.html` - HTML dashboard
- `executive-summary-YYYYMMDD-HHMMSS.md` - Executive summary
- `health-trends.json` - Historical trend data

### Log Files
Detailed logs are stored in `scripts/logs/`:
- `health-reporter-YYYYMMDD-HHMMSS.log` - Execution log

## Customization

### Custom Thresholds
```bash
# More strict thresholds
./scripts/health-reporter.sh --critical-threshold 70 --warning-threshold 85

# More lenient thresholds
./scripts/health-reporter.sh --critical-threshold 40 --warning-threshold 60
```

### Output Directory
```bash
# Custom output location
./scripts/health-reporter.sh --output-dir /custom/reports
```

## Troubleshooting

### Common Issues

**Terraform validation errors**
- Ensure Terraform is installed and accessible
- Check that `.tf` files are valid syntax
- Verify provider configurations

**Permission errors**
- Check file permissions on sensitive files
- Ensure script has read access to all directories
- Verify output directory write permissions

**Missing dependencies**
- Install required tools: `terraform`, `jq` (optional)
- Ensure shell environment supports bash 3.2+

### Debug Mode
```bash
# Enable verbose logging
./scripts/health-reporter.sh --debug

# Check log files for detailed information
tail -f scripts/logs/health-reporter-*.log
```

## Return Codes

The script returns different exit codes based on health status:
- `0`: Healthy infrastructure (score >= 80)
- `1`: Warning - needs attention (score 60-79)
- `2`: Critical - immediate action required (score < 60)

## Integration with Other Scripts

The health reporter integrates with other infrastructure scripts:
- `maintenance-check.sh` - Infrastructure validation
- `dependency-updater.sh` - Dependency analysis
- `bulk-operations.sh` - Operational metrics

## Advanced Configuration

### Custom Slack Messages
The Slack integration supports rich formatting with color-coded alerts:
- 🟢 Green: Healthy status
- 🟡 Yellow: Warning status
- 🔴 Red: Critical status

### Trend Analysis
Historical data is automatically tracked in JSON format:
```json
{
  "timestamp": "2025-07-15T16:48:51Z",
  "overall_score": 62,
  "infrastructure_score": 0,
  "security_score": 90,
  "performance_score": 95,
  "compliance_score": 84
}
```

## Best Practices

### Regular Monitoring
- Run daily in CI/CD pipelines
- Set up automated Slack alerts
- Review trends weekly
- Address critical issues immediately

### Team Integration
- Share executive summaries with management
- Use technical reports for engineering teams
- Track improvements over time
- Set health score targets

### Continuous Improvement
- Monitor trends for degradation
- Implement recommended fixes
- Update thresholds as standards evolve
- Regular script updates and maintenance

## Support

For issues, improvements, or questions:
1. Check the generated log files for detailed error information
2. Review the troubleshooting section above
3. Contact your DevOps team for infrastructure-specific issues

## Version History

- **v1.0** - Initial release with comprehensive health reporting
  - Multi-format report generation
  - Slack and email notifications
  - Trend tracking and analysis
  - HTML dashboard with visualizations