---
name: pact-contract-testing
description: Write and verify API contracts using Pact. Use when adding/modifying API boundaries, preventing breaking changes between services, or ensuring AI-generated refactors don't break downstream consumers.
version: "1.0"
template_version: "0.2"
license: MIT
---

# Pact Contract Testing

Validate agreements between producers and consumers of APIs to prevent silent breaks.

## When to Use This Skill
- User asks to "write a contract test" or "ensure API compatibility"
- User mentions "Pact", "consumer-driven testing", or "breaking changes"
- You are modifying an API endpoint shape, schema, or path

## Core Workflow

### 1. Consumer: Define Expectations
Write a consumer test in the consumer's language. This test uses a Pact mock server to record the expected interactions.
- **Output**: A Pact JSON file (e.g., `contracts/pacts/myconsumer-myprovider.json`)
- **Rule**: NEVER modify this JSON manually. Always regenerate it via the consumer test.

### 2. Commit Pact
Add the generated Pact file to `contracts/pacts/` and commit it to git.

### 3. Provider: Verify Compliance
Run a provider verification test. The Pact verifier will:
1. Replay the requests from the Pact file against the actual provider service.
2. Compare the actual response with the expected response in the Pact.
3. Fail if there's a mismatch (e.g., missing field, wrong type, different status code).

## Language-Specific Commands

- **Rust**: `cargo test --features pact`
- **TypeScript/JS**: `npm test -- pact.spec.ts`
- **C#/.NET**: `dotnet test PactTests`
- **Python**: `pytest tests/pact_tests.py`

## Critical Rules
- **No Manual Edits**: Pact files are artifacts of consumer tests. Manual changes will be overwritten.
- **Backward Compatibility**: Never remove a field or change a type without a formal deprecation period.
- **Verify Before Merge**: Always run provider verification scripts before merging a change to a Pact file.

## References
- `references/pact-quickstart-rust.md` - Rust consumer example
- `references/pact-quickstart-typescript.md` - TypeScript consumer example
- `references/pact-quickstart-csharp.md` - C# consumer example
- `references/pact-quickstart-cpp.md` - C++ consumer example
- `references/pact-cli-reference.md` - CLI usage for mock servers and verifiers
