#!/bin/bash

set -e
set -o pipefail

# Constants
ORG="https://dev.azure.com/msazure"
PROJECT="CloudNativeCompute"
ROOT_SANDBOX="$HOME/aiplayground"
ADO_PR_FETCHER_DIR="$ROOT_SANDBOX/ado-pr-fetcher"
BARE_REPOS_DIR="$ADO_PR_FETCHER_DIR/bare-repos"
PR_DATA_DIR="$ADO_PR_FETCHER_DIR/pr-data"

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# Show usage
usage() {
    echo "Usage: $0 <command> <repo> <pr-id>"
    echo ""
    echo "Commands:"
    echo "  fetch <repo> <pr-id>     Fetch PR data and create worktree"
    echo "  cleanup <repo> <pr-id>   Clean up PR worktree and data"
    echo ""
    echo "Examples:"
    echo "  $0 fetch aks-rp 13386625"
    echo "  $0 cleanup aks-rp 13386625"
    exit 1
}

# Check Azure authentication
check_azure_auth() {
    log_info "Checking Azure authentication..."
    if ! az account show >/dev/null 2>&1; then
        log_error "Not authenticated with Azure. Run 'az login' first."
        exit 1
    fi
    
    # Configure devops defaults
    log_info "Configuring Azure DevOps defaults..."
    az devops configure --defaults organization="$ORG" project="$PROJECT" >/dev/null 2>&1
    
    log_info "Azure authentication verified"
}

# Setup directory structure
setup_directories() {
    log_info "Setting up directory structure..."
    mkdir -p "$BARE_REPOS_DIR"
    mkdir -p "$PR_DATA_DIR"
}

# Main function dispatch
main() {
    if [ $# -lt 3 ]; then
        usage
    fi
    
    local command="$1"
    local repo="$2"
    local pr_id="$3"
    
    case "$command" in
        fetch)
            fetch_pr "$repo" "$pr_id"
            ;;
        cleanup)
            cleanup_pr "$repo" "$pr_id"
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            ;;
    esac
}

# Fetch PR metadata and save to file
fetch_pr_metadata() {
    local repo="$1"
    local pr_id="$2"
    local pr_data_path="$3"
    
    # Get PR details using Azure CLI
    local pr_json
    if ! pr_json=$(az repos pr show --id "$pr_id" 2>/dev/null); then
        log_error "Failed to fetch PR $pr_id from repository $repo"
        exit 1
    fi
    
    # Extract relevant information
    local source_branch title description author created_date
    source_branch=$(echo "$pr_json" | jq -r '.sourceRefName // "unknown"' | sed 's|refs/heads/||')
    title=$(echo "$pr_json" | jq -r '.title // "No title"')
    description=$(echo "$pr_json" | jq -r '.description // "No description"')
    author=$(echo "$pr_json" | jq -r '.createdBy.displayName // "Unknown"')
    created_date=$(echo "$pr_json" | jq -r '.creationDate // "Unknown"')
    
    # Create metadata.md file
    local metadata_file="$pr_data_path/metadata.md"
    cat > "$metadata_file" << EOF
# PR $pr_id Metadata

**Repository:** $repo  
**PR ID:** $pr_id  
**Source Branch:** $source_branch  
**Author:** $author  
**Created:** $created_date  

## Title
$title

## Description
$description
EOF
    
    # Log success and return branch name (to stderr to avoid contamination)
    log_info "PR metadata saved to $metadata_file" >&2
    echo "$source_branch"
}

# Setup or update bare repository
setup_bare_repo() {
    local repo="$1"
    local bare_repo_path="$BARE_REPOS_DIR/$repo"
    
    if [ ! -d "$bare_repo_path" ]; then
        log_info "Cloning bare repository $repo..."
        local repo_url="$ORG/$PROJECT/_git/$repo"
        if ! git clone --bare "$repo_url" "$bare_repo_path" >/dev/null 2>&1; then
            log_error "Failed to clone repository $repo"
            exit 1
        fi
    else
        log_info "Updating existing bare repository..."
        cd "$bare_repo_path"
        git fetch origin >/dev/null 2>&1
    fi
    
    # Ensure we have the latest master branch from remote
    cd "$bare_repo_path"
    log_info "Fetching latest master branch..."
    git fetch origin >/dev/null 2>&1
    log_info "Updating master to match remote master exactly..."
    git update-ref refs/heads/master refs/remotes/origin/master >/dev/null 2>&1
    
    log_info "Bare repository ready at $bare_repo_path"
}

