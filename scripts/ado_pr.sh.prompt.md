Create a ado_pr.sh script that can do the ADO PR fetch and clean up work. Steps:
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