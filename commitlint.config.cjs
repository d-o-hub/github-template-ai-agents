module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'header-max-length': [2, 'always', 150],
    'body-max-length': [2, 'always', 200],
    'body-max-line-length': [2, 'always', 100],
    'footer-max-length': [2, 'always', 200],
    'subject-case': [2, 'always', 'lower-case'],
  },
};
