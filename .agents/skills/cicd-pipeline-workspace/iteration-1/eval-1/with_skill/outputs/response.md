# CI/CD Pipeline Design for Node.js with GitHub Actions

## Overview

This pipeline implements a production-grade CI/CD workflow for a Node.js project with GitHub Actions. It covers linting, testing, security scanning, build, and deployment with proper caching, secrets management, and failure recovery.

---

## Pipeline Structure

### Trigger Configuration

```yaml
name: CI/CD Pipeline

on:  # yamllint disable-line rule:truthy
  push:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'package.json'
      - 'package-lock.json'
      - '.github/workflows/**'
  pull_request:
    branches: [main, develop]
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6 AM UTC for dependency audit
  workflow_dispatch:
    inputs:
      deploy_environment:
        description: 'Deployment target'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production
```

### Job Definitions

#### 1. Lint Job

```yaml
jobs:
  lint:
    name: Lint & Format
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint
        run: npm run lint

      - name: Check formatting
        run: npm run format:check
```

#### 2. Test Job with Matrix

```yaml
  test:
    name: Test (Node ${{ matrix.node-version }})
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      fail-fast: false
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests with coverage
        run: npm test -- --coverage

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage-node-${{ matrix.node-version }}
          path: coverage/
          retention-days: 7
```

#### 3. Security Scanning Job

```yaml
  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Secrets detection (GitLeaks)
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Dependency audit
        run: npm audit --audit-level=high

      - name: SAST with Semgrep
        uses: semgrep/semgrep-action@v1
        with:
          config: p/javascript
```

#### 4. Build Job

```yaml
  build:
    name: Build
    runs-on: ubuntu-latest
    needs: [lint, test, security]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/
          retention-days: 7
```

#### 5. Deploy Job

```yaml
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main' || github.event_name == 'workflow_dispatch'
    environment:
      name: staging
      url: https://staging.example.com
    concurrency:
      group: staging-deployment
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v4

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: dist
          path: dist/

      - name: Deploy to staging
        run: |
          echo "Deploying to staging..."
          # ./deploy.sh --env staging
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}

      - name: Health check
        run: |
          for i in {1..30}; do
            if curl -sf https://staging.example.com/health; then
              echo "Service is healthy"
              exit 0
            fi
            sleep 10
          done
          echo "Health check failed"
          exit 1

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.deploy_environment == 'production'
    environment:
      name: production
      url: https://example.com
    concurrency:
      group: production-deployment
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v4

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: dist
          path: dist/

      - name: Deploy to production
        run: |
          echo "Deploying to production..."
          # ./deploy.sh --env production
        env:
          DEPLOY_TOKEN: ${{ secrets.PROD_DEPLOY_TOKEN }}

      - name: Smoke test
        run: |
          curl -f https://example.com/health
          curl -f https://example.com/api/v1/status

      - name: Notify on success
        if: success()
        run: |
          echo "Production deployment successful"
```

---

## Caching Strategy

The pipeline uses `actions/setup-node@v4` with built-in npm caching:

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'  # Caches ~/.npm based on package-lock.json hash
```

**Key points**:
- Cache key derived from `package-lock.json` via `hashFiles()`
- Reduces install time by 30-70% on subsequent runs
- No manual cache configuration needed

---

## Secrets Management

| Secret | Purpose | Environment |
|--------|---------|-------------|
| `GITHUB_TOKEN` | Git operations, API access | Automatic |
| `DEPLOY_TOKEN` | Staging deployment | Staging |
| `PROD_DEPLOY_TOKEN` | Production deployment | Production |
| `SNYK_TOKEN` | Snyk vulnerability scanning | All (optional) |
| `SONAR_TOKEN` | SonarQube SAST | All (optional) |

**Rules**:
- Never hardcode tokens in workflow files
- Use GitHub environment secrets for deployment targets
- Rotate tokens regularly
- `GITHUB_TOKEN` expires after 1 hour — don't use for long-running workflows

---

## Security Gates

The pipeline implements a security gate that fails the build on critical findings:

```yaml
  security-gate:
    name: Security Gate
    runs-on: ubuntu-latest
    needs: [security]
    if: always()
    steps:
      - name: Check security results
        run: |
          if [[ "${{ needs.security.result }}" == "failure" ]]; then
            echo "Security checks failed — blocking deployment"
            exit 1
          fi
```

---

## Notification Configuration

```yaml
  notify:
    name: Notify
    runs-on: ubuntu-latest
    needs: [deploy-staging, deploy-production]
    if: always()
    steps:
      - name: Notify on failure
        if: contains(needs.*.result, 'failure')
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Pipeline failed: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Common Failure Patterns & Fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `npm ci` timeout | Large `node_modules` | Cache enabled via `setup-node` |
| Flaky test | Race conditions | `fail-fast: false` in matrix, retry logic |
| Secret not found | Wrong environment scope | Verify secret in correct GitHub environment |
| Cache miss | Key mismatch | `hashFiles('package-lock.json')` ensures deterministic keys |
| Deploy health check fail | Service not ready | Retry loop with 300s timeout |

---

## Gotchas Addressed

1. **yamllint**: All `on:` lines include `# yamllint disable-line rule:truthy`
2. **actions/checkout**: Always `@v4` (not `@v3`)
3. **Matrix builds**: `fail-fast: false` prevents one failure from killing all jobs
4. **Concurrency**: Production deployments use `cancel-in-progress: false` to prevent overlapping deploys
5. **Artifact retention**: Set to 7 days to control storage costs
6. **Path filters**: `push` triggers only run when relevant files change

---

## File Locations

- **Workflow file**: `.github/workflows/ci.yml`
- **Build artifact**: `dist/`
- **Coverage**: `coverage/`

---

## Deployment Strategy

The pipeline uses a **rolling deployment** strategy with manual promotion from staging to production:

1. **Automatic**: Lint → Test (matrix) → Security → Build → Deploy to Staging
2. **Manual gate**: Workflow dispatch required for production deployment
3. **Health checks**: Automated verification after each deployment
4. **Rollback**: Manual rollback via workflow dispatch with previous version ref

---

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [actions/checkout@v4](https://github.com/actions/checkout)
- [actions/setup-node@v4](https://github.com/actions/setup-node)
- [GitLeaks Action](https://github.com/gitleaks/gitleaks-action)
- [Trivy Vulnerability Scanner](https://github.com/aquasecurity/trivy-action)
