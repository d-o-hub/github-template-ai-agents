// Eval fixture: a profile-update route with no input validation.
// The eval asserts that the agent adds a schema check before touching the body.
interface Env {
  DB: D1Database;
}

export const onRequestPut: PagesFunction<Env> = async ({ request, env }) => {
  const body = await request.json();

  const { id, displayName, email } = body;

  await env.DB.prepare(
    "UPDATE users SET display_name = ?, email = ? WHERE id = ?"
  )
    .bind(displayName, email, id)
    .run();

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
};