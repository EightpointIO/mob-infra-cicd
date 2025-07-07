#!/bin/bash

# Slack Notification Helper Functions for Infrastructure CI/CD
# Used by mob-infrastructure-cicd workflows

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[SLACK-INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SLACK-SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SLACK-WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[SLACK-ERROR]${NC} $1"
}

# Team member Slack ID mappings
# Add your team members' GitHub usernames to Slack IDs mapping here
get_slack_member_id() {
    local github_username=${1}
    
    # Team member mappings (replace with actual mappings)
    case "$github_username" in
        "ios-devops")
            echo "U01234567"  # Replace with actual Slack user ID
            ;;
        "liviu")
            echo "U09876543"  # Replace with actual Slack user ID
            ;;
        # Add more team member mappings here
        *)
            echo ""  # Return empty if no mapping found
            ;;
    esac
}

# Get team-specific Slack channel
get_team_slack_channel() {
    local team_name=${1}
    local notification_type=${2:-"general"}  # general, pr, deployment, alert
    
    case "$team_name" in
        "ios")
            case "$notification_type" in
                "pr") echo "#ios-infrastructure-pr" ;;
                "deployment") echo "#ios-infrastructure-deploy" ;;
                "alert") echo "#ios-infrastructure-alerts" ;;
                *) echo "#ios-infrastructure" ;;
            esac
            ;;
        "android")
            case "$notification_type" in
                "pr") echo "#android-infrastructure-pr" ;;
                "deployment") echo "#android-infrastructure-deploy" ;;
                "alert") echo "#android-infrastructure-alerts" ;;
                *) echo "#android-infrastructure" ;;
            esac
            ;;
        *)
            echo "#infrastructure"  # Default channel
            ;;
    esac
}

# Send basic Slack notification
send_slack_notification() {
    local webhook_url=${1}
    local message=${2}
    local username=${3:-"InfraBot"}
    local icon=${4:-":construction:"}
    local channel=${5:-""}
    
    if [[ -z "$webhook_url" ]]; then
        log_warning "Slack webhook URL not provided, skipping notification"
        return 0
    fi
    
    if [[ -z "$message" ]]; then
        log_error "Message is required for Slack notification"
        return 1
    fi
    
    local payload="{\"text\": \"$message\", \"username\": \"$username\", \"icon_emoji\": \"$icon\""
    
    if [[ -n "$channel" ]]; then
        payload="$payload, \"channel\": \"$channel\""
    fi
    
    payload="$payload}"
    
    if curl -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" &>/dev/null; then
        log_success "Slack notification sent successfully"
        return 0
    else
        log_error "Failed to send Slack notification"
        return 1
    fi
}

# Send rich Slack notification with attachments
send_slack_rich_notification() {
    local webhook_url=${1}
    local title=${2}
    local message=${3}
    local color=${4:-"good"}  # good, warning, danger, or hex color
    local username=${5:-"InfraBot"}
    local icon=${6:-":construction:"}
    local channel=${7:-""}
    
    if [[ -z "$webhook_url" ]]; then
        log_warning "Slack webhook URL not provided, skipping notification"
        return 0
    fi
    
    local timestamp=$(date +%s)
    
    local payload="{
        \"username\": \"$username\",
        \"icon_emoji\": \"$icon\",
        \"attachments\": [
            {
                \"color\": \"$color\",
                \"title\": \"$title\",
                \"text\": \"$message\",
                \"footer\": \"Eightpoint Infrastructure Pipeline\",
                \"ts\": $timestamp
            }
        ]"
    
    if [[ -n "$channel" ]]; then
        payload="$payload, \"channel\": \"$channel\""
    fi
    
    payload="$payload}"
    
    if curl -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" &>/dev/null; then
        log_success "Rich Slack notification sent successfully"
        return 0
    else
        log_error "Failed to send rich Slack notification"
        return 1
    fi
}

