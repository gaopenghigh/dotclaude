# Claude Configuration Directory

This repository contains configuration files and tools for Claude Code, a VS Code extension and standalone application for AI-assisted development.

## Structure

```
.claude/
├── settings.json          # Core Claude configuration
├── CLAUDE.md             # Personal coding instructions for Claude
├── plugins/              # Custom shell scripts and tools
│   └── ado-pr-review.sh  # Azure DevOps PR review tool
├── commands/             # Command definitions and documentation
│   └── ado-pr-review.md  # ADO PR review command docs
└── .gitignore           # Excludes sensitive/temporary data
```

## Files Included

### Core Configuration
- **`settings.json`**: Contains API configuration, permissions, and environment variables
- **`CLAUDE.md`**: Personal instructions that guide Claude's behavior across all projects

### Custom Tools
- **`plugins/ado-pr-review.sh`**: Script for fetching and analyzing Azure DevOps pull requests
- **`commands/ado-pr-review.md`**: Documentation and instructions for the PR review command

## Setup Instructions

### 1. Basic Setup
1. Clone this repository to your `~/.claude` directory
2. Customize `settings.json` with your preferred configuration
3. Modify `CLAUDE.md` with your coding preferences

### 2. Azure DevOps PR Review Tool Setup
The ADO PR review tool requires configuration:

**Option 1: Environment Variables**
```bash
export ADO_ORG_URL=https://dev.azure.com/your-org
export ADO_PROJECT=your-project
export ADO_REPO=your-repository
```

**Option 2: Configuration File**
Create `~/.ado-pr-review.conf`:
```bash
ADO_ORG_URL=https://dev.azure.com/your-org
ADO_PROJECT=your-project
ADO_REPO=your-repository
```

### 3. Prerequisites
- Azure CLI (`az`) installed and logged in
- `jq` for JSON processing
- `git` for repository operations

## Security Notes

This repository excludes sensitive data:
- Project conversation logs (`projects/` directory)
- Task tracking data (`todos/` directory) 
- Shell snapshots (`shell-snapshots/` directory)
- IDE lock files (`ide/` directory)

The included `settings.json` contains only dummy tokens and is safe to share.

## Usage

### Azure DevOps PR Review
```bash
# Review by PR number
/ado-pr-review 12345

# Review by full URL
/ado-pr-review https://dev.azure.com/your-org/your-project/_git/your-repo/pullrequest/12345
```

## Customization

Feel free to:
- Modify coding preferences in `CLAUDE.md`
- Add your own plugins to the `plugins/` directory
- Create additional commands in the `commands/` directory
- Adjust permissions and settings in `settings.json`

## Contributing

If you create useful plugins or improvements:
1. Ensure no personal/sensitive information is included
2. Test with different Azure DevOps configurations
3. Update documentation as needed