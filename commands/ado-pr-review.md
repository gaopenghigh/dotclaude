---
allowed-tools: Bash(*), Glob(*), Grep(*), Read(*), LS(*), TodoWrite(*)
argument-hint: <PR-URL-or-ID>
description: Comprehensive Azure DevOps pull request review and analysis
---

# Azure DevOps Pull Request Review

Perform a comprehensive review of an Azure DevOps pull request with detailed code analysis, security checks, and best practices validation.

## Instructions

You are an expert code reviewer analyzing Azure DevOps pull requests for the AKS Resource Provider codebase. Follow these steps systematically:

### 1. Setup and Validation
- **Repository Check**: Ensure you're in the correct repository directory
- **PR Parsing**: Extract PR number/ID from URL if provided (handle both formats: full URL or just number)
- **Configuration Check**: First check for `~/.ado-pr-review.conf` file, then fallback to environment variables. If neither found, notify user and provide example configuration.
- **Git Fetch**: ALWAYS run `git fetch --all` first to ensure latest commits are available
- **Authentication Check**: Verify Azure CLI is logged in (`az account show`) before attempting PR operations
- **Safety First**: Use git worktree to avoid modifying the current branch
- **Prerequisites**: Verify Azure CLI is configured and accessible

### 2. PR Information Gathering
Fetch comprehensive PR details including:
- Title, author, description, status (active/completed/abandoned)
- Source and target branches
- Creation date, reviewers, and voting status
- Merge status and any merge conflicts
- Related work items and linked issues

