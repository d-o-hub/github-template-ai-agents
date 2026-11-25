# Resolver Runtime Notes

## Non-Obvious Learnings

- Base installs must import the text CLI without ML extras; load visual modules
  lazily and use the declared `ddgs` package (LESSON-048).
- Fetch callers use the httpx helper's `client=` contract and named `max_chars`;
  test with real `MockTransport`, including private redirects and empty-cache
  first writes, rather than replacing the request helper (LESSON-048).
