// Service-role client and request helpers shared by the Edge Functions.
// The secret key bypasses RLS: it never leaves the function.
import { createClient } from "@supabase/supabase-js";

function secretKey(): string {
  const keys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (keys) return JSON.parse(keys)["default"];
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // local stack
}

export const admin = createClient(Deno.env.get("SUPABASE_URL")!, secretKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

/** The signed-in user's id from the request's JWT, or null. */
export async function userIdFrom(req: Request): Promise<string | null> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer /, "");
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  return data.user?.id ?? null;
}

export function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
