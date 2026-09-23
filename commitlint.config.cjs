module.exports = {
  extends: ['@commitlint/config-conventional'],
  // Skip dependabot commits: auto-generated body lines exceed 100 char limit
  // due to long URLs in changelog/release notes references
  ignores: [
    (commit) => commit.includes('Signed-off-by: dependabot[bot]'),
    // Ignore bot-generated merge/squash commits (emoji prefix in PR title)
    (message) => /^\p{Emoji_Presentation}/u.test(message.split('\n')[0]),
    // Ignore commits with bot co-author trailers (squash merge body)
    (message) => /^\* /m.test(message) && /^Co-authored-by:.*\[bot\]/m.test(message),
  ],
  rules: {
    'header-max-length': [2, 'always', 150],
    // Allow longer bodies for squash merges that include PR description.
    // Enforced at PR level instead via lint-pr-title workflow.
    'body-max-length': [0],
    // body-max-line-length disabled — squash merge bodies from gh pr merge
    // naturally exceed 100 chars. Enforced at PR level (1000 chars) instead.
    'body-max-line-length': [0],
    'footer-max-length': [2, 'always', 1000],
    // footer-max-line-length disabled — GitHub squash merges append the PR body
    // (free-form markdown with >100-char lines) as the commit footer, which made
    // the 2026-08-07 Commit Lint run on main fail (8d673e1). Same rationale as
    // body-max-line-length above: line length is enforced at PR level instead.
    'footer-max-line-length': [0],
    // subject-case disabled: identifiers like LESSON-017, SKILL.md are valid
    'subject-case': [0],
  },
};
