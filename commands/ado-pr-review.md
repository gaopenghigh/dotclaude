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
- **Safety First**: Use git worktree to avoid modifying the current branch
- **Prerequisites**: Verify Azure CLI is configured and accessible

### 2. PR Information Gathering
Fetch comprehensive PR details including:
- Title, author, description, status (active/completed/abandoned)
- Source and target branches
- Creation date, reviewers, and voting status
- Merge status and any merge conflicts
- Related work items and linked issues

### 3. Code Analysis Strategy
Create a systematic approach to analyze changes:
- **File Scope**: Identify all modified files and their types (.go, .proto, .yaml, etc.)
- **Change Classification**: Categorize changes (feature, bugfix, refactor, cleanup, etc.)
- **Impact Assessment**: Determine scope (breaking changes, customer impact, internal only)
- **Critical Path Analysis**: Focus on high-impact areas like APIs, security, performance

### 4. Technical Review Areas

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

### 5. Risk Assessment
Evaluate and categorize risks:
- **Critical**: Security vulnerabilities, data loss, service outages
- **High**: Breaking changes, performance degradation, reliability issues  
- **Medium**: Minor bugs, code maintainability, style issues
- **Low**: Documentation, logging improvements

### 6. Output Format

Structure your review as follows:

```
# Azure DevOps Pull Request Review - PR #[NUMBER]

## PR Summary
- **Title:** [PR Title]
- **Author:** [Author Name]
- **Status:** [Active/Completed/etc.]
- **Goal:** [Brief description of PR objectives]

## Code Analysis
[Systematic analysis of changes with file-by-file breakdown]

## Issues Found
### 🔴 Critical Issues
[File:Line] - [Issue description and suggested fix]

### 🟠 High Priority Issues  
[File:Line] - [Issue description and suggested fix]

### 🟡 Medium Priority Issues
[File:Line] - [Issue description and suggested fix]

### 🔵 Low Priority Issues
[File:Line] - [Issue description and suggested fix]

## Security Review
[Security-specific findings]

## Performance Implications
[Performance impact analysis]

## Testing Assessment
[Test coverage and quality evaluation]

## Recommendations
[Specific actionable recommendations]

## Overall Verdict
[LGTM with conditions | Needs major revision | LGTM]
```

### 7. Best Practices
- **Be Specific**: Always provide file names and line numbers for issues
- **Be Constructive**: Offer solutions, not just criticism
- **Prioritize**: Focus on the most impactful issues first
- **Context Aware**: Consider the PR's scope and intended purpose
- **Consistent**: Follow established patterns and conventions in the codebase

---

## PR to Review: $ARGUMENTS

**Configuration:**
- Organization: Configured via ADO_ORG_URL environment variable
- Project: Configured via ADO_PROJECT environment variable
- Repository: Configured via ADO_REPO environment variable

Setup Instructions:
1. Set environment variables:
   - export ADO_ORG_URL=https://dev.azure.com/your-org
   - export ADO_PROJECT=your-project
   - export ADO_REPO=your-repository

2. Or create ~/.ado-pr-review.conf with the same variables 