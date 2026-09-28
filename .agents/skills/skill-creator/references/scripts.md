# Skill Creator Scripts

CLI reference for the helper modules bundled with this skill. Run every command
from the skill root (the directory holding `SKILL.md`).

## Initialize a New Skill

```bash
python -m scripts.init_skill \
  --skill-name my-skill \
  --description "Do X. Use when Y."
```

Creates full directory structure, SKILL.md template, evals/evals.json with 3 placeholder cases, scripts/example.py, and references/guide.md.

## Package for Distribution

```bash
python -m scripts.package_skill <path/to/skill-folder> [--output out.skill] [--force]
```

Validates structure (SKILL.md, evals/evals.json) and creates a `.skill` tar.gz archive.

## Aggregate Benchmark Results

```bash
python -m scripts.aggregate_benchmark <workspace-path> [--iteration N]
```

Reads all grading.json and timing.json, computes pass_rate/time/tokens stats per config, outputs `benchmark.json` and `benchmark.md`.

## Optimize Description

```bash
python -m scripts.run_loop \
  --eval-set <queries.json> \
  --skill-path <path/to/skill> \
  --model <model> \
  --max-iterations 5 \
  --verbose
```

Splits eval set 60/40 train/validation, iteratively evaluates and proposes description improvements, outputs best description by validation score.

## Generate Review Page

```bash
python eval-viewer/generate_review.py \
  --workspace <workspace-path> \
  --skill-name <name> \
  --static <output.html>
```

Generates standalone HTML with Outputs and Benchmark tabs for human review.
