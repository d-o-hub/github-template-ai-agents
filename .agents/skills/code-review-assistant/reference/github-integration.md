# GitHub Integration Guide

GitHub API integration for the Code Review Assistant skill.

## Overview

This guide covers how to integrate the code-review-assistant skill with GitHub for automated PR reviews, comments, and approvals.

## API Usage

### Authentication

The skill uses GitHub's REST API via the `gh` CLI or direct API calls:

```bash
# Using gh CLI (recommended)
gh pr view <pr-number> --json number,title,body,files

# Using GitHub API directly
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER
```

### Required Permissions

- `pull_requests:read` - View PR details and diffs
- `pull_requests:write` - Add review comments
- `contents:read` - Access file contents
- `checks:read` - View CI check status

## Auto-Approval Criteria

Configure when the assistant can automatically approve PRs:

```yaml
auto_approve:
  max_files: 5
  max_lines_changed: 100
  no_critical_paths: true
  tests_passing: true
  no_security_issues: true
  min_reviewers: 0
```

### Safety Rules

Never auto-approve PRs that:
- Modify security-related files (auth, crypto, payment)
- Have failing CI checks
- Are marked as "WIP" or "Draft"
- Change more than 500 lines
- Touch database migrations

## Webhook Setup

### GitHub App Configuration

1. Create a GitHub App in your organization settings
2. Subscribe to these events:
   - `pull_request.opened`
   - `pull_request.synchronize`
   - `pull_request.reopened`

3. Set permissions:
   - Pull requests: Read & Write
   - Contents: Read
   - Checks: Read
   - Issues: Write (for review comments)

### Webhook Handler

```python
# Example webhook handler
@app.route('/webhook', methods=['POST'])
def handle_webhook():
    event = request.headers.get('X-GitHub-Event')
    payload = request.json
    
    if event == 'pull_request':
        action = payload['action']
        if action in ['opened', 'synchronize']:
            run_code_review(payload['pull_request'])
    
    return '', 204
```

## Review Comment API

### Adding Review Comments

```bash
# Create a review with comments
gh api repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews \
  -f event='COMMENT' \
  -f body='Automated review summary' \
  -F 'comments[][path]=file.js' \
  -F 'comments[][position]=1' \
  -F 'comments[][body]=Issue description'
```

### Comment Positioning

Comments use GitHub's positioning system:
- `position`: Line number in the diff (not the file)
- `path`: File path relative to repo root
- `commit_id`: SHA of the commit being reviewed

## CI Integration

### GitHub Actions Workflow

```yaml
name: Automated Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Run Code Review Assistant
        uses: ./.github/actions/code-review
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          config: .github/code-review-config.yml
```

### Configuration File

```yaml
# .github/code-review-config.yml
risk_levels:
  critical:
    - '**/auth/**'
    - '**/security/**'
    - '**/payment/**'
  
  high:
    - '**/api/**'
    - '**/models/**'

auto_approve:
  enabled: true
  max_files: 5
  max_lines: 100

checks:
  style: true
  security: true
  tests: true
```

## Best Practices

1. **Rate Limiting**: GitHub API has rate limits. Cache results when possible.
2. **Error Handling**: Always handle API failures gracefully.
3. **Token Security**: Store tokens in GitHub Secrets, never in code.
4. **Comment Quality**: Ensure automated comments are actionable and specific.
5. **Human Review**: Auto-approval should be opt-in per repository.

## Troubleshooting

### Common Issues

**Token permissions**: Verify the token has required scopes.
**Rate limiting**: Add delays between API calls for large PRs.
**Comment positioning**: Use `commit_id` to ensure comments land on the right commit.

### Debug Mode

Enable verbose logging:
```bash
export GITHUB_DEBUG=1
export CODE_REVIEW_DEBUG=1
```
