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

Use code-reviewer sub agent to do the first round review, provide detailed context like the `{PR_DATA}` directory, the diff file, and the worktree.
At the same time, use golang-code-reviewer to do the second round review if any golang code been updated in the PR, also provide detailed context.
Write the review report into file `{ROOT_SANDBOX}/output/ado-pr-review/pr-{id}/review_report.md`.

Confirm with user whether further review needed.


# Step 3: Clean Up

Confirm with user before starting clean up, if user agreed:
1. Understand which PR (repo and PR ID) that need to clean up.
2. Clean up worktree `git worktree` commands.
3. Remove `{PR_DATA}` directory.
