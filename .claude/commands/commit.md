---
description: Create a conventional commit
---

# Create a conventional commit

Use this command to create a valid conventional commit.

## Usage

```bash
./scripts/ai-commit.sh --type <type> [--scope <scope>] --subject <subject> [--body <body> ...]
```

## Rules

1. **Type**: Must be one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
2. **Subject**: Max 72 characters, imperative mood, no period at the end.
3. **Body**: Use multiple `--body` flags for multiple paragraphs. Lines are automatically wrapped at 100 characters.

## Manual Commits

If you commit manually, the `commit-msg` hook will validate your message. If it fails, use `git commit --amend` to fix it.
