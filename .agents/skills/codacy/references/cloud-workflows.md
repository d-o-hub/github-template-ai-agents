# Common workflows

**Check critical security issues in a repo:**

```bash
codacy findings gh my-org my-repo --severities Critical,High

```

**Review what a PR introduced:**

```bash
codacy pull-request gh my-org my-repo 42
codacy pull-request gh my-org my-repo 42 --diff

```

**Understand a specific issue:**

```bash
codacy issue gh my-org my-repo <issueId>   # includes pattern docs and code context

```

**Trigger reanalysis and wait for results:**

```bash
codacy repository gh my-org my-repo --reanalyze-and-wait
codacy repository gh my-org my-repo -w -o json    # JSON delta report with issue changes by pattern/severity/category

```

**Identify and reduce noise:**

```bash
codacy issues gh my-org my-repo --overview        # see false positive counts and suggested actions to reduce noise

```