# Create worktree and generate diff
create_pr_worktree() {
    local repo="$1"
    local pr_id="$2"
    local source_branch="$3"
    local pr_data_path="$4"
    
    local bare_repo_path="$BARE_REPOS_DIR/$repo"
    local worktree_path="$pr_data_path/worktree"
    
    # Remove existing worktree if it exists
    if [ -d "$worktree_path" ]; then
        log_info "Removing existing worktree..."
        cd "$bare_repo_path"
        git worktree remove --force "$worktree_path" >/dev/null 2>&1 || true
        rm -rf "$worktree_path"
    fi
    
    log_info "Creating worktree for branch $source_branch..."
    cd "$bare_repo_path"
    
    # The branch should already be available as origin/$source_branch
    log_info "Verifying branch exists..."
    if ! git rev-parse "origin/$source_branch" >/dev/null 2>&1; then
        log_error "Branch origin/$source_branch not found"
        exit 1
    fi
    
    # Create worktree
    if ! git worktree add "$worktree_path" "origin/$source_branch" >/dev/null 2>&1; then
        log_error "Failed to create worktree"
        exit 1
    fi
    
    log_info "Merging master branch into worktree..."
    cd "$worktree_path"
    
    # Merge master to simulate the final state
    if ! git merge origin/master --no-edit >/dev/null 2>&1; then
        log_warn "Merge conflicts detected, continuing with current state"
    fi
    
    log_info "Generating diff patch..."
    local diff_file="$pr_data_path/diff.patch"
    git diff origin/master > "$diff_file"
    
    log_info "Diff patch saved to $diff_file"
    log_info "Worktree created at $worktree_path"
}

# Main fetch function
fetch_pr() {
    local repo="$1"
    local pr_id="$2"
    
    log_info "Fetching PR $pr_id from repo $repo..."
    
    # Check prerequisites
    check_azure_auth
    setup_directories
    
    # Create PR data directory
    local pr_data_path="$PR_DATA_DIR/$repo-$pr_id"
    mkdir -p "$pr_data_path"
    
    # Fetch PR metadata and get source branch
    log_info "Fetching PR metadata..."
    local source_branch
    source_branch=$(fetch_pr_metadata "$repo" "$pr_id" "$pr_data_path")
    
    if [ -z "$source_branch" ]; then
        log_error "Failed to get source branch for PR $pr_id"
        exit 1
    fi
    
    # Setup bare repository
    setup_bare_repo "$repo"
    
    # Create worktree and generate diff
    create_pr_worktree "$repo" "$pr_id" "$source_branch" "$pr_data_path"
    
    log_info "PR $pr_id fetch completed successfully!"
    log_info "PR data available at: $pr_data_path"
}

cleanup_pr() {
    local repo="$1"
    local pr_id="$2"
    
    log_info "Cleaning up PR $pr_id from repo $repo..."
    
    local pr_data_path="$PR_DATA_DIR/$repo-$pr_id"
    local bare_repo_path="$BARE_REPOS_DIR/$repo"
    local worktree_path="$pr_data_path/worktree"
    
    # Check if PR data directory exists
    if [ ! -d "$pr_data_path" ]; then
        log_warn "PR data directory does not exist: $pr_data_path"
        return 0
    fi
    
    # Remove worktree if it exists
    if [ -d "$worktree_path" ] && [ -d "$bare_repo_path" ]; then
        log_info "Removing worktree..."
        cd "$bare_repo_path"
        if git worktree remove --force "$worktree_path" >/dev/null 2>&1; then
            log_info "Worktree removed successfully"
        else
            log_warn "Failed to remove worktree via git command, removing directory directly"
            rm -rf "$worktree_path"
        fi
    fi
    
    # Remove PR data directory
    log_info "Removing PR data directory..."
    if rm -rf "$pr_data_path"; then
        log_info "PR data directory removed successfully"
    else
        log_error "Failed to remove PR data directory: $pr_data_path"
        exit 1
    fi
    
    log_info "Cleanup completed for PR $pr_id"
}


# Run main function
main "$@"