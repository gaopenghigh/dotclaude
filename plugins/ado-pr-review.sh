#!/bin/bash

# Enhanced Azure DevOps PR Review Script
# Usage: /ado-pr-review <pr-number-or-url>
# Supports both PR numbers and full URLs
#
# Configuration:
# Set environment variables or create ~/.ado-pr-review.conf with:
#   ADO_ORG_URL=https://dev.azure.com/your-org
#   ADO_PROJECT=your-project
#   ADO_REPO=your-repo
#
# Example URLs supported:
#   - PR Number: 12345
#   - Full URL: https://dev.azure.com/your-org/your-project/_git/your-repo/pullrequest/12345

set -euo pipefail

# Configuration - Load from environment variables or config file
CONFIG_FILE="$HOME/.ado-pr-review.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Default configuration (override with environment variables)
ORG_URL="${ADO_ORG_URL:-https://dev.azure.com/your-organization}"
PROJECT="${ADO_PROJECT:-your-project}"
REPO="${ADO_REPO:-your-repository}"
TEMP_DIR="/tmp/ado-pr-review-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to extract PR number from URL or use direct number
extract_pr_number() {
    local input=$1
    if [[ $input =~ pullrequest/([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ $input =~ ^[0-9]+$ ]]; then
        echo "$input"
    else
        print_color "$RED" "Error: Invalid PR number or URL format"
        echo "Supported formats:"
        echo "  - PR Number: 12345"
        echo "  - Full URL: ${ORG_URL}/${PROJECT}/_git/${REPO}/pullrequest/12345"
        exit 1
    fi
}

# Function to check configuration
check_configuration() {
    print_color "$BLUE" "Checking configuration..."
    
    if [[ "$ORG_URL" == "https://dev.azure.com/your-organization" ]] || \
       [[ "$PROJECT" == "your-project" ]] || \
       [[ "$REPO" == "your-repository" ]]; then
        print_color "$RED" "Error: Configuration not set up"
        echo ""
        echo "Please configure your Azure DevOps settings by either:"
        echo "1. Setting environment variables:"
        echo "   export ADO_ORG_URL=https://dev.azure.com/your-org"
        echo "   export ADO_PROJECT=your-project"
        echo "   export ADO_REPO=your-repo"
        echo ""
        echo "2. Creating ~/.ado-pr-review.conf with:"
        echo "   ADO_ORG_URL=https://dev.azure.com/your-org"
        echo "   ADO_PROJECT=your-project" 
        echo "   ADO_REPO=your-repo"
        exit 1
    fi
    
    print_color "$GREEN" "✓ Configuration check passed"
    print_color "$BLUE" "Using: $ORG_URL/$PROJECT/$REPO"
}

# Function to check prerequisites
check_prerequisites() {
    print_color "$BLUE" "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_color "$RED" "Error: Azure CLI (az) is not installed or not in PATH"
        echo "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if user is logged in
    if ! az account show &> /dev/null; then
        print_color "$RED" "Error: Not logged in to Azure CLI"
        echo "Please run: az login"
        exit 1
    fi
    
    # Check for required tools
    for tool in jq git; do
        if ! command -v "$tool" &> /dev/null; then
            print_color "$RED" "Error: $tool is not installed"
            exit 1
        fi
    done
    
    print_color "$GREEN" "✓ Prerequisites check passed"
}

# Function to get PR details
get_pr_details() {
    local pr_number=$1
    print_color "$BLUE" "Fetching PR details for PR #$pr_number..."
    
    local pr_details
    pr_details=$(az repos pr show \
        --id "$pr_number" \
        --organization "$ORG_URL" \
        --project "$PROJECT" \
        --output json 2>/dev/null) || {
        print_color "$RED" "Error: Failed to fetch PR details"
        echo "Please check:"
        echo "  - PR number exists: $pr_number"
        echo "  - You have access to the repository"
        echo "  - Azure CLI is properly configured"
        exit 1
    }
    
    echo "$pr_details"
}

# Function to get changed files
get_changed_files() {
    local pr_number=$1
    print_color "$BLUE" "Fetching changed files..."
    
    az repos pr list-files \
        --id "$pr_number" \
        --organization "$ORG_URL" \
        --project "$PROJECT" \
        --output json 2>/dev/null || {
        print_color "$YELLOW" "Warning: Could not fetch changed files list"
        echo "[]"
    }
}

# Function to parse and display PR information
display_pr_info() {
    local pr_details=$1
    local changed_files=$2
    
    # Parse PR information
    local title author status source_branch target_branch description web_url created_date
    title=$(echo "$pr_details" | jq -r '.title // "N/A"')
    author=$(echo "$pr_details" | jq -r '.createdBy.displayName // "N/A"')
    status=$(echo "$pr_details" | jq -r '.status // "N/A"')
    source_branch=$(echo "$pr_details" | jq -r '.sourceRefName // "N/A"' | sed 's/refs\/heads\///')
    target_branch=$(echo "$pr_details" | jq -r '.targetRefName // "N/A"' | sed 's/refs\/heads\///')
    description=$(echo "$pr_details" | jq -r '.description // "No description"')
    web_url=$(echo "$pr_details" | jq -r '._links.web.href // "N/A"')
    created_date=$(echo "$pr_details" | jq -r '.creationDate // "N/A"')
    
    # Display formatted information
    print_color "$PURPLE" "=== PR REVIEW SUMMARY ==="
    echo "Title: $title"
    echo "Author: $author" 
    echo "Status: $status"
    echo "Created: $created_date"
    echo "Source Branch: $source_branch"
    echo "Target Branch: $target_branch"
    echo "Web URL: $web_url"
    print_color "$PURPLE" "=========================="
    
    echo ""
    print_color "$YELLOW" "Description:"
    echo "$description"
    echo ""
    
    # Display changed files with categorization
    if [[ "$changed_files" != "[]" ]] && [[ -n "$changed_files" ]]; then
        print_color "$BLUE" "=== CHANGED FILES ==="
        
        local go_files proto_files yaml_files other_files
        go_files=$(echo "$changed_files" | jq -r '.[] | select(.path | test("\\.go$")) | "- \(.path) (\(.changeType))"' | wc -l)
        proto_files=$(echo "$changed_files" | jq -r '.[] | select(.path | test("\\.proto$")) | "- \(.path) (\(.changeType))"' | wc -l)
        yaml_files=$(echo "$changed_files" | jq -r '.[] | select(.path | test("\\.(yaml|yml)$")) | "- \(.path) (\(.changeType))"' | wc -l)
        other_files=$(echo "$changed_files" | jq -r '.[] | select(.path | test("\\.go$|\\.proto$|\\.(yaml|yml)$") | not) | "- \(.path) (\(.changeType))"' | wc -l)
        
        echo "File Statistics:"
        echo "  Go files: $go_files"
        echo "  Proto files: $proto_files" 
        echo "  YAML files: $yaml_files"
        echo "  Other files: $other_files"
        echo ""
        
        print_color "$GREEN" "Go Files:"
        echo "$changed_files" | jq -r '.[] | select(.path | test("\\.go$")) | "- \(.path) (\(.changeType))"' || echo "None"
        
        print_color "$GREEN" "Proto Files:"
        echo "$changed_files" | jq -r '.[] | select(.path | test("\\.proto$")) | "- \(.path) (\(.changeType))"' || echo "None"
        
        print_color "$GREEN" "YAML Files:"
        echo "$changed_files" | jq -r '.[] | select(.path | test("\\.(yaml|yml)$")) | "- \(.path) (\(.changeType))"' || echo "None"
        
        if [[ $other_files -gt 0 ]]; then
            print_color "$GREEN" "Other Files:"
            echo "$changed_files" | jq -r '.[] | select(.path | test("\\.go$|\\.proto$|\\.(yaml|yml)$") | not) | "- \(.path) (\(.changeType))"'
        fi
        
        print_color "$BLUE" "====================="
    else
        print_color "$YELLOW" "Could not fetch changed files list"
    fi
}

# Main execution
main() {
    local input=${1:-}
    
    if [[ -z "$input" ]]; then
        print_color "$RED" "Usage: /ado-pr-review <pr-number-or-url>"
        echo ""
        echo "Examples:"
        echo "  /ado-pr-review 12345"
        echo "  /ado-pr-review ${ORG_URL}/${PROJECT}/_git/${REPO}/pullrequest/12345"
        echo ""
        echo "Configuration required - see script header for setup instructions."
        exit 1
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Check configuration
    check_configuration
    
    # Check prerequisites
    check_prerequisites
    
    # Extract PR number
    local pr_number
    pr_number=$(extract_pr_number "$input")
    
    print_color "$GREEN" "Analyzing Azure DevOps PR #$pr_number"
    echo "Organization: $ORG_URL"
    echo "Project: $PROJECT"
    echo "Repository: $REPO"
    echo ""
    
    # Get PR details and changed files
    local pr_details changed_files
    pr_details=$(get_pr_details "$pr_number")
    changed_files=$(get_changed_files "$pr_number")
    
    # Display information
    display_pr_info "$pr_details" "$changed_files"
    
    echo ""
    print_color "$GREEN" "✓ PR information retrieved successfully!"
    print_color "$BLUE" "Ready for Claude to perform detailed code review."
    
    # Save data for potential Claude analysis
    echo "$pr_details" > "$TEMP_DIR/pr_details.json"
    echo "$changed_files" > "$TEMP_DIR/changed_files.json"
    
    local web_url
    web_url=$(echo "$pr_details" | jq -r '._links.web.href // "N/A"')
    echo ""
    print_color "$PURPLE" "View PR online: $web_url"
}

# Execute main function
main "$@"