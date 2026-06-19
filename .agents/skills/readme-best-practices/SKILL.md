---
name: readme-best-practices
version: "0.2.10"
category: documentation
description: >
  Create, audit, and improve GitHub README.md files following 2026 best practices.
  Use this skill when a user asks to write, rewrite, or review a README.md for a
  GitHub repository, add shields.io badges, create a project SVG logo, improve
  documentation structure, or make a repository more discoverable and professional
  — even if they just say "write the README" or "make the repo look professional". Not for agents-md, architecture-diagram.
license: MIT
compatibility: Requires access to the repository file tree. Works with Claude Code, OpenCode, and similar agents. Network access recommended for shields.io badge validation.
metadata:
  author: d-oit
  version: "1.0"
  tags: readme documentation github badges svg-logo markdown
---

# README Best Practices (2026)

This skill guides you through creating a best-practice GitHub README.md for 2026,
including a custom SVG logo and shields.io badges.

## When to Use

- User asks to "write a README", "improve README", "add badges", or "create a logo"
- User asks to analyze or audit an existing README.md
- User wants to make a repository more professional or discoverable
- User asks about GitHub documentation best practices

## Step-by-step workflow

### 1. Analyze the repository

Before writing anything, gather context:

```bash
# Detect tech stack
cat package.json 2>/dev/null | head -20
cat Cargo.toml 2>/dev/null | head -20
cat pyproject.toml 2>/dev/null | head -20
ls -1
find . -name "*.md" -maxdepth 2
```

Identify:
- Primary language(s) and tech stack
- What the project does (one sentence)
- Key features (5-10 bullet points)
- Installation method(s)
- Whether a live demo/deployment exists
- License type
- CI/CD system (GitHub Actions workflows)
- Existing screenshots or assets

### 2. Create the SVG logo

See [references/LOGO.md](references/LOGO.md) for the full logo creation guide.

**Quick pattern:**
- ViewBox: `0 0 320 80` at `width="320"`
- Dark background pill (`#0f172a` to `#1e293b` gradient, `rx="14"`)
- Domain-specific icon on the left
- Project acronym in indigo→cyan gradient (`#6366f1` to `#06b6d4`)
- Thin divider line below acronym
- Full project name as subtitle (`#94a3b8`)
- Tech stack chips on the right (colored pills)
- Save to: `assets/logo.svg`
- Reference: `<img src="assets/logo.svg" alt="..." width="320"/>` in README

Use the template at [assets/logo-template.svg](assets/logo-template.svg) as starting point.

### 3. Write README sections (in order)

Follow this exact section order:

```
1.  <div align="center"> header block
    - Logo image
    - Project title (h1)
    - One-line tagline (bold) + secondary sentence
    - Shields.io badge row (CI | Release | License | Languages | Demo)
    - Navigation links: Demo · Docs · Report Bug · Request Feature

2.  "Why [project]?" — 3-4 value-proposition bullets

3.  Table of Contents (for READMEs > 100 lines)

4.  Quick Start — copy-paste, zero-config first

5.  Architecture — ASCII or Mermaid diagram if applicable

6.  Features — table: Feature | Description

7.  Installation — per interface/language with fenced code blocks

8.  Configuration — env vars table: Variable | Required | Default | Notes

9.  Usage — per interface with realistic, runnable examples

10. Testing — unit, integration, e2e commands

11. Repository Structure — annotated tree

12. Contributing — numbered steps

13. License
```

See [references/STRUCTURE.md](references/STRUCTURE.md) for full copy-paste templates.

### 4. Add shields.io badges

See [references/BADGES.md](references/BADGES.md) for the complete badge catalog.

**Required badges (always include):**
- CI/CD status (`github/actions/workflows/ci.yml/badge.svg`)
- Latest release version (`shields.io/github/v/release/...`)
- License
- Primary language(s)

**Recommended additions:**
- Live demo (Vercel / Netlify)
- PRs Welcome
- Code coverage (if Codecov/Coveralls configured)

**Badge placement:** All in the `<div align="center">` header, on one line, max 6-8 badges.

### 5. Quality checklist

Before finalising, verify:

- [ ] Logo renders in both light and dark GitHub themes
- [ ] All badge image URLs are valid (no 404s)
- [ ] Quick Start works with zero API keys / credentials
- [ ] All fenced code blocks have a language specifier (` ```bash `, ` ```python `, etc.)
- [ ] All internal links (CONTRIBUTING.md, LICENSE, docs/) exist in the repo
- [ ] Table of Contents anchor links match actual heading text
- [ ] No broken image `src` references
- [ ] Repo name in README matches `github.com/owner/repo` exactly (no old aliases)
- [ ] README description matches the GitHub repo "About" field
- [ ] Installation section has commands for every supported interface

## Key principles

- **First 3 seconds rule**: Logo + tagline + badges must communicate value immediately
- **Zero-config first**: Always show the no-API-key usage first in Quick Start
- **Copy-paste ready**: Every code block must be directly runnable without editing
- **Consistent naming**: Use the exact repo slug throughout — never an internal alias
- **Progressive detail**: Overview → Quick Start → Full docs (do not front-load everything)
- **No lorem ipsum**: Every section must contain accurate, real information

## Common mistakes to avoid

- Using a stale project name that differs from the current repo slug
- Placing Installation before a "Why use this?" value pitch
- Missing Table of Contents on READMEs longer than 100 lines
- Broken badge URLs pointing to non-existent CI workflow files
- No language specifier on fenced code blocks
- Image paths that work locally but break on GitHub (always use paths from repo root)
- More than 8 badges (becomes noise)
- Forgetting `<div align="center">` closing tag

## See Also

- `architecture-diagram` — Project architecture diagrams
- `agents-md` — AGENTS.md best practices

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Any README is better than no README" | A bad README actively damages trust; incomplete or broken docs are worse than none. |
| "Badges are just decoration" | Badges convey CI status, version, and license at a glance — they are functional signals. |
| "I'll update the README when I have time" | Stale READMEs mislead contributors and users; update docs alongside code changes. |

## Red Flags

- [ ] README contains placeholder text or lorem ipsum
- [ ] Badge URLs point to non-existent workflow files
- [ ] Quick Start requires API keys or credentials without mention
