import { assertEquals, assertRejects } from "@std/assert";
import { type AccountDeps, deleteAccount } from "./account.ts";

const USER = "00000000-0000-4000-8000-000000000001";

function fake(failPrepare = false) {
  const calls: string[] = [];
  const deps: AccountDeps = {
    prepare: (id) => {
      calls.push(`prepare ${id}`);
      return failPrepare ? Promise.reject(new Error("db down")) : Promise.resolve();
    },
    deleteUser: (id) => {
      calls.push(`delete ${id}`);
      return Promise.resolve();
    },
  };
  return { calls, deps };
}

Deno.test("games are settled before the auth user is deleted", async () => {
  const { calls, deps } = fake();
  await deleteAccount(deps, USER);
  assertEquals(calls, [`prepare ${USER}`, `delete ${USER}`]);
});

Deno.test("the user is kept when settling the games fails", async () => {
  const { calls, deps } = fake(true);
  await assertRejects(() => deleteAccount(deps, USER));
  assertEquals(calls, [`prepare ${USER}`]);
});
