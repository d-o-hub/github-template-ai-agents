# AI Agents Overview

This document serves as an index and general guide for all AI agent specifications within this repository.
All agents must adhere to the core principles defined in the root [`AGENTS.md`](../AGENTS.md).

## Core Concepts

Agents in this project operate on a shared mental model of self-learning and coordination:

- **Episode**: One unit of work an agent performs (e.g., a PR review, a feature implementation).
- **Reward**: How the "goodness" of an episode is judged (e.g., CI passing, performance improved).
- **Reflection**: A brief summary written by the agent detailing what worked, what didn't, and what to change.
- **Escalation**: Knowing when to explicitly hand off tasks to another agent or a human developer (e.g., blocked, security constraints).
- **Skill Evolution**: The capability of an agent to update its own guidelines or prompt strategies based on reflections.

## Agent Specifications

To maintain consistency, individual agent specification files (e.g., in `agents-docs/`) should follow this standard structure:

- **Purpose**: What this agent is for.
- **Inputs**: Which files/folders it must read (e.g., source code, plans, logs).
- **Outputs**: Expected artifacts (e.g., PR comments, code changes, documentation).
- **Memory Behavior**:
  - What constitutes an "episode" for this agent.
  - How to score/reward episodes.
  - When and where to write reflections.
- **Constraints**: Strict boundaries the agent must never cross without human approval (e.g., touching secrets, deployments).

## Project State Coordination

Agents coordinate using shared state surfaces:
- **Planning Surface** (e.g., `PLANS.md` or `plans/`): Read goals and pending tasks here before acting.
- **Progress Surface** (e.g., `PROGRESS.md` or `progress/`): Write completed work, outcomes, and reflections here after acting.

## Available Agent Roles

*(Note: Create specific `.md` files in this directory for distinct roles as they evolve)*
- [General AI Assistant](../AGENTS.md) - The default configuration.
