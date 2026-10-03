// Eval fixture: public endpoints with no rate limiting and no CORS headers.
// The eval asserts the agent adds both without touching the route bodies.
interface Env {
  RATELIMIT: KVNamespace;
}

const PUBLIC_PATHS = ["/api/products", "/api/orders", "/api/health"];

export const onRequest: PagesFunction<Env> = async ({ request, env, next }) => {
  const url = new URL(request.url);

  if (PUBLIC_PATHS.includes(url.pathname)) {
    const response = await next();
    return response;
  }

  return next();
};