# Send PR notification
send_pr_notification() {
    local webhook_url=${1}
    local pr_title=${2}
    local pr_url=${3}
    local pr_author=${4}
    local project_name=${5}
    local team_name=${6}
    local environment=${7}
    
    local slack_user_id=$(get_slack_member_id "$pr_author")
    local channel=$(get_team_slack_channel "$team_name" "pr")
    
    local mention=""
    if [[ -n "$slack_user_id" ]]; then
        mention="<@$slack_user_id>"
    else
        mention="$pr_author"
    fi
    
    local message="🏗️ <!here> $mention opened Infrastructure PR for *$project_name* ($team_name/$environment): *<$pr_url|$pr_title>*"
    
    send_slack_notification "$webhook_url" "$message" "InfraBot" ":construction:" "$channel"
}

# Send deployment success notification
send_deployment_success_notification() {
    local webhook_url=${1}
    local project_name=${2}
    local team_name=${3}
    local environment=${4}
    local commit_message=${5}
    local author=${6}
    local version=${7:-""}
    
    local channel=$(get_team_slack_channel "$team_name" "deployment")
    local env_emoji=""
    local env_color=""
    
    case "$environment" in
        "dev"|"development")
            env_emoji="🚧"
            env_color="good"
            ;;
        "prod"|"production")
            env_emoji="🚀"
            env_color="#ff6b6b"
            ;;
        *)
            env_emoji="🏗️"
            env_color="good"
            ;;
    esac
    
    local title="$env_emoji $(echo "$environment" | tr '[:lower:]' '[:upper:]') $project_name Infrastructure Deployed"
    
    local fields="[
        {\"title\": \"Team\", \"value\": \"$team_name\", \"short\": true},
        {\"title\": \"Environment\", \"value\": \"$environment\", \"short\": true}"
    
    if [[ -n "$version" ]]; then
        fields="$fields, {\"title\": \"Version\", \"value\": \"$version\", \"short\": true}"
    fi
    
    fields="$fields]"
    
    local timestamp=$(date +%s)
    
    local payload="{
        \"username\": \"InfraBot\",
        \"icon_emoji\": \":rocket:\",
        \"channel\": \"$channel\",
        \"attachments\": [
            {
                \"color\": \"$env_color\",
                \"title\": \"$title\",
                \"fields\": $fields,
                \"text\": \"Commit: $commit_message\",
                \"footer\": \"Eightpoint Infrastructure Pipeline | Author: $author\",
                \"ts\": $timestamp
            }
        ]
    }"
    
    if curl -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" &>/dev/null; then
        log_success "Deployment success notification sent"
        return 0
    else
        log_error "Failed to send deployment success notification"
        return 1
    fi
}

