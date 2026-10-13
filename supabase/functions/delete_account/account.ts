// delete_account logic: end the user's games and queue entry first
// (prepare_account_deletion), then delete the auth user, whose profile and
// rating history go by cascade. A failed first step keeps the account, so a
// retry can finish the job.
export interface AccountDeps {
  prepare(userId: string): Promise<void>;
  deleteUser(userId: string): Promise<void>;
}

export async function deleteAccount(deps: AccountDeps, userId: string): Promise<void> {
  await deps.prepare(userId);
  await deps.deleteUser(userId);
}
