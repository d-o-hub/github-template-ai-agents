# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Executable-invariants registry `plans/invariants.json` and canonical checker `scripts/check-invariants.sh` integrated into ADR compliance gate.
- Opt-in paired behavioral evaluation runner (`scripts/behavioral-eval.py`) with a versioned adapter contract, redacted machine-readable artifacts, a `workflow_dispatch`-only workflow, and an explicit reviewed baseline-blessing path. Default quality gates remain offline and credential-free.
