# Infrastructure Orchestrator Testing Guide 🧪

Comprehensive testing procedures for the Infrastructure Manager (`infrastructure-manager.sh`) - your master orchestration tool.

## 🎯 Overview

This guide provides step-by-step testing procedures to validate all functionality of the Infrastructure Manager, ensuring reliable operation across all environments and use cases.

## 📋 Prerequisites

### Required Tools
- [x] Git (for repository operations)
- [x] Terraform (for infrastructure validation)
- [x] GitHub CLI (for API operations)
- [x] AWS CLI (for cloud operations)
- [x] jq (for JSON processing)
- [x] curl (for HTTP operations)

### Environment Setup
```bash
# 1. Set required environment variables
export GITHUB_TOKEN='your_github_token_here'

# 2. Verify script permissions
chmod +x ./scripts/infrastructure-manager.sh

# 3. Navigate to project root
cd /path/to/infrastructure/
```

### Verification Commands
```bash
# Verify all dependencies
./scripts/infrastructure-manager.sh --status

# Expected output: All tools should show ✓ (green checkmarks)
```

## 🔧 Core Functionality Testing

### 1. System Status and Health

#### Test 1.1: System Status Check
```bash
# Command
./scripts/infrastructure-manager.sh --status

# Expected Results
✓ System Status displays:
  - Infrastructure Manager version
  - Available scripts (all marked as ✓)
  - System dependencies (all installed)
  - Directory status (all created)

# Success Criteria
- No missing dependencies
- All scripts executable
- All directories present
```

#### Test 1.2: Quick Health Check
```bash
# Command
./scripts/infrastructure-manager.sh --health

# Expected Results
✓ Runs maintenance-check.sh with quick parameters
✓ Displays colored output with progress indicators
✓ Completes in under 2 minutes
✓ Shows final health score

# Success Criteria
- Health score > 75 (good condition)
- No critical errors reported
- Log file created in scripts/logs/
```

#### Test 1.3: System Diagnostic
```bash
# Command
./scripts/infrastructure-manager.sh --help

# Expected Results
✓ Displays comprehensive help information
✓ Shows all available commands
✓ Includes usage examples
✓ Shows integration examples

# Success Criteria
- All commands documented
- Examples are accurate
- Clear formatting
```

### 2. Security and Compliance Testing

#### Test 2.1: Comprehensive Security Scan
```bash
# Command
./scripts/infrastructure-manager.sh --compliance

# Expected Results
✓ Executes compliance-checker.sh
✓ Performs NIST, CIS, SOC2 validation
✓ Generates security report
✓ No critical security issues

# Success Criteria
- Compliance score > 80%
- All critical issues flagged
- Recommendations provided
- Report generated
```

#### Test 2.2: Quick Security Validation
```bash
# Command (via compliance script directly)
./scripts/compliance-checker.sh --quick

# Expected Results
✓ Fast security check (under 1 minute)
✓ Basic security validations pass
✓ Critical issues identified

# Success Criteria
- Completes quickly
- Identifies obvious issues
- Provides clear output
```

### 3. Reporting and Monitoring

#### Test 3.1: Comprehensive Health Report
```bash
# Command
./scripts/infrastructure-manager.sh --report

# Expected Results
✓ Executes health-reporter.sh
✓ Generates detailed health metrics
✓ Creates multiple report formats
✓ Shows trends and analysis

# Success Criteria
- Multiple output formats (MD, JSON, HTML)
- Comprehensive metrics included
- Executive summary generated
- Files created in reports/ directory
```

#### Test 3.2: Session Summary
```bash
# Run after several operations
./scripts/infrastructure-manager.sh --summary

# Expected Results
✓ Shows session information
✓ Lists all executed operations
✓ Displays success/failure rates
✓ Shows execution time

# Success Criteria
- Accurate operation tracking
- Correct timing information
- Clear success metrics
```

### 4. Dependency Management

#### Test 4.1: Dependency Updates
```bash
# Command
./scripts/infrastructure-manager.sh --dependencies

# Expected Results
✓ Executes dependency-updater.sh
✓ Checks Terraform module versions
✓ Identifies available updates
✓ Provides update recommendations

# Success Criteria
- Modules analyzed correctly
- Updates identified accurately
- Safe update recommendations
- Detailed logging
```

### 5. Bulk Operations Testing

