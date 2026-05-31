# README Section Templates

Copy-paste templates for every section of a 2026 best-practice GitHub README.

---

## 1. Header block

```markdown
<div align="center">

<img src="assets/logo.svg" alt="PROJECT-NAME logo" width="320"/>

# project-name

**Short tagline in bold** — one sentence describing what it does.
Secondary sentence: key differentiator or zero-config benefit.

[![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/REPO/actions)
[![Release](https://img.shields.io/github/v/release/OWNER/REPO?color=6366f1&label=release)](https://github.com/OWNER/REPO/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-06b6d4.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11%2B-3776ab?logo=python&logoColor=white)](https://www.python.org/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

[**Live Demo**](https://demo.example.com) · [**Documentation**](docs/) · [**Report Bug**](../../issues) · [**Request Feature**](../../issues)

</div>

---
```

---

## 2. Why section

```markdown
## Why project-name?

- **Zero-key mode**: Works out of the box — no API keys or credentials required to get started
- **Self-healing**: Circuit breakers and per-domain routing memory recover from failures automatically
- **LLM-optimized output**: Compact, deduplicated Markdown ready for direct injection into prompts
- **Three interfaces**: Python library, Rust CLI, and Next.js Web UI — one core, any workflow

---
```

---

## 3. Table of Contents (for READMEs > 100 lines)

```markdown
## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Testing](#testing)
- [Repository Structure](#repository-structure)
- [Contributing](#contributing)
- [License](#license)

---
```

---

## 4. Quick Start

```markdown
## Quick Start

```bash
# Clone and install (no API keys needed)
git clone https://github.com/OWNER/REPO.git
cd REPO
pip install -r requirements.txt

# Resolve a URL
python -m scripts.resolve "https://docs.example.com"

# Resolve a search query (uses free providers)
python -m scripts.resolve "your search query"
```

Or try the **[live demo →](https://demo.example.com)**

---

```

---

## 5. Architecture (ASCII cascade diagram)

```markdown
## Architecture

### Resolution Cascade

```

Input
  │
  ▼
┌────────────────────────────────────────────────┐
│ 1. Semantic Cache             (free, instant)  │
├────────────────────────────────────────────────┤
│ 2. Provider A                 (free)           │
├────────────────────────────────────────────────┤
│ 3. Provider B                 (API_KEY required)│
├────────────────────────────────────────────────┤
│ N. Fallback                   (free)           │
└────────────────────────────────────────────────┘

```
```

---

## 6. Features table

```markdown
## Features

| Feature | Description |
|---|---|
| **Feature A** | One sentence description |
| **Feature B** | One sentence description |
| **Feature C** | One sentence description |

---
```

---

## 7. Installation

```markdown
## Installation

### Primary interface

```bash
git clone https://github.com/OWNER/REPO.git
cd REPO
pip install -r requirements.txt
```

### Secondary interface (e.g. CLI)

```bash
cd cli && cargo build --release
# Binary at: cli/target/release/tool-name
```

### Web UI

```bash
cd web && npm install && npm run dev
# Open http://localhost:3000
```

```

---

## 8. Configuration

```markdown
## Configuration

All API keys are **optional**. The tool works with zero configuration using free providers.

| Variable | Provider | Required | Notes |
|---|---|---|---|
| `PROVIDER_API_KEY` | Provider Name | No | Enables X feature |
| `OTHER_API_KEY` | Other Name | No | Enables Y feature |

```bash
# Linux/macOS
export PROVIDER_API_KEY="your-key"

# Windows PowerShell
$env:PROVIDER_API_KEY="your-key"
```

```

---

## 9. Repository Structure

```markdown
## Repository Structure

```

repo-name/
├── README.md             # This file
├── CONTRIBUTING.md       # Contribution guidelines
├── LICENSE               # MIT license
├── src/                  # Source code
│   └── main.py             # Entry point
├── tests/                # Test suite
├── scripts/              # Helper scripts
├── assets/               # Logo and screenshots
└── .github/workflows/    # CI/CD pipelines

```
```

---

## 10. Contributing

```markdown
## Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Add tests for new functionality
4. Run the quality gate: `./scripts/quality_gate.sh`
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.
```

---

## 11. License

```markdown
## License

MIT License — see [LICENSE](LICENSE) for details.
```
