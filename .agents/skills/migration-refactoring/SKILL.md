---
name: migration-refactoring
version: "0.2.10"
category: code-quality
description: Automate complex code migrations, cross-file refactorings, and move-only file decompositions with safety patterns. Use this skill when a dependency upgrade forces source changes, when migrating frameworks (React class→hooks, Flask→FastAPI), modernizing languages (Python 2→3), or splitting large files near size ceilings without behavior change — even if they say "split this large file", "extract module", or "keep the diff move-only". Includes breaking change analysis, automated fix application, rollback strategies, and cross-file dependency tracking. Not for static-analysis, code-review-assistant, or routine patch/minor/CVE bumps (use dependency-upgrades).
license: MIT
---

# Migration & Refactoring

Systematic approach to complex code migrations, structural refactorings, and move-only decompositions with safety guardrails and rollback capabilities.

## When to Use

- **Move-only decomposition** - Splitting large files near size ceilings (e.g., 500 LOC limits) without behavioral change ("split this large file", "extract module", "keep diff move-only")
- **Dependency upgrades that force source changes** - Major bumps with breaking APIs; routine patch/minor/CVE bumps go to `dependency-upgrades`
- **Framework migrations** - React class→hooks, Flask→FastAPI, Django→DRF, etc.
- **Language modernizations** - Python 2→3, JavaScript→TypeScript
- **Large-scale refactoring** - Cross-file changes requiring structural consistency
- **Database schema evolution** - Migrations with data transformation
- **Monorepo decomposition** - Extracting services from monoliths

## When NOT to Use

- **Routine patch/minor/CVE dependency upgrades** - Use `dependency-upgrades`
- **Static analysis and linter-only fixes** - Use `static-analysis`
- **PR code reviews and feedback analysis** - Use `code-review-assistant`

## Move-Only Decomposition Workflow

Dedicated procedure for splitting large files without behavioral change. Keep distinct from semantic migrations with intentional logic or interface changes.

1. **Establish Trigger & Baseline**: Document the LOC/complexity ceiling warning (e.g., 500 LOC). Verify test suite passes before edits.
2. **Identify Extraction Seams**: Analyze cohesive module boundaries. Map public/private visibility, imported dependencies, initialization sequence, and test ownership. Watch for circular deps or global state.
3. **Mechanical Move**: Extract code purely mechanically. Do not mix behavioral refactoring, performance tweaks, or reformatting into the move commit.
4. **Validate Tests**: Run narrow unit tests first, followed by full repository quality gate checks (`scripts/quality_gate.sh`).
5. **Review Move-Aware Diff**: Inspect diff using `git diff --find-renames` (`git diff -M`) to verify pure structural relocation without line edits or type changes.
6. **Handle Unintentional Semantic Changes**: If behavior changes were added accidentally, stop, revert or isolate them into a separate commit/PR with dedicated tests.
7. **Revise Seam Boundaries**: If tests fail or contracts break, re-evaluate seam boundaries and visibility before re-attempting the move.

## Core Workflow

### Phase 1: Analysis

1. **Identify scope** - What files, modules, and dependencies are affected?
2. **Map dependencies** - Create a dependency graph of cross-file relationships
3. **Find breaking changes** - Analyze changelogs, migration guides, deprecation warnings
4. **Assess risk** - Flag high-risk changes (public APIs, critical paths)

### Phase 2: Planning

1. **Create migration plan** - Ordered sequence of changes
2. **Define checkpoints** - Intermediate states that compile/work
3. **Design rollback strategy** - How to revert if issues arise
4. **Estimate effort** - Time and complexity assessment

### Phase 3: Execution

1. **Execute in phases** - Apply changes incrementally
2. **Validate at each checkpoint** - Test compilation, run tests, verify functionality
3. **Document changes** - Update docs, changelogs, ADRs
4. **Commit incrementally** - Each checkpoint is a commit

### Phase 4: Validation

1. **Run full test suite** - Verify nothing broken
2. **Performance testing** - Ensure no regressions
3. **Code review** - Human validation of changes
4. **Production rollout** - Deploy with monitoring

## Migration Patterns

### Pattern 1: Gradual Migration

```
Old API → Compatibility Layer → New API → Remove Old
```

**When**: Cannot change all call sites at once

### Pattern 2: Feature Flags

```javascript
if (useNewImplementation) {
  return newImplementation();
} else {
  return oldImplementation();
}
```