#### Test 5.1: Terraform Formatting
```bash
# Command
./scripts/infrastructure-manager.sh --bulk-format

# Expected Results
✓ Executes bulk-operations.sh with terraform-format
✓ Processes all Terraform files
✓ Shows progress indicators
✓ Reports formatting changes

# Success Criteria
- All .tf files processed
- Formatting applied consistently
- Progress clearly shown
- Summary of changes
```

#### Test 5.2: Interactive Bulk Operations
```bash
# Command (choose option 5 from main menu)
./scripts/infrastructure-manager.sh
# Select: 5. Bulk Operations
# Choose specific bulk operation

# Expected Results
✓ Displays bulk operation submenu
✓ Allows selection of specific operations
✓ Executes chosen operation correctly
✓ Returns to main menu

# Success Criteria
- Clear menu options
- Correct operation execution
- Proper menu navigation
```

## 🔄 Workflow Testing

### 6. Complete Setup Workflow

#### Test 6.1: New Environment Setup
```bash
# Command
./scripts/infrastructure-manager.sh --setup

# Expected Results
✓ Runs multi-step setup process
✓ Verifies prerequisites
✓ Performs health checks
✓ Runs security validation
✓ Updates dependencies
✓ Provides final validation

# Success Criteria
- All steps complete successfully
- No critical errors
- Takes 5-10 minutes
- Final validation passes

# Detailed Step Verification
Step 1/5: System Prerequisites Check ✓
Step 2/5: Health Check ✓
Step 3/5: Security & Compliance ✓
Step 4/5: Dependency Updates ✓
Step 5/5: Final Validation ✓
```

### 7. Daily Maintenance Workflow

#### Test 7.1: Automated Daily Tasks
```bash
# Command
./scripts/infrastructure-manager.sh --daily

# Expected Results
✓ Runs daily maintenance checks
✓ Performs security review
✓ Generates daily summary
✓ Completes in 2-3 minutes

# Success Criteria
- Quick execution
- Essential checks only
- Daily report generated
- No blocking issues
```

### 8. Weekly Reporting Workflow

#### Test 8.1: Comprehensive Weekly Analysis
```bash
# Command
./scripts/infrastructure-manager.sh --weekly

# Expected Results
✓ Comprehensive health report
✓ Full compliance check
✓ Dependency update check
✓ Executive summary generated

# Success Criteria
- Complete analysis performed
- Multiple reports generated
- Executive summary created
- Takes 5-8 minutes
```

## 🎮 Interactive Menu Testing

### 9. Menu Navigation and Operations

#### Test 9.1: Interactive Menu Launch
```bash
# Command
./scripts/infrastructure-manager.sh

# Expected Results
✓ Beautiful menu interface displays
✓ All 13 options visible
✓ Clear descriptions provided
✓ Session information shown

# Menu Verification Checklist
- [ ] Option 1: Quick Health Check
- [ ] Option 2: Comprehensive Health Report
- [ ] Option 3: Security & Compliance Check
- [ ] Option 4: Update Dependencies
- [ ] Option 5: Bulk Operations
- [ ] Option 6: Maintenance Check
- [ ] Option 7: Complete Setup Workflow
- [ ] Option 8: Daily Maintenance Workflow
- [ ] Option 9: Weekly Report Workflow
- [ ] Option 10: View Recent Reports
- [ ] Option 11: Session Summary
- [ ] Option 12: System Status
- [ ] Option 13: Help & Examples
- [ ] Option 0: Exit
```

#### Test 9.2: Individual Menu Options
Test each menu option individually:

```bash
# Test each option by selecting it from the interactive menu
./scripts/infrastructure-manager.sh

# Option 1: Quick Health Check
# Expected: Runs health check and returns to menu

# Option 2: Comprehensive Health Report
# Expected: Generates detailed report and returns to menu

# Continue testing each option...
```

### 10. Report Viewing and Management

#### Test 10.1: Recent Reports Viewer
```bash
# Generate some reports first
./scripts/infrastructure-manager.sh --report
./scripts/infrastructure-manager.sh --weekly

# Then test viewer
./scripts/infrastructure-manager.sh
# Select option 10: View Recent Reports

# Expected Results
✓ Lists recent report files
✓ Shows file dates and times
✓ Allows selection and viewing
✓ Opens files in appropriate viewer
```

## 🚨 Error Handling and Edge Cases

### 11. Error Scenarios Testing

