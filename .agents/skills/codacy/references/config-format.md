# Codacy Configuration Format

Codacy can be configured via a `.codacy/codacy.config.json` file in the repository root.

## Schema

```json
{
  "tools": [
    {
      "name": "eslint",
      "enabled": true,
      "config": ".eslintrc.json"
    }
  ],
  "engines": {
    "node": "20"
  },
  "exclude_paths": [
    "dist/**",
    "tests/fixtures/**"
  ]
}
```

## Local Initialization

You can generate a default configuration using:
```bash
codacy-analysis init --default
```
