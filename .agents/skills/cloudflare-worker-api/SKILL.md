---
version: "0.2.10"
name: cloudflare-worker-api
description: >
  Structure Worker API routes and handlers. Use this skill when defining Cloudflare Worker routes, building response helpers, or implementing typed handler patterns — even if they just say "set up the worker routes" or "add an API endpoint to the worker". Auth belongs to secure-invite-and-access.
category: workflow
license: MIT
---

# Cloudflare Worker API

Provide a standardized structure for Worker routes, auth middleware, and response helpers.

## When to Use

- User asks to define Cloudflare Worker routes or handlers
- Building response helpers or typed handler patterns
- Even if they just say "set up the worker routes" or "add an API endpoint to the worker"

## Key Responsibilities

- Define API routes and handlers.
- Implement auth middleware and session validation.
- Provide response helpers for consistent API responses.
- Design signed URL endpoints for secure file access.

## Interface Example

```ts
// Example route file structure
src/routes/
  access.ts
  resources.ts
  admin.ts
```

## Constraints

- No hardcoded secrets.
- All routes must be typed and validated.
- Use Zod for input validation.
- All responses must follow consistent format.

## Checklist

- [ ] All routes have input validation with Zod.
- [ ] Error responses follow consistent format.
- [ ] Auth middleware applied to protected routes.
- [ ] Rate limiting configured on public endpoints.
- [ ] CORS headers set appropriately.

## References

- `references/routing-patterns.md` - Common routing patterns for Workers
- `references/response-helpers.md` - Consistent response formatting

## See Also

- `secure-invite-and-access` — Auth endpoints and permissions
- `api-design-first` — API design and OpenAPI specs

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll add auth later, it's just an MVP" | Unauthenticated endpoints are immediately exploitable; even internal routes need auth. |
| "Hardcoded secrets are fine for dev" | Dev credentials leak into version control; use environment bindings from day one. |
| "Rate limiting isn't needed for internal APIs" | Compromised internal tokens turn rate-limited services into attack amplifiers. |

## Red Flags

- [ ] Returning raw error stack traces in API responses
- [ ] Skipping input validation because "the client should handle it"
- [ ] Deploying without CORS configuration on public endpoints
