# API Contracts

This directory contains the machine-readable agreements between different parts of the system.

## Structure

- `pacts/`: Contains [Pact](https://pact.io) contract files (JSON). These define the interactions between API consumers and providers.
- `schemas/`: Contains JSON Schemas for non-HTTP boundaries, such as CLI tool outputs or internal skill data shapes.

## Why Contract Testing?

Contract testing ensures that a change in one service (the Provider) doesn't break another service that depends on it (the Consumer). It is especially critical in AI-driven development where interfaces might be refactored autonomously.

## Workflow

1. **Consumer writes a test**: The consumer defines what it expects from the provider. Running this test generates a "pact" file.
2. **Commit the pact**: The pact file is committed to `contracts/pacts/`.
3. **Provider verifies**: The provider runs its tests against the pact file to ensure it meets the consumer's expectations.

For a detailed guide, see `agents-docs/CONTRACT-TESTING.md`.
