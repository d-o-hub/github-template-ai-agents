---
name: lifecycle-management
description: Manage application lifecycle, error handling, and resource cleanup to prevent memory leaks and ensure stability. Use this skill when handling startup/shutdown sequences, managing resource pools, implementing error boundaries, preventing memory leaks, or ensuring graceful degradation — even if they just say "clean up resources" or "fix the memory leak". Not for security-code-auditor.
version: "0.2.10"
category: quality
license: MIT
---

# Lifecycle Management

Generic patterns for managing application lifecycle, specifically for web applications to prevent memory leaks and handle global errors.

## When to Use

- User asks to handle startup/shutdown sequences or manage resource pools
- Need to implement error boundaries or prevent memory leaks
- Even if they just say "clean up resources" or "fix the memory leak"

## Patterns

### Global Error Handler

`initGlobalErrorHandling()` MUST be called to catch uncaught exceptions and unhandled rejections.

```javascript
function initGlobalErrorHandling() {
  window.addEventListener('error', (event) => {
    console.error('Uncaught exception:', event.error);
    // Add telemetry/reporting here
  });

  window.addEventListener('unhandledrejection', (event) => {
    console.error('Unhandled rejection:', event.reason);
    // Add telemetry/reporting here
  });
}
```

### Route Cleanup

Call `lifecycle.cleanupRoute()` before navigating to cancel in-flight fetch requests via a global `AbortController`.

```javascript
const lifecycle = {
  controller: new AbortController(),
  cleanupRoute() {
    this.controller.abort();
    this.controller = new AbortController();
  }
};
```

### Event Listeners

Use `AbortController` signal for all `addEventListener` calls where possible to automate cleanup.

```javascript
const controller = new AbortController();
const { signal } = controller;

// handleResize must be defined in your component or module
window.addEventListener('resize', handleResize, { signal });

// Later, to remove all listeners associated with this controller:
controller.abort();
```

## See Also

- `security-code-auditor` — Security audits
- `pwa-offline-sync` — Service workers and caching

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "It's just a small app, no leaks." | Memory leaks accumulate over time and affect performance and stability even in small apps. |
| "I'll remove listeners manually." | Manual removal is error-prone and often forgotten. AbortController is a cleaner, more robust pattern. |

## Red Flags

- [ ] `addEventListener` used without a corresponding `removeEventListener` or `signal`.
- [ ] No global error handling implementation.
- [ ] In-flight requests not cancelled during navigation or component unmounting.
