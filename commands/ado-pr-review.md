---
allowed-tools: Task(*), Read(*), TodoWrite(*)
argument-hint: <PR-URL-or-ID>
description: Orchestrates Azure DevOps pull request review using specialized sub-agents
---

Review Azure DevOps (ADO) Pull Request. 

# Basic Information

Basic information:
- Org: https://dev.azure.com/msazure
- Project: CloudNativeCompute
- Default repo: aks-rp

Directories:
- ROOT_SANDBOX: `~/aiplayground/`
- BARE_REPO: `{ROOT_SANDBOX}/ado-pr-fetcher/bare-repos/{repo}`
- PR_DATA: `{ROOT_SANDBOX}/ado-pr-fetcher/pr-data/{repo}-{id}/`

For example, for PR `https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp/pullrequest/13340120`:
- BARE_REPO is `~/aiplayground/ado-pr-fetcher/bare-repos/aks-rp`
- PR_DATA is `~/aiplayground/ado-pr-fetcher/pr-data/aks-rp-13340120`

# Step 1: Fetch PR

- Check Azure auth (`az account show`)
- Configure the defaults of devops via `az devops` CLI command, e.g. `az devops configure --defaults organization=https://dev.azure.com/msazure project=CloudNativeCompute`.
- Parse PR id (and repo if provided or from URL; fallback to default repo), make sure it's ADO PR not github PR.
- Get PR metadata by using `az` CLI or call ADO API, e.g. `az repos pr show --id 12345`. We need only these informations: source branch, author (createdBy), description, rewrite as a markdown file `{PR_DATA}/metadata.md`
- Ensure dirs exist: `{ROOT_SANDBOX}/ado-pr-fetcher/{bare-repos,pr-data}`
- Ensure bare repo exists (clone if missing)
- Emsure we are in master branch and have the latest code, which means we are exactly the same as remote master.
- Get the actual changes of the PR, create diff patch, store as file `{PR_DATA}/diff.patch`.
    1. Create worktree for this PR branch in `{PR_DATA}/worktree`, if the worktree already exists, remove it via `git worktree` commands.
    2. In the worktree directory, merge master branch, so it represent the codes when the PR get merged. This step is IMPORTANT!
    3. In the worktree directory, get the diff via `git diff master`.


# Step 2: Review

**Code Quality:**
- Go best practices and idiomatic patterns
- Error handling completeness and consistency
- Resource management (context cancellation, cleanup)
- Concurrency safety and race conditions
- Memory leaks, goroutine leaks, and performance implications

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

**⚠️ CRITICAL CONCURRENCY ANALYSIS (MANDATORY):**
For ANY code containing goroutines, channels, or concurrent operations, perform DEEP analysis:

1. **Goroutine Lifecycle Management:**
   - Are goroutines properly cancelled when parent context is cancelled?
   - Is there a mechanism to wait for goroutine completion before function returns?
   - Are there any code paths that can abandon running goroutines?
   - Do goroutines have panic recovery mechanisms?

2. **Context Cancellation Propagation:**
   - Do long-running operations inside goroutines check `ctx.Done()`?
   - Are child contexts properly cancelled to terminate goroutines?
   - Are there timeout enforcement mechanisms at appropriate levels?

3. **Channel Safety:**
   - Can channels become deadlocked if goroutines panic or exit early?
   - Are channel buffers appropriately sized for the concurrency model?
   - Are channels properly closed to prevent reader deadlocks?

4. **Race Condition Analysis:**
   - Are shared data structures accessed safely across goroutines?
   - Is there proper synchronization for maps, slices, or other shared state?
   - Are there any write-after-read or read-after-write hazards?

5. **Resource Limits:**
   - Is there a limit on concurrent goroutine creation?
   - Could unbounded concurrency overwhelm external APIs or resources?
   - Are there appropriate backpressure mechanisms?

6. **Memory Management:**
   - Could goroutines hold references preventing garbage collection?
   - Are there potential memory leaks from abandoned goroutines?
   - Do cleanup mechanisms ensure resource deallocation?

**Concurrency Testing Requirements:**
- Verify tests cover concurrent execution scenarios
- Check for context cancellation test cases
- Ensure race condition testing (suggest `-race` flag usage)
- Validate goroutine leak detection in tests

**FAIL THE REVIEW** if any of these concurrency safety issues are present without proper mitigation.

**IMPORTANT**: 
- Think Hard - Especially about concurrent code paths.
- Don't try to build, run unit tests, etc, they are already done by automation pipelines.
- Out put the review report into `{ROOT_SANDBOX}/output/ado-pr-review/pr-{id}` directory.
- Create separate detailed concurrency analysis if issues found.
- Confirm with user whether further review needed.


# Step 3: Clean Up

Confirm with user before starting clean up, if user agreed:
1. Understand which PR (repo and PR ID) that need to clean up.
2. Clean up worktree `git worktree` commands.
3. Remove `{PR_DATA}` directory.
