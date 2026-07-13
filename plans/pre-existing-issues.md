# Pre-existing Issues

Follow-up tracker for known debt. Update when resolved.

## Resolved (2026-07-11 hygiene)

| Issue | Resolution |
|-------|------------|
| Skills missing `version:` frontmatter | All skills now declare `version:` |
| Broken `*-workspace` CLI symlinks | Pruned; setup-skills reconciles |
| Stale renamed skill links (e.g. anti-ai-slop) | Pruned; `.qwen/skills/` removed |
| `plans/_status.json` nextAvailable stuck at adr-011 | Updated to adr-030; GOAP_STATE restored |

## Open / deferred

### validate-links empty / malformed input

**Status:** Hardened with empty-file-list guards (no hang on empty discovery).  
**Remaining:** Edge cases with malformed binary input still low priority.

### Codacy High findings (assert in tests)

**Status:** Deferred to Codacy dashboard (SonarPython S101 not suppressible via CLI).  
**Action:** Manual suppression of test-file assert findings when Codacy is connected.
