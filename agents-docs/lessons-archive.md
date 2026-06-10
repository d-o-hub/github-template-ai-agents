# Archived Project-Wide Learnings

- **Locale-Independent Sort**: Use `LC_ALL=C sort` for committed generator output to prevent CI drift (LESSON-018)
- **Nested node_modules**: Use `*/node_modules/*` in `find` to exclude at any depth, not just root (LESSON-019)
- **CI Symlink Dependency**: Always run `setup-skills.sh` before `validate-skills.sh` in CI workflows (LESSON-017)
- **Action SHA Pinning**: Pin to 40-char SHAs for security (LESSON-016)
- **Worktree Cleanup**: Use `trap cleanup EXIT ERR` and `CREATED_WORKTREES` (LESSON-010)
- **Dependabot Auto-Merge**: Use `enablePullRequestAutoMerge` (GraphQL) not `pulls.merge()` (REST); Dependabot's restricted token can't push branches, but GitHub native auto-merge uses system privileges for linear history + branch updates (LESSON-023)
- **Update CI Status on Dependabot**: Skip `update-ci-status` job with `github.actor != 'dependabot[bot]'` guard; Dependabot's read-only token causes git push failures that block auto-merge (LESSON-023)
- **ADR Compliance Gate**: The quality gate already runs `check-adr-compliance.sh` — no new gate needed. After creating an ADR in `plans/adr-*.md`, always register it in `plans/_status.json` entries and bump `nextAvailable.adr` (LESSON-024)
- **Markdown Test Fixtures**: BATS tests creating `.md` fixture files via `printf` must end with `\n` to pass markdownlint MD047/single-trailing-newline (LESSON-025)
