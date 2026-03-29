---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
license: MIT
---

# Skill Creator

Create and improve skills following the Agent Skills specification. A skill extends agent capabilities with specialized knowledge, workflows, and tools.

## Core Loop

1. **Capture intent** - What should the skill do? When should it trigger?
2. **Write draft** - Create SKILL.md with frontmatter and instructions
3. **Create test cases** - Realistic prompts users would actually say
4. **Run evals** - Test with-skill vs baseline (or old version)
5. **Review results** - Use eval-viewer for human review + benchmarks
6. **Iterate** - Improve based on feedback until satisfied
7. **Optimize description** - Fine-tune frontmatter for better triggering

---

## Part 1: Skill Specification

### Directory Structure

```
skill-name/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
├── assets/           # Optional: templates, resources
└── evals/            # Optional: test cases
```

### Frontmatter Fields

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | Max 64 chars. Lowercase letters, numbers, hyphens only. Must not start/end with hyphen. |
| `description` | Yes | Max 1024 chars. Describes what the skill does AND when to use it. |
| `license` | No | License name or reference to bundled license file. |
| `compatibility` | No | Max 500 chars. Environment requirements. |
| `metadata` | No | Arbitrary key-value mapping. |
| `allowed-tools` | No | Space-delimited list of pre-approved tools. |

### SKILL.md Body

- Keep under **250 lines**
- Use progressive disclosure: move detailed reference material to `references/`
- Include step-by-step instructions, examples, and common edge cases

---

## Part 2: Best Practices for Skill Creators

### Start from Real Expertise

A common pitfall is asking an LLM to generate a skill without domain-specific context. The result is vague, generic procedures rather than specific API patterns, edge cases, and project conventions.

**Extract from a Hands-On Task:**
- Complete a real task with an agent, providing context, corrections, and preferences
- Extract the reusable pattern, paying attention to:
  - Steps that worked
  - Corrections you made
  - Input/output formats
  - Context you provided

**Synthesize from Existing Project Artifacts:**
- Internal documentation, runbooks, and style guides
- API specifications, schemas, and configuration files
- Code review comments and issue trackers
- Real-world failure cases and their resolutions

### Refine with Real Execution

Run the skill against real tasks, then feed results back:

- What triggered false positives?
- What was missed?
- What could be cut?

### Spend Context Wisely

Focus on what the agent *wouldn't* know without your skill:
- Project-specific conventions
- Domain-specific procedures
- Non-obvious edge cases
- Particular tools or APIs to use

**Don't explain:** what a PDF is, how HTTP works, or what a database migration does.

### Calibrating Control

**Give freedom** when:
- Multiple approaches are valid
- Task tolerates variation

**Be prescriptive** when:
- Operations are fragile
- Consistency matters
- Specific sequence must be followed

### Effective Instruction Patterns

**Gotchas Sections** (highest-value content):
```markdown
## Gotchas
- The `users` table uses soft deletes. Queries must include `WHERE deleted_at IS NULL`.
- The user ID is `user_id` in the database, `uid` in the auth service.
- The `/health` endpoint returns 200 even if the database is down. Use `/ready`.
```

**Templates for Output Format:**
Provide a template rather than describing format in prose.

**Checklists for Multi-Step Workflows:**
```markdown
## Workflow
- [ ] Step 1: Analyze
- [ ] Step 2: Create mapping
- [ ] Step 3: Validate
- [ ] Step 4: Execute
```

**Validation Loops:**
1. Do the work
2. Run validation
3. Fix any issues
4. Repeat until validation passes

---

## Part 3: Optimizing Skill Descriptions

### Core Writing Principles

1. **Use imperative phrasing** — "Use this skill when..." rather than "This skill does..."
2. **Focus on user intent, not implementation** — Describe what the user is trying to achieve
3. **Err on the side of being pushy** — Explicitly list contexts where the skill applies
4. **Keep it concise** — A few sentences to a short paragraph; max 1024 characters

