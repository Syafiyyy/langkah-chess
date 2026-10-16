-- F2b: rematch after a finished game.
-- A waiting invite is visible only to its creator, so the opponent can't see
-- a rematch invite on its own. offer_rematch stores the new invite's code on
-- the finished game (readable by both players; its Realtime event is the
-- opponent's hint). When the opponent offers too, they join that invite.

alter table public.games
  add column rematch_code text,
  add column rematch_by uuid references public.profiles (id) on delete set null;

create index games_rematch_by_idx on public.games (rematch_by);

-- Offers a rematch with the same time control, or accepts the opponent's
-- offer. Returns the new game: waiting (offered) or active (accepted).
create function public.offer_rematch(p_game uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_uid();
  g public.games := public.lock_my_game(p_game);
  opponent uuid;
  offered public.games;
begin
  if uid is distinct from g.white_id and uid is distinct from g.black_id then
    raise exception 'NOT_A_PLAYER';
  end if;
  if g.status <> 'finished' then
    raise exception 'NOT_FINISHED';
  end if;
  if uid = g.white_id then
    opponent := g.black_id;
  else
    opponent := g.white_id;
  end if;
  if opponent is null then
    raise exception 'NO_OPPONENT';
  end if;

  if g.rematch_code is not null then
    select * into offered from public.games where invite_code = g.rematch_code;
    if g.rematch_by = uid and offered.status = 'waiting' then
      return offered;
    end if;
    if g.rematch_by = opponent and offered.status = 'waiting' then
      return public.join_invite(g.rematch_code);
    end if;
    -- The earlier offer was cancelled or expired: make a new one.
  end if;

  offered := public.create_invite(g.time_base_ms, g.increment_ms);
  update public.games set rematch_code = offered.invite_code, rematch_by = uid
  where id = p_game;
  return offered;
end;
$$;

revoke execute on function public.offer_rematch(uuid) from public, anon;
grant execute on function public.offer_rematch(uuid) to authenticated;
