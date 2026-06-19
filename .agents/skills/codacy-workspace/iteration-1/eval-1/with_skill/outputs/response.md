# Codacy Analysis Results

**Repository**: `/workspaces/github-template-ai-agents`
**Tool**: ShellCheck 0.9.0 (via `codacy-analysis`)
**Date**: 2026-06-19

## Summary

| Severity | Count |
|----------|-------|
| Error    | 0     |
| Warning  | 40    |
| Info     | 77    |
| **Total** | **117** |

## Analysis Configuration

- **CLI**: `@codacy/analysis-cli` v0.10.1
- **Tool detected**: ShellCheck (79 shell files routed)
- **Config source**: Local `.codacy/codacy.config.json` (auto-generated via `codacy-analysis init`)
- **Note**: ShellCheck 0.9.0 does not support `--rcfile`; ran directly with `shellcheck --format=json` for clean results

## Warnings (40)

### SC2034 — Variables appear unused
| File | Line | Variable |
|------|------|----------|
| `tests/verify-version-logic.sh` | 8, 9, 10, 24 | `SKILL_NAME`, `YELLOW`, `NC`, `skill_name` |
| `tests/test-commitlint-rules.sh` | 20 | `AGENTS_MD` |
| `scripts/lib/skill-validation.sh` | 7, 18, 138 | `SKILLS_SRC`, `GREEN`, `SKILL_LINE_COUNT` |
| `scripts/verify-commands.sh` | 173, 217 | `CACHED`, `TOTAL_ALL` |
| `scripts/benchmark-command-verify.sh` | 21 | `i` |
| `scripts/validate-skills.sh` | 212 | `WARNINGS` |
| `scripts/discover-commands.sh` | 10 | `OUTPUT_FILE` |
| `scripts/validate-config.sh` | 16 | `value` |

### SC2155 — Declare and assign separately to avoid masking return values
| File | Lines |
|------|-------|
| `.agents/skills/git-github-workflow/run.sh` | 197, 199, 204, 205, 217, 279, 287, 288, 341, 348, 407, 412, 423, 424, 458, 596 |

### SC2206 — Quote to prevent word splitting/globbing
| File | Line |
|------|------|
| `scripts/lib/command-cache.sh` | 67 |
| `scripts/lib/command-invalidation.sh` | 99 |
| `scripts/lib/skill-validation.sh` | 73 |
| `scripts/cleanup-ci-status-prs.sh` | 34 |
| `scripts/docs-sync.sh` | 19 |

### SC2207 — Prefer mapfile or read -a to split command output
| File | Line |
|------|------|
| `scripts/validate-links.sh` | 244-252 |
| `scripts/self-fix-loop.sh` | 289 |
| `scripts/validate-workflows.sh` | 47-100 |

### SC2115 — Use `${var:?}` to ensure this never expands to /*
| File | Line |
|------|------|
| `scripts/lib/command-cache.sh` | 164 |

### SC1090 — Can't follow non-constant source
| File | Line |
|------|------|
| `scripts/verify-commands.sh` | 30 |

## Info (77)

### SC2059 — Don't use variables in printf format string
Most common info-level issue. Found across:
- `tests/test-llms-txt-generation.sh` (lines 73, 100, 124, 146, 162, 164)
- `tests/test-generate-llms-txt-block-scalars.sh` (lines 60, 87, 110, 133, 135)
- `tests/test-workflow-validation.sh` (lines 35, 43, 45)
- `scripts/validate-links.sh` (lines 359, 376)
- `scripts/health-check.sh` (lines 79, 103, 109, 120, 130, 134, 136, 141, 143, 172)
- `scripts/verify-commands.sh` (lines 84, 104, 109, 238, 251, 259, 269)
- `scripts/validate-skills.sh` (lines 221, 225)
- `scripts/validate-workflows.sh` (lines 137, 140)

### SC2317 — Command appears to be unreachable
| File | Lines |
|------|-------|
| `scripts/check-adr-compliance.sh` | 20 |
| `scripts/wasm_size_gate.sh` | 24 |
| `scripts/generate-llms-txt.sh` | 47 |
| `scripts/generate-skills-reference.sh` | 49 |
| `scripts/swarm-worktree-web-research.sh` | 63-85 (many unreachable lines) |
| `scripts/validate-workflows.sh` | 18 |

### SC2016 — Expressions don't expand in single quotes
| File | Lines |
|------|-------|
| `tests/test-sentinel-hardening.sh` | 40 |
| `tests/test-lifecycle-management-js.sh` | 11 |
| `scripts/generate-skills-reference.sh` | 79-141, 153-161 |
| `scripts/analyze-codebase.sh` | 218 |
| `scripts/discover-commands.sh` | 30-70 |

### SC2030 / SC2031 — Subshell modification issues
| File | Lines |
|------|-------|
| `tests/test-llms-txt-generation.sh` | 114-115, 145-146, 160-161 |

### SC2295 — Expansions inside `${..}` need quoting
| File | Line |
|------|------|
| `scripts/analyze-codebase.sh` | 226 |

### SC2086 — Double quote to prevent globbing and word splitting
| File | Line |
|------|------|
| `scripts/quality_gate.sh` | 337 |

## No Errors Found

Zero error-level issues detected. All warnings are informational or advisory.

## Key Takeaways

1. **No critical issues** — 0 errors across 79 shell scripts
2. **SC2155 in git-github-workflow/run.sh** — 16 instances of declare-and-assign-separately; most impactful warning to fix
3. **SC2034 unused variables** — 11 instances; likely safe (exported for subshells) but worth verifying
4. **SC2059 printf format strings** — 25+ instances; cosmetic but easy to fix with `printf '%s' "$var"` pattern
5. **SC2207 word splitting** — 3 instances; potential runtime issues if filenames contain spaces
