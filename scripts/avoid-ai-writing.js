#!/usr/bin/env node

/**
 * Avoid AI Writing CLI — Unified quality gate for AI-isms
 * Usage: avoid-ai-writing --mode detect --severity P0,P1 <file>
 */

const fs = require('fs');
const path = require('path');

// Dynamically locate the detector
const REPO_ROOT = path.resolve(__dirname, '..');
const DETECTOR_PATH = path.join(REPO_ROOT, '.agents/skills/avoid-ai-writing/detector/patterns.js');

if (!fs.existsSync(DETECTOR_PATH)) {
  console.error(`Error: Detector not found at ${DETECTOR_PATH}`);
  process.exit(1);
}

const AIDetector = require(DETECTOR_PATH);

function showHelp() {
  console.log(`
Avoid AI Writing CLI — v3.10.0

USAGE
  avoid-ai-writing [options] [file...]

OPTIONS
  --mode <detect|edit>    Operation mode (default: detect)
  --severity <P0,P1,P2>  Filter issues by severity (default: P0,P1)
  --context <docs|blog...> Context profile for strictness (default: general)
  --iterate <n>           Number of edit passes (default: 1)
  --json                  Output results in JSON format
  --help                  Show this help
  --version               Show version

SEVERITY TIERS
  P0 — Credibility killers (fails build)
  P1 — Obvious AI smell (warning)
  P2 — Stylistic polish

EXAMPLES
  avoid-ai-writing --mode detect --severity P0,P1 README.md
  avoid-ai-writing --mode edit --iterate 1 CHANGELOG.md
`);
}

async function main() {
  const args = process.argv.slice(2);
  const options = {
    mode: 'detect',
    severity: ['P0', 'P1'],
    context: 'general',
    iterate: 1,
    json: false,
    files: []
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--help' || arg === '-h') {
      showHelp();
      process.exit(0);
    } else if (arg === '--version' || arg === '-v') {
      console.log('avoid-ai-writing v3.10.0');
      process.exit(0);
    } else if (arg === '--mode') {
      options.mode = args[++i];
    } else if (arg === '--severity') {
      options.severity = args[++i].split(',');
    } else if (arg === '--context') {
      options.context = args[++i];
    } else if (arg === '--iterate') {
      options.iterate = parseInt(args[++i], 10);
    } else if (arg === '--json') {
      options.json = true;
    } else if (arg.startsWith('-')) {
      console.error(`Unknown option: ${arg}`);
      process.exit(1);
    } else {
      options.files.push(arg);
    }
  }

  if (options.files.length === 0) {
    // Try to read from stdin if no files provided
    if (!process.stdin.isTTY) {
      const stdinData = fs.readFileSync(0, 'utf-8');
      if (stdinData) {
        processContent('stdin', stdinData, options);
        return;
      }
    }
    showHelp();
    process.exit(1);
  }

  let totalFailures = 0;
  for (const file of options.files) {
    if (!fs.existsSync(file)) {
      console.error(`File not found: ${file}`);
      totalFailures++;
      continue;
    }
    const content = fs.readFileSync(file, 'utf-8');

    let hasP0 = false;
    if (options.mode === 'edit') {
      hasP0 = editContent(file, content, options);
    } else {
      hasP0 = processContent(file, content, options);
    }

    if (hasP0) totalFailures++;
  }

  process.exit(totalFailures > 0 ? 1 : 0);
}

function processContent(filename, content, options) {
  const result = AIDetector.analyzeText(content, { contextMode: options.context });

  // Filter issues by severity
  const filteredIssues = result.issues.filter(issue => {
    const sevLabel = AIDetector.SEVERITY_LABELS[issue.severity];
    return options.severity.includes(sevLabel);
  });

  const p0Issues = filteredIssues.filter(i => AIDetector.SEVERITY_LABELS[i.severity] === 'P0');

  if (options.json) {
    console.log(JSON.stringify({
      filename,
      score: result.score,
      label: result.label,
      issues: filteredIssues
    }, null, 2));
  } else {
    if (filteredIssues.length > 0) {
      console.log(`\nAudit for ${filename}: ${result.label} (Score: ${result.score})`);
      console.log('='.repeat(40));

      filteredIssues.forEach(issue => {
        const sev = AIDetector.SEVERITY_LABELS[issue.severity];
        const typeLabel = (AIDetector.TYPE_LABELS && AIDetector.TYPE_LABELS[issue.type]) || issue.type;
        console.log(`[${sev}] ${typeLabel}: "${issue.text}"`);
        if (issue.suggestion) console.log(`     Suggestion: ${issue.suggestion}`);
      });
    } else {
      console.log(`\n✓ ${filename}: No AI-isms found matching severity ${options.severity.join(',')}`);
    }
  }

  // Return true if build-failing issues are found (P0)
  return p0Issues.length > 0;
}

function editContent(filename, content, options) {
  let currentContent = content;
  let changed = false;

  for (let iter = 0; iter < options.iterate; iter++) {
    let iterationChanged = false;

    // Fix Tier 1 words and phrases
    for (const [word, suggestion] of Object.entries(AIDetector.TIER1)) {
      const regex = new RegExp(`\\b${word}\\b`, 'gi');
      if (regex.test(currentContent)) {
        const replacement = suggestion.split(',')[0].trim();
        currentContent = currentContent.replace(regex, replacement);
        iterationChanged = true;
        changed = true;
      }
    }

    for (const phrase of AIDetector.TIER1_PHRASES) {
      const regex = new RegExp(phrase.pattern.source, phrase.pattern.flags);
      if (regex.test(currentContent)) {
        const replacement = phrase.replace.split(',')[0].trim();
        currentContent = currentContent.replace(regex, replacement);
        iterationChanged = true;
        changed = true;
      }
    }

    // Fix Tier 2 if requested
    if (options.severity.includes('P2')) {
      for (const [word, suggestion] of Object.entries(AIDetector.TIER2)) {
        const regex = new RegExp(`\\b${word}\\b`, 'gi');
        if (regex.test(currentContent)) {
          const replacement = suggestion.split(',')[0].trim();
          currentContent = currentContent.replace(regex, replacement);
          iterationChanged = true;
          changed = true;
        }
      }
    }

    if (!iterationChanged) break;
  }

  if (changed) {
    if (filename !== 'stdin') {
      fs.writeFileSync(filename, currentContent, 'utf-8');
      console.log(`✓ ${filename}: Auto-fixed AI-isms.`);
    } else {
      process.stdout.write(currentContent);
    }
  } else if (!options.json) {
    console.log(`✓ ${filename}: No auto-fixable AI-isms found.`);
  }

  // Check if any P0 issues remain
  const result = AIDetector.analyzeText(currentContent, { contextMode: options.context });
  const p0Issues = result.issues.filter(i => AIDetector.SEVERITY_LABELS[i.severity] === 'P0');
  return p0Issues.length > 0;
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
