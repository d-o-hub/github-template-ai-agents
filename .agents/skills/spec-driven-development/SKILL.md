---
name: spec-driven-development
description: Write a structured specification (SPEC.md) before any code. Triggers on "new feature", "start project", "redesign", or when scope is unclear.
category: workflow
version: "1.0"
template_version: "0.3"
---

# Spec-Driven Development

SPECIFY phase: Define the what and why before the how.

## When to Use
- Starting a new feature, project, or significant change
- When requirements are vague or contradictory
- Before any implementation begins

## Instructions
1. **Clarify Objectives**: Ask the user for the primary goal, target users, and success criteria.
2. **Draft SPEC.md**: Create a `SPEC.md` file in the project root covering:
   - **Objective**: What are we building and why?
   - **Requirements**: Functional and non-functional.
   - **Out of Scope**: What are we NOT doing?
   - **Tech Stack**: Languages, frameworks, and tools.
   - **User Flow/API**: How does it work for the user?
3. **Seek Approval**: Present the `SPEC.md` to the human and wait for explicit approval.
4. **Iterate**: Update `SPEC.md` based on feedback until approved.

## Rationalizations
| Rationalization | Reality |
|-----------------|---------|
| "It's a small change, I don't need a spec." | Small changes often have hidden complexity. |
| "I'll update the spec as I go." | That's not a spec; that's documentation of what you happened to do. |
| "The user already told me what they want." | Writing it down reveals gaps in understanding. |

## Red Flags
- [ ] Starting code before `SPEC.md` is approved
- [ ] Vague "requirements" that aren't testable
- [ ] Ignoring the "Out of Scope" section

## Verification
- [ ] `SPEC.md` exists in the project root
- [ ] `SPEC.md` contains all required sections
- [ ] Human has explicitly approved `SPEC.md` in the chat
