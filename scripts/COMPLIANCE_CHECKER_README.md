# Infrastructure Compliance Checker

A comprehensive security and compliance validation tool for infrastructure projects that supports multiple compliance frameworks and generates detailed remediation guidance.

## Overview

The Infrastructure Compliance Checker performs automated security and compliance assessments against industry-standard frameworks including:

- **NIST Cybersecurity Framework** - Identity, Protect, Detect controls
- **CIS Controls** - Critical security controls for cyber defense
- **SOC 2 Type II** - Trust service criteria (Security, Availability, Processing Integrity, Confidentiality, Privacy)
- **Terraform Best Practices** - Infrastructure as Code security and quality standards
- **Git Security** - Version control security and secrets management
- **AWS Best Practices** - Cloud-specific security controls and Well-Architected principles

## Features

### 🔒 Security Compliance
- **Multi-framework support** - NIST, CIS, SOC2 standards
- **Infrastructure scanning** - Terraform, AWS, Git repositories
- **Policy violation detection** - Hardcoded secrets, overly permissive policies
- **Continuous monitoring** - Track compliance trends over time

### 📊 Comprehensive Reporting
- **Multiple report formats** - Markdown, JSON, CSV
- **Executive summaries** - High-level compliance status for management
- **Detailed remediation guidance** - Specific actions to address findings
- **Trend analysis** - Historical compliance tracking

### 🚀 Integration Ready
- **CI/CD pipeline integration** - Automated compliance checks
- **Exit codes** - Fail builds on compliance violations
- **Configurable thresholds** - Customize risk tolerance
- **External tool integration** - Checkov, TFSec, Terrascan support

## Installation

1. **Download the script:**
   ```bash
   wget https://raw.githubusercontent.com/your-repo/compliance-checker.sh
   chmod +x compliance-checker.sh
   ```

2. **Verify dependencies:**
   The script automatically checks for optional tools:
   - `git` - For Git security checks
   - `terraform` - For Terraform validation
   - `checkov` - For infrastructure security scanning
   - `tfsec` - For Terraform security analysis
   - `jq` - For JSON processing

3. **Configuration (optional):**
   Copy and customize the configuration file:
   ```bash
   cp compliance-checker.config.example compliance-checker.config
   # Edit configuration as needed
   ```

## Usage

### Basic Usage

```bash
# Run all compliance checks
./compliance-checker.sh

# Run with verbose output
./compliance-checker.sh --verbose

# Run with debug information
./compliance-checker.sh --debug

# Specify custom project root
./compliance-checker.sh --project-root /path/to/project

# Show help
./compliance-checker.sh --help
```

### Advanced Usage

```bash
# Run specific compliance framework checks only
NIST_ONLY=true ./compliance-checker.sh

# Generate reports in specific directory
REPORTS_DIR=/custom/reports ./compliance-checker.sh

# Enable detailed debugging
DEBUG=true ./compliance-checker.sh

# Custom configuration file
CONFIG_FILE=/path/to/custom.config ./compliance-checker.sh
```

## Configuration

The compliance checker can be customized using the `compliance-checker.config` file:

### Framework Configuration
```ini
[frameworks]
nist_enabled=true
cis_enabled=true
soc2_enabled=true
terraform_enabled=true
git_enabled=true
aws_enabled=true
```

### Risk Thresholds
```ini
[severity]
high_risk_threshold=5      # Failed checks for HIGH risk
medium_risk_threshold=2    # Failed checks for MEDIUM risk
```

### Report Configuration
```ini
[reports]
markdown_report=true
json_report=true
csv_report=true
executive_summary=true
trends_tracking=true
```

## Compliance Frameworks

### NIST Cybersecurity Framework

The tool checks for implementation of key NIST controls:

- **ID.AM-1** - Infrastructure inventory documentation
- **ID.AM-2** - Software asset inventory
- **PR.AC-1** - Identity and access management
- **PR.DS-1** - Data-at-rest protection
- **PR.DS-2** - Data-in-transit protection
- **DE.CM-1** - Network monitoring and detection

### CIS Controls

Critical security controls validation:

- **Control 1** - Hardware asset inventory
- **Control 2** - Software asset inventory
- **Control 3** - Continuous vulnerability management
- **Control 4** - Controlled use of administrative privileges
- **Control 6** - Maintenance and analysis of audit logs

### SOC 2 Type II

Trust service criteria assessment:

- **Security** - Access controls implementation
- **Availability** - Monitoring and alerting
- **Processing Integrity** - Data validation mechanisms
- **Confidentiality** - Encryption implementation
- **Privacy** - Data classification and handling

### Terraform Best Practices

Infrastructure as Code quality checks:

- **State Management** - Remote backend configuration
- **Input Validation** - Variable validation rules
- **Resource Tagging** - Consistent tagging strategy
- **Version Constraints** - Provider version pinning
- **Security Scanning** - Integration with security tools
- **Modular Structure** - Code organization and reusability