#### Test 11.1: Missing Dependencies
```bash
# Temporarily rename a required tool
sudo mv /usr/local/bin/terraform /usr/local/bin/terraform.bak

# Run system check
./scripts/infrastructure-manager.sh --status

# Expected Results
✓ Detects missing dependency
✓ Shows clear error message
✓ Provides installation guidance
✓ Gracefully handles missing tool

# Restore tool
sudo mv /usr/local/bin/terraform.bak /usr/local/bin/terraform
```

#### Test 11.2: Invalid Command Line Arguments
```bash
# Test invalid arguments
./scripts/infrastructure-manager.sh --invalid-option

# Expected Results
✓ Shows clear error message
✓ Suggests using --help
✓ Exits with non-zero code
✓ No system damage
```

#### Test 11.3: Permission Issues
```bash
# Remove execute permission temporarily
chmod -x ./scripts/infrastructure-manager.sh

# Try to run
./scripts/infrastructure-manager.sh

# Expected Results
✓ Shell reports permission denied
✓ Clear error message

# Restore permissions
chmod +x ./scripts/infrastructure-manager.sh
```

### 12. Resource Constraints Testing

#### Test 12.1: Large Repository Handling
```bash
# Test with large number of files
# Command
./scripts/infrastructure-manager.sh --bulk-format

# Expected Results
✓ Handles large file counts gracefully
✓ Shows progress for long operations
✓ Doesn't overwhelm system resources
✓ Completes successfully
```

#### Test 12.2: Memory and Performance
```bash
# Monitor resource usage during operation
# In one terminal:
top -p $(pgrep -f infrastructure-manager)

# In another terminal:
./scripts/infrastructure-manager.sh --weekly

# Expected Results
✓ Reasonable memory usage (< 1GB)
✓ Reasonable CPU usage (< 80%)
✓ No memory leaks
✓ Completes in expected time
```

## 🔗 Integration Testing

### 13. CI/CD Integration

#### Test 13.1: GitHub Actions Simulation
```bash
# Simulate CI/CD environment
export CI=true
export GITHUB_ACTIONS=true

# Run health check
./scripts/infrastructure-manager.sh --health

# Expected Results
✓ Runs in non-interactive mode
✓ Provides appropriate exit codes
✓ Generates machine-readable output
✓ Logs appropriately for CI
```

#### Test 13.2: Automated Workflow Testing
```bash
# Test automated workflow
./scripts/infrastructure-manager.sh --daily --quiet

# Expected Results
✓ Runs without interaction
✓ Minimal output for automation
✓ Appropriate exit codes
✓ Logs captured properly
```

### 14. Multi-Environment Testing

#### Test 14.1: Different Working Directories
```bash
# Test from different directories
cd /tmp
/path/to/infrastructure/scripts/infrastructure-manager.sh --status

# Expected Results
✓ Detects correct project root
✓ Finds all required files
✓ Functions normally
✓ No path issues
```

## 📊 Performance Testing

### 15. Performance Benchmarks

#### Test 15.1: Operation Timing
```bash
# Time different operations
time ./scripts/infrastructure-manager.sh --health
time ./scripts/infrastructure-manager.sh --compliance
time ./scripts/infrastructure-manager.sh --report

# Expected Performance
- Health check: < 2 minutes
- Compliance check: < 5 minutes
- Full report: < 8 minutes
- Setup workflow: < 10 minutes
```

#### Test 15.2: Parallel Operation Handling
```bash
# Test concurrent executions (should be prevented)
./scripts/infrastructure-manager.sh --report &
./scripts/infrastructure-manager.sh --health

# Expected Results
✓ Second instance detects first
✓ Appropriate handling of concurrency
✓ No resource conflicts
✓ Clear messaging about running instance
```

## 🧹 Cleanup and Maintenance Testing

### 16. Log and Report Management

#### Test 16.1: Log File Creation and Management
```bash
# Generate multiple operations
./scripts/infrastructure-manager.sh --health
./scripts/infrastructure-manager.sh --compliance
./scripts/infrastructure-manager.sh --summary

# Check log files
ls -la ./scripts/logs/

# Expected Results
✓ Log files created for each session
✓ Proper naming convention
✓ Reasonable file sizes
✓ Proper permissions
```

#### Test 16.2: Report Directory Management
```bash
# Generate reports
./scripts/infrastructure-manager.sh --report
./scripts/infrastructure-manager.sh --weekly

# Check reports
ls -la ./reports/

# Expected Results
✓ Reports created in correct location
✓ Multiple formats available
✓ Proper naming and timestamps
✓ Reasonable file sizes
```

