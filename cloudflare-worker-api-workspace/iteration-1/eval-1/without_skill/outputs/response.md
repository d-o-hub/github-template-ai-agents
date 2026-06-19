# User Profile Update API Route

## Overview

This document provides a Cloudflare Worker API route for user profile updates with comprehensive input validation.

## API Route Implementation

```typescript
// src/routes/profile.ts

interface UserProfile {
  id: string;
  email: string;
  name: string;
  bio?: string;
  avatarUrl?: string;
  updatedAt: string;
}

interface UpdateProfileRequest {
  name?: string;
  email?: string;
  bio?: string;
  avatarUrl?: string;
}

interface ValidationErrors {
  [field: string]: string[];
}

function validateEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function validateUrl(url: string): boolean {
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

function validateProfileUpdate(data: unknown): {
  valid: boolean;
  errors: ValidationErrors;
  sanitized: UpdateProfileRequest;
} {
  const errors: ValidationErrors = {};
  const sanitized: UpdateProfileRequest = {};

  if (typeof data !== 'object' || data === null) {
    return { valid: false, errors: { body: ['Request body must be a JSON object'] }, sanitized };
  }

  const body = data as Record<string, unknown>;

  if ('name' in body) {
    if (typeof body.name !== 'string') {
      errors.name = ['Name must be a string'];
    } else if (body.name.trim().length === 0) {
      errors.name = ['Name cannot be empty'];
    } else if (body.name.length > 100) {
      errors.name = ['Name must be 100 characters or less'];
    } else {
      sanitized.name = body.name.trim();
    }
  }

  if ('email' in body) {
    if (typeof body.email !== 'string') {
      errors.email = ['Email must be a string'];
    } else if (!validateEmail(body.email)) {
      errors.email = ['Email must be a valid email address'];
    } else {
      sanitized.email = body.email.toLowerCase().trim();
    }
  }

  if ('bio' in body) {
    if (typeof body.bio !== 'string') {
      errors.bio = ['Bio must be a string'];
    } else if (body.bio.length > 500) {
      errors.bio = ['Bio must be 500 characters or less'];
    } else {
      sanitized.bio = body.bio.trim() || undefined;
    }
  }

  if ('avatarUrl' in body) {
    if (typeof body.avatarUrl !== 'string') {
      errors.avatarUrl = ['Avatar URL must be a string'];
    } else if (body.avatarUrl.length > 0 && !validateUrl(body.avatarUrl)) {
      errors.avatarUrl = ['Avatar URL must be a valid URL'];
    } else {
      sanitized.avatarUrl = body.avatarUrl.trim() || undefined;
    }
  }

  const hasNoFields = Object.keys(sanitized).length === 0;
  if (hasNoFields) {
    errors.body = ['At least one field must be provided for update'];
  }

  return {
    valid: Object.keys(errors).length === 0,
    errors,
    sanitized,
  };
}

export async function handleProfileUpdate(
  request: Request,
  env: Env,
  userId: string
): Promise<Response> {
  const headers = {
    'Content-Type': 'application/json',
  };

  if (request.method !== 'PATCH' && request.method !== 'PUT') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers }
    );
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return new Response(
      JSON.stringify({ error: 'Invalid JSON in request body' }),
      { status: 400, headers }
    );
  }

  const validation = validateProfileUpdate(body);

  if (!validation.valid) {
    return new Response(
      JSON.stringify({ error: 'Validation failed', details: validation.errors }),
      { status: 422, headers }
    );
  }

  const existingProfile = await env.PROFILE_KV.get(`profile:${userId}`, 'json') as UserProfile | null;

  if (!existingProfile) {
    return new Response(
      JSON.stringify({ error: 'Profile not found' }),
      { status: 404, headers }
    );
  }

  if (validation.sanitized.email && validation.sanitized.email !== existingProfile.email) {
    const emailTaken = await env.PROFILE_KV.get(`email:${validation.sanitized.email}`);
    if (emailTaken && emailTaken !== userId) {
      return new Response(
        JSON.stringify({ error: 'Email is already in use' }),
        { status: 409, headers }
      );
    }
  }

  const updatedProfile: UserProfile = {
    ...existingProfile,
    ...validation.sanitized,
    updatedAt: new Date().toISOString(),
  };

  await env.PROFILE_KV.put(`profile:${userId}`, JSON.stringify(updatedProfile));

  if (validation.sanitized.email && validation.sanitized.email !== existingProfile.email) {
    await env.PROFILE_KV.delete(`email:${existingProfile.email}`);
    await env.PROFILE_KV.put(`email:${validation.sanitized.email}`, userId);
  }

  return new Response(
    JSON.stringify({ profile: updatedProfile }),
    { status: 200, headers }
  );
}
```

## Route Registration

```typescript
// src/router.ts

import { handleProfileUpdate } from './routes/profile';

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    const profileMatch = path.match(/^\/api\/users\/([^/]+)\/profile$/);
    if (profileMatch && (request.method === 'PATCH' || request.method === 'PUT')) {
      const userId = profileMatch[1];
      return handleProfileUpdate(request, env, userId);
    }

    return new Response('Not Found', { status: 404 });
  },
};
```

## Type Definitions

```typescript
// src/types.ts

interface Env {
  PROFILE_KV: KVNamespace;
}

interface UserProfile {
  id: string;
  email: string;
  name: string;
  bio?: string;
  avatarUrl?: string;
  updatedAt: string;
}

interface UpdateProfileRequest {
  name?: string;
  email?: string;
  bio?: string;
  avatarUrl?: string;
}

interface ValidationErrors {
  [field: string]: string[];
}
```

## Validation Rules

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| name | string | No | 1-100 characters, non-empty after trim |
| email | string | No | Valid email format, unique across users |
| bio | string | No | Max 500 characters, optional (null/empty clears) |
| avatarUrl | string | No | Valid URL format, optional (null/empty clears) |

## Error Responses

| Status | Condition |
|--------|-----------|
| 405 | Wrong HTTP method (not PATCH/PUT) |
| 400 | Malformed JSON body |
| 404 | User profile not found |
| 409 | Email already in use by another user |
| 422 | Validation errors in request fields |

## Example Usage

```bash
# Update name and bio
curl -X PATCH https://api.example.com/api/users/usr_123/profile \
  -H "Content-Type: application/json" \
  -d '{"name": "Jane Doe", "bio": "Software engineer"}'

# Update email
curl -PATCH https://api.example.com/api/users/usr_123/profile \
  -H "Content-Type: application/json" \
  -d '{"email": "jane.new@example.com"}'
```
