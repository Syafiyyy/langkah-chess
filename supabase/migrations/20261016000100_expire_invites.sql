-- The minute sweep also aborts invites nobody joined within 24 hours
-- (termination 'expired', no rating). CREATE OR REPLACE keeps the grants:
-- still no role but postgres (pg_cron) can run it.
create or replace function public.sweep_games()
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

  for r in
    select g.id from public.games g
    where g.status = 'waiting' and g.created_at < now() - interval '24 hours'
    for update skip locked
  loop
    perform public.abort_game(r.id, 'expired');
    ended := ended + 1;
  end loop;

  delete from public.matchmaking_queue where seen_at < now() - interval '2 minutes';
  return ended;
end;
$$;
