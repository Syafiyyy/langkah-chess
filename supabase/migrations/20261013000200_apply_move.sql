-- F2a section 2: finish_game (Elo, ADR-0007) and apply_move (ADR-0004).
-- Errors are raised with SQLSTATE P0001 and the error code as the message.

-- Seconds a player has for their first move before the game is aborted.
create function public.first_move_seconds()
returns int language sql immutable as 'select 30';

-- Ends an active game. Idempotent: a finished or aborted game is left alone,
-- and rating_history's UNIQUE(game_id, user_id) guards the rating update.
create function public.finish_game(p_game uuid, p_result text, p_termination text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games;
  w public.profiles;
  b public.profiles;
  score_w numeric;
  expected_w numeric;
  new_w int;
  new_b int;
  inserted int;
begin
  if p_result not in ('white', 'black', 'draw') then
    raise exception 'BAD_RESULT';
  end if;

  select * into g from public.games where id = p_game for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if g.status <> 'active' then
    return;
  end if;

  update public.games
  set status = 'finished', result = p_result, termination = p_termination,
      finished_at = now(), draw_offer_by = null, first_move_deadline = null
  where id = p_game;

  if g.white_id is null or g.black_id is null then
    return; -- a player deleted their account: no rating change
  end if;

  -- Lock both profiles in a fixed order (no deadlock between two finishes).
  perform 1 from public.profiles where id in (g.white_id, g.black_id)
    order by id for update;
  select * into w from public.profiles where id = g.white_id;
  select * into b from public.profiles where id = g.black_id;

  score_w := case p_result when 'white' then 1 when 'black' then 0 else 0.5 end;
  expected_w := 1 / (1 + power(10::numeric, (b.rating - w.rating) / 400.0));
  new_w := round(w.rating + (case when w.games_played < 30 then 32 else 20 end)
                 * (score_w - expected_w));
  new_b := round(b.rating + (case when b.games_played < 30 then 32 else 20 end)
                 * ((1 - score_w) - (1 - expected_w)));

  insert into public.rating_history (game_id, user_id, before, after)
  values (p_game, g.white_id, w.rating, new_w),
         (p_game, g.black_id, b.rating, new_b)
  on conflict (game_id, user_id) do nothing;
  get diagnostics inserted = row_count;
  if inserted = 0 then
    return; -- already rated
  end if;

  update public.profiles set rating = new_w, games_played = games_played + 1
  where id = g.white_id;
  update public.profiles set rating = new_b, games_played = games_played + 1
  where id = g.black_id;
end;
$$;

-- Ends a game without a result or rating (first-move deadline, abort).
create function public.abort_game(p_game uuid, p_termination text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.games
  set status = 'aborted', termination = p_termination, finished_at = now(),
      draw_offer_by = null, first_move_deadline = null
  where id = p_game and status in ('waiting', 'active');
$$;

-- Result when the side to move runs out of time: the opponent wins, unless the
-- opponent has no mating material (stored by make_move), then it is a draw.
create function public.timeout_result(g public.games)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when g.ply % 2 = 0 then case when g.black_can_mate then 'black' else 'draw' end
    else case when g.white_can_mate then 'white' else 'draw' end
  end;
$$;

-- Milliseconds left for the side to move, as of now (clocks run from ply 2).
create function public.clock_left_ms(g public.games)
returns int
language sql
stable
set search_path = ''
as $$
  select case when g.ply % 2 = 0 then g.white_ms else g.black_ms end
    - case when g.ply >= 2 and g.last_move_at is not null
        then floor(extract(epoch from (now() - g.last_move_at)) * 1000)::int
        else 0 end;
$$;

-- If the game is over on time (or past the first-move deadline), end it and
-- return true. Shared by apply_move, claim_timeout and the sweep.
create function public.settle_clock(p_game uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games;
begin
  select * into g from public.games where id = p_game for update;
  if g.status <> 'active' then
    return false;
  end if;
  if g.ply < 2 then
    if g.first_move_deadline is not null and g.first_move_deadline <= now() then
      perform public.abort_game(p_game, 'firstMoveTimeout');
      return true;
    end if;
    return false;
  end if;
  if public.clock_left_ms(g) <= 0 then
    if g.ply % 2 = 0 then
      update public.games set white_ms = 0 where id = p_game;
    else
      update public.games set black_ms = 0 where id = p_game;
    end if;
    perform public.finish_game(p_game, public.timeout_result(g), 'timeout');
    return true;
  end if;
  return false;
end;
$$;

-- Applies a move that make_move has already validated with chess.js.
-- Atomic and idempotent per client_move_id. Returns the game after the call;
-- the move was applied iff the returned ply = p_ply.
create function public.apply_move(
  p_game uuid,
  p_ply int,
  p_uci text,
  p_san text,
  p_fen_after text,
  p_result text,
  p_termination text,
  p_client_move_id uuid,
  p_user uuid,
  p_white_can_mate boolean,
  p_black_can_mate boolean
)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games;
  existing public.moves;
  white_to_move boolean;
  mover uuid;
  left_ms int;
  new_white int;
  new_black int;
begin
  select * into g from public.games where id = p_game for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  -- Safe retry: the same attempt returns the game as it is now.
  select * into existing from public.moves where client_move_id = p_client_move_id;
  if found then
    if existing.game_id <> p_game or existing.played_by is distinct from p_user then
      raise exception 'DUPLICATE_MOVE_ID';
    end if;
    return g;
  end if;

  if p_user is distinct from g.white_id and p_user is distinct from g.black_id then
    raise exception 'NOT_A_PLAYER';
  end if;
  if g.status <> 'active' then
    raise exception 'GAME_OVER';
  end if;
  if p_ply <> g.ply + 1 then
    raise exception 'STALE';
  end if;
  white_to_move := g.ply % 2 = 0;
  mover := g.black_id;
  if white_to_move then
    mover := g.white_id;
  end if;
  if p_user is distinct from mover then
    raise exception 'NOT_YOUR_TURN';
  end if;

  -- Out of time (or first move too late): the game ends without this move.
  if public.settle_clock(p_game) then
    select * into g from public.games where id = p_game;
    return g;
  end if;

  new_white := g.white_ms;
  new_black := g.black_ms;
  if g.ply >= 2 then
    left_ms := public.clock_left_ms(g) + g.increment_ms;
    if white_to_move then new_white := left_ms; else new_black := left_ms; end if;
  end if;

  insert into public.moves (game_id, ply, uci, san, fen_after, white_ms, black_ms,
                            client_move_id, played_by)
  values (p_game, p_ply, p_uci, p_san, p_fen_after, new_white, new_black,
          p_client_move_id, p_user);

  update public.games
  set fen = p_fen_after,
      ply = p_ply,
      white_ms = new_white,
      black_ms = new_black,
      last_move_at = now(),
      first_move_deadline = case
        when p_ply = 1 then now() + make_interval(secs => public.first_move_seconds())
        else null end,
      draw_offer_by = null,
      white_can_mate = p_white_can_mate,
      black_can_mate = p_black_can_mate
  where id = p_game;

  if p_result is not null then
    perform public.finish_game(p_game, p_result, p_termination);
  end if;

  select * into g from public.games where id = p_game;
  return g;
end;
$$;

-- Only the make_move Edge Function (service role) may apply moves; the helpers
-- are internal.
revoke execute on function public.apply_move(uuid, int, text, text, text, text, text, uuid, uuid, boolean, boolean)
  from public, anon, authenticated;
grant execute on function public.apply_move(uuid, int, text, text, text, text, text, uuid, uuid, boolean, boolean)
  to service_role;
revoke execute on function public.finish_game(uuid, text, text) from public, anon, authenticated, service_role;
revoke execute on function public.abort_game(uuid, text) from public, anon, authenticated, service_role;
revoke execute on function public.settle_clock(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.timeout_result(public.games) from public, anon, authenticated;
revoke execute on function public.clock_left_ms(public.games) from public, anon, authenticated;