# Send deployment failure notification
send_deployment_failure_notification() {
    local webhook_url=${1}
    local project_name=${2}
    local team_name=${3}
    local environment=${4}
    local error_message=${5}
    local author=${6}
    local workflow_url=${7:-""}
    
    local channel=$(get_team_slack_channel "$team_name" "alert")
    local slack_user_id=$(get_slack_member_id "$author")
    
    local mention=""
    if [[ -n "$slack_user_id" ]]; then
        mention="<@$slack_user_id>"
    else
        mention="$author"
    fi
    
    local title="❌ FAILED: $project_name Infrastructure Deployment ($team_name/$environment)"
    
    local fields="[
        {\"title\": \"Team\", \"value\": \"$team_name\", \"short\": true},
        {\"title\": \"Environment\", \"value\": \"$environment\", \"short\": true},
        {\"title\": \"Author\", \"value\": \"$mention\", \"short\": true}"
    
    if [[ -n "$workflow_url" ]]; then
        fields="$fields, {\"title\": \"Workflow\", \"value\": \"<$workflow_url|View Logs>\", \"short\": true}"
    fi
    
    fields="$fields]"
    
    local timestamp=$(date +%s)
    
    local payload="{
        \"username\": \"InfraBot\",
        \"icon_emoji\": \":warning:\",
        \"channel\": \"$channel\",
        \"attachments\": [
            {
                \"color\": \"danger\",
                \"title\": \"$title\",
                \"fields\": $fields,
                \"text\": \"Error: $error_message\",
                \"footer\": \"Eightpoint Infrastructure Pipeline\",
                \"ts\": $timestamp
            }
        ]
    }"
    
    if curl -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" &>/dev/null; then
        log_success "Deployment failure notification sent"
        return 0
    else
        log_error "Failed to send deployment failure notification"
        return 1
    fi
}

# Send drift detection notification
send_drift_notification() {
    local webhook_url=${1}
    local project_name=${2}
    local team_name=${3}
    local environment=${4}
    local drift_summary=${5}
    local workflow_url=${6:-""}
    
    local channel=$(get_team_slack_channel "$team_name" "alert")
    
    local title="⚠️ Infrastructure Drift Detected: $project_name ($team_name/$environment)"
    
    local fields="[
        {\"title\": \"Team\", \"value\": \"$team_name\", \"short\": true},
        {\"title\": \"Environment\", \"value\": \"$environment\", \"short\": true}"
    
    if [[ -n "$workflow_url" ]]; then
        fields="$fields, {\"title\": \"Details\", \"value\": \"<$workflow_url|View Drift Report>\", \"short\": true}"
    fi
    
    fields="$fields]"
    
    local timestamp=$(date +%s)
    
    local payload="{
        \"username\": \"InfraBot\",
        \"icon_emoji\": \":warning:\",
        \"channel\": \"$channel\",
        \"attachments\": [
            {
                \"color\": \"warning\",
                \"title\": \"$title\",
                \"fields\": $fields,
                \"text\": \"Drift Summary: $drift_summary\\n\\nPlease review and apply necessary changes to align infrastructure with configuration.\",
                \"footer\": \"Eightpoint Infrastructure Pipeline\",
                \"ts\": $timestamp
            }
        ]
    }"
    
    if curl -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" &>/dev/null; then
        log_success "Drift notification sent"
        return 0
    else
        log_error "Failed to send drift notification"
        return 1
    fi
}

# Send security alert notification
send_security_alert_notification() {
    local webhook_url=${1}
    local project_name=${2}
    local team_name=${3}
    local security_issues=${4}
    local pr_url=${5:-""}
    
    local channel=$(get_team_slack_channel "$team_name" "alert")
    
    local title="🔒 Security Issues Detected: $project_name ($team_name)"
    
    local fields="[
        {\"title\": \"Team\", \"value\": \"$team_name\", \"short\": true},
        {\"title\": \"Severity\", \"value\": \"High\", \"short\": true}"
    
    if [[ -n "$pr_url" ]]; then
        fields="$fields, {\"title\": \"Pull Request\", \"value\": \"<$pr_url|View PR>\", \"short\": true}"
    fi
    
    fields="$fields]"
    
    local timestamp=$(date +%s)
    
    local payload="{
        \"username\": \"SecurityBot\",
        \"icon_emoji\": \":lock:\",
        \"channel\": \"$channel\",
        \"attachments\": [
            {
                \"color\": \"danger\",
                \"title\": \"$title\",
                \"fields\": $fields,
                \"text\": \"Security Issues Found:\\n$security_issues\\n\\nPlease address these issues before proceeding with deployment.\",
                \"footer\": \"Eightpoint Security Scanner\",
                \"ts\": $timestamp
            }
        ]
    }"
    
    if curl -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" &>/dev/null; then
        log_success "Security alert notification sent"
        return 0
    else
        log_error "Failed to send security alert notification"
        return 1
    fi
}

# Test Slack webhook connectivity
test_slack_webhook() {
    local webhook_url=${1}
    local channel=${2:-""}
    
    if [[ -z "$webhook_url" ]]; then
        log_error "Webhook URL is required for testing"
        return 1
    fi
    
    log_info "Testing Slack webhook connectivity"
    
    local test_message="🧪 Test message from mob-infrastructure-cicd pipeline"
    
    if send_slack_notification "$webhook_url" "$test_message" "TestBot" ":test_tube:" "$channel"; then
        log_success "Slack webhook test successful"
        return 0
    else
        log_error "Slack webhook test failed"
        return 1
    fi
}

# Main execution check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_error "This script should be sourced, not executed directly"
    log_info "Usage: source slack-notifications.sh"
    exit 1
fi

log_info "Slack notification helper functions loaded successfully"