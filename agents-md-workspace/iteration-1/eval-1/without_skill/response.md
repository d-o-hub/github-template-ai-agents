# AGENTS.md - TypeScript Monorepo with npm Workspaces

## Named Constants

```bash
readonly MAX_LINES_PER_SOURCE_FILE=500
readonly MAX_LINES_AGENTS_MD=200
readonly MAX_COMMIT_SUBJECT_LENGTH=150
readonly MAX_PR_TITLE_LENGTH=150
```

## Monorepo Structure

```
├── packages/           # Shared packages (core, api, ui, utils)
├── apps/               # Deployable applications
├── scripts/            # Build and utility scripts
├── tsconfig.base.json  # Base TypeScript configuration
└── package.json        # Root workspace configuration
```

## npm Workspaces Setup

**Root package.json:**

```json
{
  "name": "@myorg/monorepo",
  "version": "0.0.0",
  "private": true,
  "workspaces": ["packages/*", "apps/*"],
  "scripts": {
    "build": "turbo run build",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "dev": "turbo run dev"
  }
}
```

**Package naming:** `@myorg/package-name`

## TypeScript Configuration

**Base tsconfig.base.json:**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "declaration": true,
    "sourceMap": true,
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
```

**Each package extends base:**

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "outDir": "./dist", "rootDir": "./src" },
  "include": ["src/**/*"]
}
```

## Development Commands

```bash
npm install                    # Install all dependencies
npm run build                  # Build all packages
npm run build --workspace=@myorg/pkg  # Build specific package
npm run test                   # Run all tests
npm run test --workspace=@myorg/pkg   # Test specific package
npm run lint                   # Lint all packages
npm run dev                    # Start development mode
```

## Package Management Rules

- NEVER install dependencies directly in packages
- Use `npm install --save-dev <pkg>` from root for shared deps
- Use `npm install <pkg> --workspace=@myorg/target` for package-specific deps
- Internal deps: `"@myorg/core": "*"`

## Code Style & Conventions

### TypeScript Rules
- Strict TypeScript (strict: true)
- Prefer interfaces over types for object shapes
- Explicit return types for public functions
- Avoid `any` - use `unknown` and type guards
- Use async/await over raw promises

### Naming Conventions
- Files: `kebab-case.ts`
- Classes: `PascalCase`
- Interfaces: `PascalCase` (no `I` prefix)
- Functions: `camelCase`
- Constants: `UPPER_SNAKE_CASE`

## Testing Requirements

- **Framework**: Vitest (preferred) or Jest
- **Coverage**: Minimum 80% for new code
- **Location**: `__tests__/` or co-located with source
- **Naming**: `*.test.ts` or `*.spec.ts`

## Quality Gates (Required Before Commit)

```bash
npm run typecheck   # Type checking
npm run lint        # Linting (zero warnings)
npm run test        # Tests must pass
npm run build       # Build must succeed
```

## Build & CI Requirements

### CI Pipeline Must Include
1. Dependency installation
2. TypeScript compilation check
3. Linting (ESLint + Prettier)
4. Test execution with coverage
5. Build verification

## Dependency Management

- Always commit `package-lock.json`
- Use `npm update` for minor/patch, manual for major
- Run `npm audit` before merging security updates
- Run `npm dedupe` after major dependency changes

## Common Patterns

### Shared Types Package
```typescript
// packages/core/src/types/index.ts
export interface User {
  id: string;
  name: string;
  email: string;
}
```

### Package.json for Shared Package
```json
{
  "name": "@myorg/core",
  "version": "0.0.0",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "scripts": { "build": "tsc", "test": "vitest run" }
}
```

## Error Handling

- Use custom error classes extending `Error`
- Include error codes for programmatic handling
- Log errors with context (package name, operation)
- Never swallow errors silently

## Documentation

- README.md required in each package
- JSDoc for all public APIs
- Update root README when adding packages
- Maintain CHANGELOG.md for breaking changes

## Git Workflow

- Branch per feature/fix
- One concern per PR
- Never commit to `main` directly
- Squash merge to maintain clean history
- PR title: `type(scope): description`

## Troubleshooting

1. **Dependency not found**: Run `npm install` from root
2. **Type errors across packages**: Rebuild dependent packages first
3. **Circular dependencies**: Use dependency injection or restructure
4. **Build order**: Check `turbo.json` for correct order

```bash
npm ls --all           # Check dependency tree
npm ls --depth=0       # Verify workspace links
npm dedupe --dry-run   # Check for duplicates
```
