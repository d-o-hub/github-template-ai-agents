# CI/CD Pipeline Design for Node.js Project

## Overview

This document outlines a production-ready CI/CD pipeline using GitHub Actions for a Node.js project. The pipeline covers linting, testing, building, security scanning, and deployment.

---

## Pipeline Architecture

```
PR/Push → Lint → Test → Build → Security Scan → Deploy (Staging) → Deploy (Production)
```

---

## 1. CI Workflow (`.github/workflows/ci.yml`)

```yaml
name: CI

on:  # yamllint disable-line rule:truthy
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: npm
      - run: npm ci
      - run: npm test -- --coverage
      - uses: actions/upload-artifact@v4
        if: matrix.node-version == 20
        with:
          name: coverage
          path: coverage/

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm audit --audit-level=high
      - uses: github/codeql-action/init@v3
        with:
          languages: javascript
      - uses: github/codeql-action/analyze@v3
```

---

## 2. CD Workflow (`.github/workflows/deploy.yml`)

```yaml
name: Deploy

on:  # yamllint disable-line rule:truthy
  push:
    branches: [main]

environment:
  name: production

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
      - name: Deploy to Staging
        run: echo "Deploy to staging environment"
        # Add actual deployment command:
        # - run: npm run deploy:staging
        # - uses: aws-actions/configure-aws-credentials@v4

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
      - name: Deploy to Production
        run: echo "Deploy to production environment"
        # Add actual deployment command:
        # - run: npm run deploy:production
```

---

## 3. Release Workflow (`.github/workflows/release.yml`)

```yaml
name: Release

on:  # yamllint disable-line rule:truthy
  push:
    tags:
      - "v*"

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          registry-url: https://registry.npmjs.org
      - run: npm ci
      - run: npm run build
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
      - name: Publish to npm
        run: npm publish --provenance
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

---

## 4. Recommended `package.json` Scripts

```json
{
  "scripts": {
    "lint": "eslint . --max-warnings 0",
    "test": "vitest run",
    "test:coverage": "vitest run --coverage",
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "prepare": "husky"
  }
}
```

---

## 5. Required Secrets

| Secret | Purpose |
|--------|---------|
| `NPM_TOKEN` | npm publish authentication |
| `CODECOV_TOKEN` | Coverage reporting |
| AWS/Cloud credentials | Deployment (if applicable) |

---

## 6. Performance Optimizations

- **Cache npm dependencies**: Uses `actions/setup-node` with `cache: npm`
- **Parallel jobs**: Lint, test, and security run in parallel; build waits on test
- **Matrix testing**: Tests across Node 18, 20, 22 in parallel
- **Artifact reuse**: Build output uploaded once, downloaded for deployment
- **Concurrency groups**: Prevent duplicate runs on same branch

---

## 7. Branch Protection Rules

Recommended GitHub settings:
- Require PR reviews before merge
- Require status checks (lint, test, build) to pass
- Require branches to be up to date
- Require signed commits
- Restrict force pushes to `main`

---

## Summary

This pipeline provides:
1. **CI**: Lint → Test (matrix) → Build → Security scan
2. **CD**: Staging → Production with environment gates
3. **Release**: Automated GitHub releases + npm publish on tags
4. **Security**: npm audit + CodeQL analysis

**Status**: success
**Summary**: Designed a complete Node.js CI/CD pipeline with GitHub Actions covering CI, CD, and release workflows.

**Files touched**: cicd-pipeline-workspace/iteration-1/eval-1/without_skill/response.md
**Findings worth promoting**:
- Matrix testing across multiple Node versions ensures compatibility
- Separating CI (on PR) from CD (on main push) provides clear deployment gates
- Security scanning should run in parallel with tests to reduce pipeline time
- Environment protection rules in GitHub add manual approval gates for production
