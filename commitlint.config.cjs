module.exports = {
  extends: ['@commitlint/config-conventional'],
  // Skip dependabot commits: auto-generated body lines exceed 100 char limit
  // due to long URLs in changelog/release notes references
  ignores: [
    (commit) => commit.includes('Signed-off-by: dependabot[bot]'),
  ],
  rules: {
    'header-max-length': [2, 'always', 150],
    'body-max-length': [2, 'always', 1000],
    'body-max-line-length': [2, 'always', 100],
    'footer-max-length': [2, 'always', 1000],
    'footer-max-line-length': [2, 'always', 100],
    // subject-case disabled: identifiers like LESSON-017, SKILL.md are valid
    'subject-case': [0],
  },
};