### Git Security

Version control security validation:

- **Pre-commit Hooks** - Automated security checks
- **Gitignore Configuration** - Sensitive file exclusion
- **Secrets Scanning** - Detection of committed secrets
- **Branch Protection** - CI/CD workflow integration
- **Commit Signing** - Authenticity verification

### AWS Best Practices

Cloud security controls assessment:

- **CloudTrail** - Comprehensive API logging
- **VPC Security** - Network security configuration
- **S3 Security** - Encryption and access controls
- **IAM Practices** - Least privilege implementation
- **Monitoring** - CloudWatch alarms and notifications

## Report Formats

### Markdown Report
Human-readable compliance report with:
- Executive summary
- Framework-specific results
- Detailed remediation guidance
- Risk assessment and recommendations

### JSON Report
Machine-readable format for:
- API integration
- Automated processing
- Dashboard integration
- Historical data analysis

### CSV Report
Spreadsheet-compatible format for:
- Data analysis
- Compliance tracking
- Management reporting
- Trend visualization

### Executive Summary
High-level overview including:
- Key compliance metrics
- Risk assessment
- Immediate action items
- Strategic recommendations

## Integration

### CI/CD Pipeline Integration

#### GitHub Actions
```yaml
name: Compliance Check
on: [push, pull_request]
jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Compliance Check
        run: |
          chmod +x scripts/compliance-checker.sh
          scripts/compliance-checker.sh
      - name: Upload Reports
        uses: actions/upload-artifact@v2
        with:
          name: compliance-reports
          path: reports/
```

#### GitLab CI
```yaml
compliance_check:
  stage: test
  script:
    - chmod +x scripts/compliance-checker.sh
    - scripts/compliance-checker.sh
  artifacts:
    paths:
      - reports/
    expire_in: 1 week
  only:
    - branches
```

#### Jenkins Pipeline
```groovy
pipeline {
    agent any
    stages {
        stage('Compliance Check') {
            steps {
                sh 'chmod +x scripts/compliance-checker.sh'
                sh 'scripts/compliance-checker.sh'
                archiveArtifacts artifacts: 'reports/*', fingerprint: true
            }
        }
    }
}
```

### Exit Codes

The script uses the following exit codes for CI/CD integration:

- **0** - Success (all checks passed or only warnings)
- **1** - Failure (critical compliance issues found)

### Slack Integration

Configure Slack notifications in the config file:
```ini
[notifications]
slack_webhook_url=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   chmod +x compliance-checker.sh
   ```

2. **Command Not Found**
   Install required dependencies:
   ```bash
   # For macOS
   brew install jq git terraform
   
   # For Ubuntu/Debian
   apt-get install jq git terraform
   ```

3. **No Terraform Files Found**
   Ensure you're running the script from the correct directory or use `--project-root`

4. **JSON Parse Errors**
   Install `jq` for JSON processing:
   ```bash
   # macOS
   brew install jq
   
   # Linux
   apt-get install jq
   ```

### Debug Mode

Enable debug mode for detailed logging:
```bash
DEBUG=true ./compliance-checker.sh
```

### Log Files

Logs are stored in `scripts/logs/compliance-checker-TIMESTAMP.log`

## Best Practices

### Regular Compliance Checks
- Run compliance checks on every pull request
- Schedule weekly automated compliance scans
- Review and address warnings promptly
- Track compliance trends over time

### Team Integration
- Include compliance reports in sprint reviews
- Assign remediation tasks based on priority
- Provide team training on identified issues
- Document compliance exceptions and approvals

### Continuous Improvement
- Regularly update compliance rules
- Customize checks for your specific environment
- Monitor industry best practices
- Integrate with security toolchain

## Contributing

### Adding New Checks

1. **Create check function:**
   ```bash
   check_new_compliance() {
       log_info "Checking new compliance requirement..."
       
       if [[ condition ]]; then
           record_check_result "CATEGORY" "CHECK_ID" "PASS" "Description" "Remediation"
       else
           record_check_result "CATEGORY" "CHECK_ID" "FAIL" "Description" "Remediation"
       fi
   }
   ```

2. **Add to main execution:**
   ```bash
   main() {
       # ... existing checks ...
       check_new_compliance
       # ... rest of main ...
   }
   ```

### Custom Rules

Add custom rules in the configuration file:
```ini
[custom_checks]
custom_secret_patterns=custom_secret.*=,private_key.*=
custom_policy_violations=admin.*allow.*all
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the project repository
- Check the troubleshooting section
- Review the configuration documentation
- Enable debug mode for detailed logging

## Changelog

### Version 1.0.0
- Initial release with NIST, CIS, SOC2 support
- Terraform, Git, and AWS best practices
- Multiple report formats
- CI/CD integration support
- Trend tracking and historical analysis

---

*Generated by Infrastructure Compliance Checker - Ensuring security and compliance across your infrastructure*