Use: `az repos pr show --id <PR-ID>` (ensure you've run `az devops configure` with org/project defaults first)

### 3. Fetching PR Changes - Enhanced REST API Approach

**Primary Strategy - Azure DevOps REST API (Most Reliable):**
```bash
# Get PR file changes using REST API
PR_ID=<PR-ID>
ACCESS_TOKEN=$(az account get-access-token --query accessToken -o tsv)

# Get list of changed files
wget -q -O /tmp/pr-${PR_ID}-changes.json \
  "https://dev.azure.com/msazure/CloudNativeCompute/_apis/git/repositories/aks-rp/pullrequests/${PR_ID}/iterations/1/changes?api-version=7.0" \
  --header="Authorization: Bearer ${ACCESS_TOKEN}"

# If commit IDs are available from PR metadata, get detailed diff
BASE_COMMIT=$(az repos pr show --id ${PR_ID} --query "lastMergeTargetCommit.commitId" -o tsv)
TARGET_COMMIT=$(az repos pr show --id ${PR_ID} --query "lastMergeSourceCommit.commitId" -o tsv)

if [[ "$BASE_COMMIT" != "null" && "$TARGET_COMMIT" != "null" ]]; then
  wget -q -O /tmp/pr-${PR_ID}-diff.json \
    "https://dev.azure.com/msazure/CloudNativeCompute/_apis/git/repositories/aks-rp/diffs/commits?baseVersionType=commit&baseVersion=${BASE_COMMIT}&targetVersionType=commit&targetVersion=${TARGET_COMMIT}&api-version=7.0" \
    --header="Authorization: Bearer ${ACCESS_TOKEN}"
fi
```

**Secondary Strategy - Git Operations (If API fails):**

Use directory `~/aiplayground` for all git worktree operations to avoid modifying current workspace.

```bash
# Fetch latest to ensure we have all refs
git fetch --all

# Try to find the PR branch or merge commit
PR_BRANCH=$(az repos pr show --id <PR-ID> --query "sourceRefName" -o tsv | sed 's|refs/heads/||')

if git show-ref --verify --quiet refs/remotes/origin/${PR_BRANCH}; then
  # Branch exists, use it for diff
  git diff origin/master...origin/${PR_BRANCH} --name-only
  git diff origin/master...origin/${PR_BRANCH}
else
  # Try to find merge commit by PR ID
  MERGE_COMMIT=$(git log --grep="<PR-ID>" --oneline master | head -1 | cut -d' ' -f1)
  if [[ -n "$MERGE_COMMIT" ]]; then
    git show --name-only ${MERGE_COMMIT}
    git show ${MERGE_COMMIT}
  fi
fi
```

**Fallback Strategy - Temporary Clone (Last Resort):**
```bash
# Only if other methods fail and we need actual file contents
cd ~/aiplayground
if [[ ! -d "pr-<ID>-review" ]]; then
  timeout 300 git clone https://dev.azure.com/msazure/CloudNativeCompute/_git/aks-rp pr-<ID>-review --branch <pr-branch> --single-branch
fi

# Always cleanup afterwards
trap "rm -rf ~/aiplayground/pr-<ID>-review" EXIT
```

### 4. Processing API Responses

**Parse PR Changes from REST API:**
```bash
# Extract changed files list from API response
if [[ -f "/tmp/pr-${PR_ID}-changes.json" ]]; then
  # Parse changed files
  python3 -c "
import json, sys
with open('/tmp/pr-${PR_ID}-changes.json') as f:
    data = json.load(f)
    for entry in data.get('changeEntries', []):
        path = entry['item']['path']
        change_type = entry['changeType']
        print(f'{change_type}: {path}')
" || {
    # Fallback: use jq if python3 not available
    jq -r '.changeEntries[]? | "\(.changeType): \(.item.path)"' /tmp/pr-${PR_ID}-changes.json
  }
fi

# For each critical file, try to get individual file content from specific commits
for file_path in $(jq -r '.changeEntries[]? | select(.changeType=="edit") | .item.path' /tmp/pr-${PR_ID}-changes.json 2>/dev/null || echo ""); do
  if [[ "$file_path" =~ \.(go|proto|yaml|yml)$ ]]; then
    echo "Analyzing: $file_path"
    # Get file content from both commits for comparison if needed
    BASE_OBJ=$(jq -r ".changeEntries[] | select(.item.path==\"$file_path\") | .item.originalObjectId" /tmp/pr-${PR_ID}-changes.json)
    TARGET_OBJ=$(jq -r ".changeEntries[] | select(.item.path==\"$file_path\") | .item.objectId" /tmp/pr-${PR_ID}-changes.json)
    
    if [[ "$BASE_OBJ" != "null" && "$TARGET_OBJ" != "null" ]]; then
      # Can get specific file versions via API if needed for detailed analysis
      echo "File objects: $BASE_OBJ -> $TARGET_OBJ"
    fi
  fi
done
```

**Error Recovery and Validation:**
```bash
# Validate API responses
validate_api_response() {
  local file=$1
  if [[ ! -f "$file" ]]; then
    echo "❌ API response file not found: $file"
    return 1
  fi
  
  # Check if response contains error
  if grep -q '"error":\|"message":\|"statusCode":' "$file" 2>/dev/null; then
    echo "❌ API returned error:"
    cat "$file"
    return 1
  fi
  
  return 0
}

# Use validation before processing
if validate_api_response "/tmp/pr-${PR_ID}-changes.json"; then
  echo "✅ Successfully retrieved PR changes"
else
  echo "⚠️  API approach failed, falling back to git operations"
  # Fall back to git-based approaches
fi
```

### 5. Code Analysis Strategy
Create a systematic approach to analyze changes:
- **File Scope**: Identify all modified files and their types (.go, .proto, .yaml, etc.)
- **Change Classification**: Categorize changes (feature, bugfix, refactor, cleanup, etc.)
- **Impact Assessment**: Determine scope (breaking changes, customer impact, internal only)
- **Critical Path Analysis**: Focus on high-impact areas like APIs, security, performance

**IMPORTANT**: If any step fails, try the next strategy. Always clean up temporary worktrees.

### 6. Technical Review Areas

**Code Quality:**
- Go best practices and idiomatic patterns
- Error handling completeness and consistency
- Resource management (context cancellation, cleanup)
- Concurrency safety and race conditions
- Memory leaks and performance implications

**Architecture & Design:**
- API design consistency
- Interface contracts and backward compatibility
- Layer separation and dependency management
- Design pattern usage and appropriateness

**Testing Coverage:**
- Unit test completeness for new/changed code
- Test quality and edge case coverage
- Mock usage and test isolation
- Integration test considerations

**Security Review:**
- Input validation and sanitization
- Authentication and authorization checks
- Secrets and credential handling
- Logging of sensitive information

**AKS-Specific Concerns:**
- Azure resource management patterns
- Kubernetes client usage
- Feature flag implementation
- Customer impact and breaking changes
- Compliance with AKS coding standards

### 7. Error Handling and Recovery

**Authentication Issues:**
- If `az account get-access-token` fails, prompt user to run `az login` first
- Check for proper organization/project configuration with `az devops configure --list`
- Validate repository access permissions before making API calls

**API Issues:**
- If REST API calls fail (401/403), check authentication and permissions
- If PR not found (404), verify PR ID is correct and user has access
- If rate limiting (429), implement exponential backoff or suggest retry later
- Always validate API responses before processing

**Git Issues (Secondary/Fallback):**
- If commit/branch not found, try alternative git strategies above
- If worktree creation fails, use regular checkout in playground directory
- Always attempt cleanup, but don't fail if cleanup fails

**General Troubleshooting:**
- Use `--detect false` flag with Azure CLI commands to avoid auto-detection issues
- Set explicit timeouts for long-running operations (wget, git clone)
- Store temporary files in `/tmp/pr-<ID>-*` pattern for easy cleanup
- Provide clear error messages with suggested next steps

**Graceful Degradation Strategy:**
1. Try REST API approach first (most reliable)
2. Fall back to git operations if API fails
3. Use temporary clone only as last resort
4. Always clean up temporary files regardless of success/failure

### 8. Risk Assessment
Evaluate and categorize risks:
- **Critical**: Security vulnerabilities, data loss, service outages
- **High**: Breaking changes, performance degradation, reliability issues  
- **Medium**: Minor bugs, code maintainability, style issues
- **Low**: Documentation, logging improvements

### 9. Output Format

**IMPORTANT: Focus on issues found, not verbose positive feedback. Be concise and issue-oriented.**

Structure your review as follows:

```
# Azure DevOps Pull Request Review - PR #[NUMBER]

## PR Summary
- **Title:** [PR Title]
- **Author:** [Author Name]
- **Status:** [Active/Completed/etc.]
- **Goal:** [Brief description of PR objectives]

## Issues Found
### 🔴 Critical Issues
[File:Line] - [Issue description and suggested fix]

### 🟠 High Priority Issues  
[File:Line] - [Issue description and suggested fix]

### 🟡 Medium Priority Issues
[File:Line] - [Issue description and suggested fix]

### 🔵 Low Priority Issues
[File:Line] - [Issue description and suggested fix]

*If no issues in a category, omit that section entirely.*

## Security Concerns
[Only list actual security issues found - omit if none]

## Performance Impact
[Only list actual performance concerns - omit if none]

## Test Coverage Gaps
[Only list missing or inadequate test coverage - omit if adequate]

## Recommendations
[Only actionable recommendations for improvement - omit generic praise]

## Overall Verdict
[LGTM | LGTM with minor suggestions | Needs revision | Needs major revision]
```

**Output Guidelines:**
- **Skip verbose positive commentary** - don't list things that are "good" or "well done"
- **Focus on actionable items** - only mention what needs attention
- **Omit empty sections** - if no issues in a category, don't include that section
- **Be specific** - provide file names, line numbers, and concrete suggestions
- **Avoid generic praise** - focus on concrete improvements needed

### 10. Best Practices & Robustness Guidelines

**Analysis Best Practices:**
- **Be Specific**: Always provide file names and line numbers for issues
- **Be Constructive**: Offer solutions, not just criticism
- **Prioritize**: Focus on the most impactful issues first
- **Context Aware**: Consider the PR's scope and intended purpose
- **Consistent**: Follow established patterns and conventions in the codebase

**Robustness Guidelines:**
- **API-first approach**: Always try REST API before git operations for better reliability
- **Validate responses**: Check API responses for errors before processing
- **Parallel operations**: Use multiple bash tool calls in single message for parallel execution
- **Timeout management**: Set appropriate timeouts for API calls (30s) and git operations (5min)
- **Cleanup guarantee**: Always clean up temporary files in `/tmp/pr-*` pattern
- **Graceful degradation**: If one strategy fails, automatically try the next
- **Clear error reporting**: When operations fail, explain what went wrong and suggest next steps

**Command Execution Patterns:**
```bash
# Good: Parallel execution with validation
az account show; az devops configure --list; git fetch --all

# Good: API call with timeout and error handling
timeout 30 wget -q -O /tmp/pr-${PR_ID}-changes.json "API_URL" || {
  echo "❌ API call failed, trying git approach"
  # fallback strategy here
}

# Good: Cleanup with error handling
cleanup() {
  rm -f /tmp/pr-${PR_ID}-*.json
  rm -rf ~/aiplayground/pr-${PR_ID}-review 2>/dev/null || true
}
trap cleanup EXIT

# Good: Validation before processing
validate_api_response "/tmp/pr-${PR_ID}-changes.json" && {
  echo "✅ Processing API response"
  # process API response
} || {
  echo "⚠️ Falling back to git operations"
  # fallback strategy
}
```

---

## PR to Review: $ARGUMENTS

**Configuration:**

The system will check for configuration in the following order:
1. **Configuration file**: `~/.ado-pr-review.conf` (checked first)
2. **Environment variables**: ADO_ORG_URL, ADO_PROJECT, ADO_REPO (fallback)

If neither configuration method is found, you will see this notification:
```
⚠️  Configuration not found!
Neither ~/.ado-pr-review.conf file nor required environment variables are set.
Please configure using one of the methods below.
```

### Configuration Methods:

**Method 1: Configuration File (Recommended)**
Create `~/.ado-pr-review.conf` with the following content:
```bash
# Azure DevOps PR Review Configuration
# Replace values below with your actual organization, project, and repository names

ADO_ORG_URL=https://dev.azure.com/msazure
ADO_PROJECT=CloudNativeCompute
ADO_REPO=aks-rp
```

**Method 2: Environment Variables**
```bash
export ADO_ORG_URL=https://dev.azure.com/msazure
export ADO_PROJECT=CloudNativeCompute
export ADO_REPO=aks-rp
```

**Note**: The configuration file method is recommended as it persists across sessions and doesn't require setting variables each time. 