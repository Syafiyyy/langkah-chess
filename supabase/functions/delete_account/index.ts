// Edge Function delete_account: POST with the user's JWT deletes that user's
// account (see account.ts and prepare_account_deletion). Returns
// { deleted: true } or { error }.
import { admin, json, userIdFrom } from "../_shared/admin.ts";
import { type AccountDeps, deleteAccount } from "./account.ts";

const deps: AccountDeps = {
  async prepare(userId) {
    const { error } = await admin.rpc("prepare_account_deletion", { p_user: userId });
    if (error) throw error;
  },
  async deleteUser(userId) {
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  },
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "METHOD_NOT_ALLOWED" });
  const userId = await userIdFrom(req);
  if (!userId) return json(401, { error: "UNAUTHORIZED" });
  try {
    await deleteAccount(deps, userId);
    return json(200, { deleted: true });
  } catch (e) {
    console.error("delete_account failed", e);
    return json(500, { error: "INTERNAL" });
  }
});
