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

### 3. Fetching PR Changes - Multi-Strategy Approach

**Primary Strategy - Azure CLI:**
```bash
# Configure defaults first if not done
az devops configure --defaults organization=<ORG-URL> project=<PROJECT>

# Get PR details
az repos pr show --id <PR-ID>

# Get file changes 
az repos pr show --id <PR-ID> --query "lastMergeSourceCommit.commitId"
```

**Secondary Strategy - Git Operations:**

Use directory ~/aiplayground for all the git worktree or other commands that fetch/get/edit files.

```bash
# Find the PR source branch
git branch -r | grep -i <author-name> | grep -i <keyword>

# Get diff using branch comparison
git diff origin/master...origin/<pr-branch> --name-only
git diff origin/master...origin/<pr-branch>

# Alternative: Use merge base if available
git merge-base origin/master origin/<pr-branch>
git diff <merge-base>..origin/<pr-branch>
```

**Tertiary Strategy - Worktree Creation:**
```bash
# Create worktree from specific commit (if merge commit available)
git worktree add /tmp/pr-<ID>-review <commit-id>

# Create worktree from PR branch
git worktree add /tmp/pr-<ID>-review origin/<pr-branch>

# Always cleanup afterwards
git worktree remove /tmp/pr-<ID>-review
```

**Fallback Strategy - Direct Branch Analysis:**
```bash
# If PR is merged, look for merge commit
git log --grep="<PR-ID>" --oneline master

# Check recent merges
git log --oneline --merges master | head -10
```

### 4. Code Analysis Strategy
Create a systematic approach to analyze changes:
- **File Scope**: Identify all modified files and their types (.go, .proto, .yaml, etc.)
- **Change Classification**: Categorize changes (feature, bugfix, refactor, cleanup, etc.)
- **Impact Assessment**: Determine scope (breaking changes, customer impact, internal only)
- **Critical Path Analysis**: Focus on high-impact areas like APIs, security, performance

**IMPORTANT**: If any step fails, try the next strategy. Always clean up temporary worktrees.

### 5. Technical Review Areas

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

### 6. Error Handling and Recovery

**Authentication Issues:**
- If `az login` is required, prompt user to authenticate first
- Check for proper organization/project configuration
- Validate repository access permissions

**Git Issues:**
- If commit/branch not found, try alternative strategies above
- If worktree creation fails, fall back to direct branch checkout
- Always attempt cleanup, but don't fail if cleanup fails

**General Troubleshooting:**
- Use `--detect false` flag with Azure CLI commands to avoid auto-detection issues
- Set explicit timeouts for long-running operations
- Provide clear error messages with suggested next steps

### 7. Risk Assessment
Evaluate and categorize risks:
- **Critical**: Security vulnerabilities, data loss, service outages
- **High**: Breaking changes, performance degradation, reliability issues  
- **Medium**: Minor bugs, code maintainability, style issues
- **Low**: Documentation, logging improvements

### 8. Output Format

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

### 9. Best Practices & Robustness Guidelines

**Analysis Best Practices:**
- **Be Specific**: Always provide file names and line numbers for issues
- **Be Constructive**: Offer solutions, not just criticism
- **Prioritize**: Focus on the most impactful issues first
- **Context Aware**: Consider the PR's scope and intended purpose
- **Consistent**: Follow established patterns and conventions in the codebase

**Robustness Guidelines:**
- **Always fetch latest**: Run `git fetch --all` before any analysis
- **Parallel operations**: Use multiple bash tool calls in single message for parallel execution
- **Timeout management**: Set appropriate timeouts for long operations (max 10 minutes)
- **Cleanup guarantee**: Always clean up temporary worktrees, even if analysis fails
- **Graceful degradation**: If one strategy fails, try the next automatically
- **Clear error reporting**: When operations fail, explain what went wrong and what to try next

**Command Execution Patterns:**
```bash
# Good: Parallel execution in single message
git status; git fetch --all; az account show

# Good: Cleanup with error handling  
git worktree remove /tmp/pr-review || echo "Cleanup failed, continuing..."

# Good: Explicit timeout for long operations
timeout 300 ./hack/aksbuilder.sh test -w <workspace>
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