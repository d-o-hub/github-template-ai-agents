#!/usr/bin/env node
/**
 * UI/UX Optimize — Token validation pre-check.
 *
 * Fast-fail filesystem validation that runs before expensive browser verification.
 * Checks that persistent design JSON and code design system exist and are aligned.
 *
 * Exit 0 = pass, Exit 1 = fail.
 */

const fs = require('fs');
const path = require('path');

const designTokensPath = path.join(process.cwd(), 'docs', 'design', 'design-tokens.json');
const codeDesignSystemPath = path.join(process.cwd(), 'src', 'lib', 'design-system.tsx');
const sessionJsonlPath = path.join(process.cwd(), 'ui-ux-session.jsonl');

let hasError = false;

// 1. Check persistent design tokens JSON
if (!fs.existsSync(designTokensPath)) {
  console.error('❌ Validation failed: docs/design/design-tokens.json not found.');
  console.error('   Run Step 2 (Token Architect) of the UI/UX Optimize skill first.');
  hasError = true;
} else {
  try {
    const currentTokens = JSON.parse(fs.readFileSync(designTokensPath, 'utf8'));
    const requiredCategories = ['colors', 'typography', 'spacing', 'radius', 'shadow', 'breakpoints', 'effects'];

    requiredCategories.forEach(cat => {
      if (!currentTokens[cat]) {
        console.error(`❌ Validation failed: Missing required category "${cat}" in design-tokens.json.`);
        hasError = true;
      }
    });

    // 2. Programmatic Freeze Check (Session-based)
    if (fs.existsSync(sessionJsonlPath)) {
      const lines = fs.readFileSync(sessionJsonlPath, 'utf8').split('\n').filter(Boolean);
      let frozenTokens = null;

      // Find the first occurrence of design_tokens in the session log
      for (const line of lines) {
        try {
          const entry = JSON.parse(line);
          if (entry.design_tokens) {
            frozenTokens = entry.design_tokens;
            break;
          }
        } catch (e) { /* ignore malformed lines */ }
      }

      if (frozenTokens) {
        for (const cat of requiredCategories) {
          if (frozenTokens[cat] && JSON.stringify(frozenTokens[cat]) !== JSON.stringify(currentTokens[cat])) {
            console.error(`❌ FREEZE VIOLATION: Category "${cat}" has changed from the initial frozen state in the session log.`);
            console.error(`   Initial: ${JSON.stringify(frozenTokens[cat])}`);
            console.error(`   Current: ${JSON.stringify(currentTokens[cat])}`);
            hasError = true;
          }
        }
      }
    }
  } catch (e) {
    console.error(`❌ Validation failed: design-tokens.json is not valid JSON. Error: ${e.message}`);
    hasError = true;
  }
}

// 3. Check code design system
if (!fs.existsSync(codeDesignSystemPath)) {
  console.error('❌ Validation failed: src/lib/design-system.tsx not found.');
  console.error('   Run Step 4a (Sync Code) to generate the code design system from the JSON tokens.');
  hasError = true;
}

if (hasError) {
  process.exit(1);
}

console.log('✅ Token validation passed: design tokens (JSON) and code design system are aligned.');
process.exit(0);
