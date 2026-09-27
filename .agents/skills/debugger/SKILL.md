---
name: debugger
version: "0.1.0"
category: code-quality
description: Diagnose failing builds and runtime errors with root-cause discipline. Use when a build breaks, a service crashes, or an error appears at runtime — even if they just say "why is this failing" or "debug this crash". Not for test-runner (failing tests), security-code-auditor (vulns).
license: MIT
---

# Debugger

Root-cause diagnosis for failing builds and runtime errors. Symptoms first,
theories second, fixes last.

## When to Use

- Build, deploy, or CI pipeline fails
- Runtime crash, panic, exception, or hang
- Error output that is cryptic or misleading
- Even if they just say "why is this failing" or "debug this"

## Steps

1. **Read the error first** — full output, not the last line. Note exit
   codes, file:line locations, and the first failure (later ones cascade).
2. **Reproduce minimally** — smallest command or input that triggers it.
   If it only fails in CI, diff the environments (versions, env vars, cwd).
3. **Form one hypothesis** — state the suspected cause before changing code.
4. **Bisect** — halve the search space (recent commits, config halves,
   feature flags) until the trigger commit or line is isolated.
5. **Fix at the root** — patch the cause, not the symptom; add the minimal
   reproducer as a regression test.
6. **Verify** — rerun the reproducer plus the surrounding suite green.

## Common Traps

- Fixing the second error in the log while the first (causal) one remains.
- "Works on my machine" without diffing dependency or environment versions.
- Treating flaky as fixed after one green run — rerun at least 3 times.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The error message says what's wrong, just fix that line" | Error text reports where it surfaced, not where it started; trace to the cause. |
| "I'll just retry, it was probably flaky" | Uninvestigated flakes become incidents; reproduce or explicitly classify with evidence. |

## Red Flags

- [ ] Changing code before stating a hypothesis
- [ ] Closing as flaky without rerun evidence or a tracking issue
- [ ] Fix without a regression test

## See Also

- `test-runner` — Execute tests and diagnose test failures
- `iterative-refinement` — Validation loops until criteria are met

## References

- `evals/evals.json` — diagnostic cases incl. misleading-error negative
