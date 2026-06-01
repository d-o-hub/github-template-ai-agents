#!/usr/bin/env bash
# Install git hooks from .githooks directory.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "Configuring git to use .githooks directory..."
git config core.hooksPath .githooks

echo "Ensuring hooks are executable..."
# Security: Use -- to prevent option injection from filenames starting with -
chmod +x -- "$REPO_ROOT/.githooks/"*

echo "Git hooks installed successfully."
