# Shields.io Badge Reference

Complete catalog of shields.io badges for GitHub README files (2026).

## Badge syntax

```markdown
![Label](https://img.shields.io/badge/label-message-color?logo=logoname&logoColor=white)
```

Dynamic badge:
```markdown
![CI](https://github.com/OWNER/REPO/actions/workflows/WORKFLOW.yml/badge.svg)
```

Linked badge (recommended — always wrap badges in links):
```markdown
[![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/REPO/actions)
```

---

## Required badges

### CI/CD Status (GitHub Actions)
```markdown
[![CI](https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/REPO/actions)
```

### Latest Release
```markdown
[![Release](https://img.shields.io/github/v/release/OWNER/REPO?color=6366f1&label=release)](https://github.com/OWNER/REPO/releases)
```

### License: MIT
```markdown
[![License: MIT](https://img.shields.io/badge/license-MIT-06b6d4.svg)](LICENSE)
```

### License: Apache-2.0
```markdown
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
```

---

## Language & framework badges

### Python
```markdown
[![Python](https://img.shields.io/badge/python-3.11%2B-3776ab?logo=python&logoColor=white)](https://www.python.org/)
```

### Rust
```markdown
[![Rust](https://img.shields.io/badge/rust-stable-f74c00?logo=rust&logoColor=white)](https://www.rust-lang.org/)
```

### TypeScript
```markdown
[![TypeScript](https://img.shields.io/badge/typescript-5.x-3178c6?logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
```

### Next.js
```markdown
[![Next.js](https://img.shields.io/badge/Next.js-15-black?logo=next.js)](https://nextjs.org/)
```

### Node.js
```markdown
[![Node.js](https://img.shields.io/badge/node.js-20%2B-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
```

### Go
```markdown
[![Go](https://img.shields.io/badge/go-1.22%2B-00add8?logo=go&logoColor=white)](https://go.dev/)
```

---

## Deployment badges

### Vercel
```markdown
[![Vercel](https://img.shields.io/badge/demo-live-00c7b7?logo=vercel)](https://YOUR-DEPLOYMENT.vercel.app/)
```

### Netlify
```markdown
[![Netlify](https://img.shields.io/badge/demo-live-00c7b7?logo=netlify)](https://YOUR-DEPLOYMENT.netlify.app/)
```

### Docker Hub
```markdown
[![Docker](https://img.shields.io/docker/pulls/OWNER/IMAGE?logo=docker)](https://hub.docker.com/r/OWNER/IMAGE)
```

---

## Code quality badges

### Code Coverage (Codecov)
```markdown
[![Coverage](https://img.shields.io/codecov/c/github/OWNER/REPO?logo=codecov)](https://codecov.io/gh/OWNER/REPO)
```

### Code Coverage (Coveralls)
```markdown
[![Coverage](https://coveralls.io/repos/github/OWNER/REPO/badge.svg?branch=main)](https://coveralls.io/github/OWNER/REPO)
```

---

## Community badges

### PRs Welcome
```markdown
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
```

### GitHub Stars
```markdown
[![Stars](https://img.shields.io/github/stars/OWNER/REPO?style=flat&color=yellow)](https://github.com/OWNER/REPO/stargazers)
```

### GitHub Issues
```markdown
[![Issues](https://img.shields.io/github/issues/OWNER/REPO)](https://github.com/OWNER/REPO/issues)
```

---

## Badge design guidelines (2026)

| Rule | Detail |
|---|---|
| **Max count** | 6-8 badges — more becomes visual noise |
| **Always link** | Wrap every badge in `[![...](img)](url)` |
| **Grouping order** | Status \| Languages \| Deployment \| Community |
| **Accent colors** | Use project palette for version/release badges |
| **Style** | Default `flat` is fine; `flat-square` for minimalist look |
| **Placement** | All badges in `<div align="center">` header block, one line |
| **No broken badges** | Verify every badge URL before committing |