**When**: High-risk changes needing rollback capability

### Pattern 3: Strangler Fig

```
Monolith → Proxy → New Service
              → Old Monolith
```

**When**: Decomposing monoliths incrementally

### Pattern 4: Parallel Implementation

```
Old System (read-only) → Data Sync → New System (write)
```

**When**: Zero-downtime migrations with data changes

See `references/migration-patterns.md` for detailed implementations.

## Breaking Change Analysis

### Checklist for Upgrades

- [ ] Review CHANGELOG for breaking changes
- [ ] Check deprecation warnings in current version
- [ ] Identify removed/renamed APIs
- [ ] Find changed default behaviors
- [ ] Note environment/dependency changes
- [ ] Review migration guide if available
- [ ] Search for known issues in community

### Common Breaking Changes

| Category | Examples |
|----------|----------|
| API Removal | `function removed()` |
| Signature Changes | `func(a, b)` → `func(a, b, c)` |
| Default Changes | `encoding='utf-8'` → `encoding=None'` |
| Dependency Drops | Dropped Python 3.8 support |
| Return Type Changes | `list` → `generator` |

## Cross-File Dependency Tracking

### Dependency Graph Elements

- **Imports/includes** - File A imports File B
- **Inheritance** - Class A extends Class B
- **Interface implementations** - Class implements Interface
- **Function calls** - Function in A calls function in B

### Tools by Language

- **Python**: `pydeps`, `importlab`
- **JavaScript/TypeScript**: `dependency-cruiser`, `madge`
- **Java**: `jdeps`, `classycle`
- **Go**: `godepgraph`
- **Rust**: `cargo-deps`

See `references/dependency-analysis.md` for detailed usage.

## Safety Patterns

### Snapshot Testing

```python
# Before migration: capture expected outputs
save_snapshot(test_output, "v1_expected.json")

# After migration: compare
assert_matches_snapshot(actual_output, "v1_expected.json")
```

### Property-Based Testing

```python
# Verify invariants hold post-migration
@given(st.data())
def test_migration_preserves_properties(data):
    old_result = old_implementation(data)
    new_result = new_implementation(data)
    assert old_result.property == new_result.property
```

### Canary Deployments

1. Deploy to 1% of traffic
2. Monitor error rates, latency
3. Gradually increase to 100%
4. Rollback if issues detected

See `references/safety-patterns.md` for more patterns.

## Rollback Strategies

| Strategy | Best for | Example |
|---|---|---|
| Git Revert | Small, isolated migrations | `git revert <migration-commit>` |
| Feature Flag Disable | Gradual rollouts | `USE_NEW_PARSER = False` |
| Database Rollback | Schema changes with data loss | `ALTER TABLE users DROP COLUMN ...` |

See `references/rollback-strategies.md` for platform-specific guides.

## Examples

**React Class to Hooks:** `componentDidMount`/`componentWillUnmount` → `useEffect`, `componentDidUpdate` → `useEffect` with deps, `this.state` → `useState`, `this.props` → destructured.

**Python 2 to 3:** `2to3 -w --output-dir=src_py3 src/` then fix imports, print, string handling. See `references/language-migrations.md`.

## Quality Checklist

- [ ] Breaking changes documented
- [ ] Rollback procedure tested
- [ ] All dependencies mapped
- [ ] Checkpoints defined and validated
- [ ] Test coverage maintained or improved
- [ ] Performance regression testing done
- [ ] Code review completed
- [ ] Documentation updated

## See Also

- `static-analysis` — Linter triage and fix workflows
- `code-review-assistant` — PR review workflow
- `dependency-upgrades` — Routine patch/minor/CVE version bumps
- `testing-strategy` — Test design and coverage guidelines

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "We'll migrate everything at once in one big PR" | Big-bang migrations create untestable changesets with no safe rollback point. |
| "The old version still works, no rush to migrate" | Unmaintained dependencies accumulate CVEs and block critical security patches. |
| "Automated tests are enough validation" | Automated tests catch regressions; human review catches design and UX regressions. |

## Red Flags

- [ ] Starting a migration without a documented rollback strategy
- [ ] Migrating multiple major dependencies in a single commit
- [ ] Skipping checkpoint validation between migration phases

## References

- `references/migration-patterns.md` - Detailed pattern implementations
- `references/dependency-analysis.md` - Cross-file dependency tracking
- `references/language-migrations.md` - Framework migration guides
