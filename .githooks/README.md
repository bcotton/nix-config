# Git Hooks

This directory contains version-controlled git hooks for the repository.

## Automatic Installation

Git hooks are **automatically installed** when you run any of these commands:
- `just build`
- `just switch`
- `just fmt`

The installation is idempotent—it only configures the hooks path once.

## Manual Installation

To manually install the hooks:

```bash
just install-hooks
```

This sets the git config `core.hooksPath` to `.githooks`, causing git to use hooks from this directory instead of `.git/hooks/`.

## Available Hooks

### pre-commit

Runs before each commit to ensure code quality:
- Formats all Nix files using `just fmt` (alejandra)
- Re-stages any formatted files
- Prevents commits if formatting fails

## Bypassing Hooks

If you need to bypass hooks (use sparingly):

```bash
git commit --no-verify
```

## Adding New Hooks

1. Create a new executable file in `.githooks/` (e.g., `pre-push`, `commit-msg`)
2. Make it executable: `chmod +x .githooks/<hook-name>`
3. Test it: `git <action>` (the hook will run automatically)
4. Commit the hook file to the repository

## Technical Details

- Hooks are stored in `.githooks/` and version-controlled
- Git is configured to use this directory via `git config core.hooksPath .githooks`
- This setting is stored in `.git/config` (local to each clone)
- Each developer needs to run `just install-hooks` once (or run any just command that depends on it)
