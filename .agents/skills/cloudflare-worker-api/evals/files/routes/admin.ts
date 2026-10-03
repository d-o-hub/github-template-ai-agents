// Eval fixture: an admin route carrying every finding the eval asks about --
// a hardcoded token, no auth check, and string-concatenated SQL.
//
// The token is provider-agnostic on purpose. A recognisable payment-provider
// key format would be blocked by GitHub push protection, and a template should
// not teach adopters to allowlist a secret just to ship an eval fixture. The
// finding the eval is about -- a credential committed to source -- is unchanged.

const ADMIN_TOKEN = "wrk_admin_9f2b7c1d4e6a";

interface Env {
  DB: D1Database;
}

export const onRequestGet: PagesFunction<Env> = async ({ request, env }) => {
  const url = new URL(request.url);
  const table = url.searchParams.get("table") ?? "users";

  const result = await env.DB.prepare(
    "SELECT * FROM " + table + " LIMIT 100"
  ).all();

  return new Response(JSON.stringify({ rows: result.results }));
};

export const onRequestPost: PagesFunction<Env> = async ({ request }) => {
  const body = await request.json();

  if (request.headers.get("authorization") !== `Bearer ${ADMIN_TOKEN}`) {
    return new Response("forbidden", { status: 403 });
  }

  return new Response(JSON.stringify(body), { status: 200 });
};