## ✅ Test Validation Checklist

### Core Functionality
- [ ] System status check works correctly
- [ ] Health checks execute and report properly
- [ ] Security scans complete with appropriate results
- [ ] Dependency updates function correctly
- [ ] Bulk operations process files appropriately

### Interactive Interface
- [ ] Main menu displays correctly
- [ ] All menu options function
- [ ] Navigation works properly
- [ ] Help system is accessible
- [ ] Exit functions cleanly

### Workflow Testing
- [ ] Setup workflow completes successfully
- [ ] Daily maintenance runs quickly
- [ ] Weekly reports generate properly
- [ ] All workflows track progress

### Error Handling
- [ ] Missing dependencies detected
- [ ] Invalid arguments handled gracefully
- [ ] Permission issues reported clearly
- [ ] Resource constraints managed

### Integration
- [ ] CI/CD simulation works
- [ ] Different directories supported
- [ ] Environment variables respected
- [ ] Exit codes appropriate

### Performance
- [ ] Operations complete within expected time
- [ ] Resource usage reasonable
- [ ] Concurrent execution handled
- [ ] Large repositories supported

## 🚀 Quick Test Suite

For rapid validation, run this condensed test sequence:

```bash
#!/bin/bash
# Quick Infrastructure Manager Test Suite

echo "🧪 Quick Infrastructure Manager Test Suite"
echo "=========================================="

# Test 1: System Status
echo "1. Testing system status..."
./scripts/infrastructure-manager.sh --status
echo "✅ System status test completed"

# Test 2: Quick Health Check
echo "2. Testing health check..."
./scripts/infrastructure-manager.sh --health
echo "✅ Health check test completed"

# Test 3: Help System
echo "3. Testing help system..."
./scripts/infrastructure-manager.sh --help > /dev/null
echo "✅ Help system test completed"

# Test 4: Interactive Menu (automated)
echo "4. Testing menu launch..."
timeout 5s ./scripts/infrastructure-manager.sh < /dev/null
echo "✅ Menu launch test completed"

# Test 5: Session Summary
echo "5. Testing session summary..."
./scripts/infrastructure-manager.sh --summary
echo "✅ Session summary test completed"

echo ""
echo "🎉 Quick test suite completed!"
echo "For comprehensive testing, follow the full guide above."
```

## 🐛 Troubleshooting Test Issues

### Common Test Problems

#### Issue: Tests Fail Due to Missing Tools
**Solution:**
```bash
# Install missing tools
# macOS:
brew install terraform git gh jq

# Ubuntu/Debian:
sudo apt-get install terraform git gh jq

# Verify installation
./scripts/infrastructure-manager.sh --status
```

#### Issue: Permission Denied Errors
**Solution:**
```bash
# Fix script permissions
find ./scripts -name "*.sh" -exec chmod +x {} \;

# Verify permissions
ls -la ./scripts/*.sh
```

#### Issue: GitHub Token Issues
**Solution:**
```bash
# Verify token is set
echo $GITHUB_TOKEN

# Test token validity
gh auth status

# Set token if needed
export GITHUB_TOKEN='your_token_here'
```

#### Issue: Long Test Execution Times
**Solution:**
```bash
# Use quick mode for testing
export QUICK_MODE=true
export SKIP_PERFORMANCE_METRICS=true

# Run specific tests only
./scripts/infrastructure-manager.sh --health
```

## 📝 Test Documentation and Reporting

### Test Results Template
```markdown
# Infrastructure Manager Test Results

**Test Date:** $(date)
**Tester:** [Your Name]
**Environment:** [Description]

## Test Summary
- Total Tests: X
- Passed: X
- Failed: X
- Skipped: X

## Failed Tests
[List any failed tests with details]

## Performance Metrics
- Health Check: X seconds
- Compliance Check: X seconds
- Full Report: X seconds

## Recommendations
[Any recommendations for improvements]
```

## 🎯 Best Practices for Testing

1. **Regular Testing**: Run tests after each update to the infrastructure manager
2. **Environment Isolation**: Test in clean environments when possible
3. **Documentation**: Document any custom tests for your environment
4. **Automation**: Consider automating frequent test scenarios
5. **Performance Monitoring**: Track performance trends over time

---

**🎉 Comprehensive Testing Complete!**

*This testing guide ensures the Infrastructure Manager operates reliably across all scenarios and environments. Regular testing maintains confidence in your infrastructure automation.*