### Testing & Evaluation

5. **Design trigger eval queries** — Create ~20 realistic prompts (8-10 should-trigger, 8-10 should-not-trigger)
6. **Vary should-trigger queries** along multiple axes:
   - Phrasing: formal, casual, typos, abbreviations
   - Explicitness: some name the domain, others describe the need
   - Detail: mix terse prompts with context-heavy ones
   - Complexity: single-step tasks alongside multi-step workflows
7. **Create strong should-not-trigger queries** — Use near-misses that share keywords but need something different
8. **Run each query multiple times** — Model behavior is nondeterministic; run 3 times
9. **Use train/validation splits** — ~60% train / ~40% validation

### The Optimization Loop

10. **Evaluate on both sets** — Train results guide changes; validation tells if changes generalize
11. **Identify failures in train set only** — Keep validation results hidden during iteration
12. **Revise strategically:**
    - Should-trigger failing → broaden scope or add context
    - Should-not-trigger false-triggering → add specificity about what the skill does *not* do
    - Avoid adding specific keywords from failed queries (that's overfitting)
13. **Select best iteration by validation pass rate**
14. **Check the 1024-character limit**

---

## Part 4: Evaluating Skill Output Quality

### Designing Test Cases

Store in `evals/evals.json`:
```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": [],
      "assertions": ["The output includes X"]
    }
  ]
}
```

### Running Evals

Run each test case **twice**: once with the skill, once without.

**Workspace structure:**
```
<skill-name>-workspace/
└── iteration-1/
    ├── eval-0/
    │   ├── with_skill/outputs/
    │   ├── without_skill/outputs/
    │   └── eval_metadata.json
    └── timing.json
```

### Writing Assertions

Verifiable statements about output:
- Must be programmatically verifiable or observable
- Examples: "The output file is valid JSON", "The chart has labeled axes"
- Avoid vague assertions like "The output is good"

### Grading Outputs

- Evaluate each assertion against actual outputs
- Record **PASS** or **FAIL** with concrete evidence
- Use LLMs for subjective checks, scripts for mechanical checks

### Aggregating Results

Compute in `benchmark.json`:
- Pass rate (mean, stddev)
- Time in seconds (mean, stddev)
- Tokens (mean, stddev)
- Delta between with/without skill

### Analyzing Patterns

- Remove assertions that always pass in both configurations
- Investigate assertions that always fail in both configurations
- Study assertions that pass with skill but fail without
- Check for inconsistent results (high stddev)

### Human Review

- Human reviewer catches issues not covered by assertions
- Record specific feedback in `feedback.json`
- Focus improvements on test cases with specific complaints

---

## Part 5: Creating Test Cases

After writing the draft, create realistic test prompts:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": [],
      "assertions": ["The output includes X"]
    }
  ]
}
```

### Test Case Guidelines

- **Realism**: Add file paths, personal context, specific details, casual language
- **Variety**: Mix formal/casual, terse/context-heavy, single-step/multi-step
- **Near-misses**: Include queries that share keywords but need something different

---

## Part 6: Description Optimization

After the skill is working well, optimize the frontmatter:

1. **Generate eval queries** - 20 queries (8-10 should-trigger, 8-10 should-not-trigger)
2. **Run optimization loop**:
```bash
python -m scripts.run_loop \
  --eval-set <path/to/queries.json> \
  --skill-path <path/to/skill> \
  --model <current-model> \
  --max-iterations 5 \
  --verbose
```
3. **Apply best description** - Update SKILL.md frontmatter

---

## Reference Files

- `references/schemas.md` - JSON structures for evals.json, grading.json
- `references/output-patterns.md` - Common output patterns
- `references/workflows.md` - Common workflow patterns

## Packaging

```bash
python -m scripts.package_skill <path/to/skill-folder>
```

Creates a .skill file for distribution.