-- F2a section 4: the minute sweep (pg_cron, ADR-0005) and account deletion.

-- Ends games past their first-move deadline (abort) or with a flagged clock
-- (timeout, draw without mating material) and drops queue entries not seen
-- for 2 minutes. Returns how many games it ended. Rows locked by a move in
-- progress are skipped; the next run (or the players' claim_timeout) gets them.
create function public.sweep_games()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  ended int := 0;
begin
  for r in
    select g.id from public.games g
    where g.status = 'active'
      and ((g.ply < 2 and g.first_move_deadline <= now())
           or (g.ply >= 2 and public.clock_left_ms(g) <= 0))
    for update skip locked
  loop
    if public.settle_clock(r.id) then
      ended := ended + 1;
    end if;
  end loop;

  delete from public.matchmaking_queue where seen_at < now() - interval '2 minutes';
  return ended;
end;
$$;

-- Ends everything the user is still part of, before the delete_account Edge
-- Function deletes the auth user (profile, queue entry and rating history go
-- by cascade; games and moves stay for opponents with the player set to null).
-- Running games are resigned (rated, so the opponent keeps the win); games
-- nobody has really started and waiting invites are aborted.
create function public.prepare_account_deletion(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  g record;
begin
  delete from public.matchmaking_queue where user_id = p_user;
  for g in
    select id, status, ply, white_id from public.games
    where status in ('waiting', 'active') and p_user in (white_id, black_id, created_by)
    order by id
    for update
  loop
    if g.status = 'waiting' or g.ply < 2 then
      perform public.abort_game(g.id, 'aborted');
    elsif not public.settle_clock(g.id) then
      perform public.finish_game(
        g.id, case when g.white_id = p_user then 'black' else 'white' end, 'resignation');
    end if;
  end loop;
end;
$$;

revoke execute on function public.sweep_games() from public, anon, authenticated, service_role;
revoke execute on function public.prepare_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid) to service_role;

-- pg_cron (Supabase docs: install in pg_catalog). The job runs as postgres.
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;
select cron.schedule('skak-sweep', '* * * * *', 'select public.sweep_games()');
