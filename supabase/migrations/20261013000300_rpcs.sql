-- F2a section 3: RPCs for signed-in users (SECURITY DEFINER, check auth.uid()).
-- Errors are raised with SQLSTATE P0001 and the error code as the message.
-- Game actions are idempotent: on a game that is already over they return
-- the game unchanged, so a retried request sees the result.

-- Internal helpers -----------------------------------------------------------

create function public.require_uid()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'NOT_SIGNED_IN';
  end if;
  return uid;
end;
$$;

create function public.check_time_control(p_time_base_ms int, p_increment_ms int)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  -- Same bounds as the games table.
  if p_time_base_ms is null or p_time_base_ms not between 60000 and 3600000
     or p_increment_ms is null or p_increment_ms not between 0 and 60000 then
    raise exception 'BAD_TIME_CONTROL';
  end if;
end;
$$;

-- 6 characters without 0/O/1/I. 32 symbols, so byte % 32 is unbiased.
create function public.random_invite_code()
returns text
language sql
volatile
set search_path = ''
as $$
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', get_byte(b, i) % 32 + 1, 1), ''
                    order by i)
  from extensions.gen_random_bytes(6) as b, generate_series(0, 5) as i;
$$;

-- Starts a waiting game between two users with random colours.
create function public.start_game(p_game uuid, p_a uuid, p_b uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games;
  white uuid := p_a;
  black uuid := p_b;
begin
  if random() < 0.5 then
    white := p_b;
    black := p_a;
  end if;
  update public.games
  set white_id = white, black_id = black, status = 'active',
      first_move_deadline = now() + make_interval(secs => public.first_move_seconds())
  where id = p_game
  returning * into g;
  return g;
end;
$$;

-- Locks a game the caller plays in (or created) and returns it.
create function public.lock_my_game(p_game uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_uid();
  g public.games;
begin
  select * into g from public.games where id = p_game for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if uid is distinct from g.white_id and uid is distinct from g.black_id
     and uid is distinct from g.created_by then
    raise exception 'NOT_A_PLAYER';
  end if;
  return g;
end;
$$;

-- Profile -------------------------------------------------------------------------

-- Sets the username (once; null keeps it) and/or the avatar key (any time).
create function public.set_profile(p_username text, p_avatar text)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_uid();
  p public.profiles;
begin
  select * into p from public.profiles where id = uid for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  if p_username is not null and p_username is distinct from p.username then
    if p.username_set then
      raise exception 'USERNAME_LOCKED';
    end if;
    -- "u_..." is reserved for temporary names (a clash would break a signup).
    if p_username !~ '^[a-z0-9_]{3,20}$' or p_username like 'u\_%' then
      raise exception 'BAD_USERNAME';
    end if;
    begin
      update public.profiles set username = p_username, username_set = true where id = uid;
    exception when unique_violation then
      raise exception 'USERNAME_TAKEN';
    end;
  end if;

  if p_avatar is not null then
    if p_avatar !~ '^[a-z0-9_]{1,32}$' then
      raise exception 'BAD_AVATAR';
    end if;
    update public.profiles set avatar = p_avatar where id = uid;
  end if;

  select * into p from public.profiles where id = uid;
  return p;
end;
$$;

-- Invites ---------------------------------------------------------------------------

-- A waiting game with an invite code. Returns the caller's existing waiting
-- invite with the same time control instead of making a second one.
create function public.create_invite(p_time_base_ms int, p_increment_ms int)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_uid();
  g public.games;
begin
  perform public.check_time_control(p_time_base_ms, p_increment_ms);
  select * into g from public.games
  where created_by = uid and status = 'waiting' and mode = 'invite'
    and time_base_ms = p_time_base_ms and increment_ms = p_increment_ms
  limit 1;
  if found then
    return g;
  end if;

  loop
    begin
      insert into public.games (created_by, mode, time_base_ms, increment_ms,
                                white_ms, black_ms, invite_code)
      values (uid, 'invite', p_time_base_ms, p_increment_ms,
              p_time_base_ms, p_time_base_ms, public.random_invite_code())
      returning * into g;
      return g;
    exception when unique_violation then
      -- Code already in use: draw another.
    end;
  end loop;
end;
$$;

-- Joins an invite by code (any case). Joining a game you already play returns it.
create function public.join_invite(p_code text)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_uid();
  g public.games;
begin
  select * into g from public.games where invite_code = upper(trim(p_code)) for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if uid = g.white_id or uid = g.black_id then
    return g;
  end if;
  if uid = g.created_by then
    raise exception 'OWN_GAME';
  end if;
  if g.status <> 'waiting' then
    raise exception 'NOT_AVAILABLE';
  end if;
  return public.start_game(g.id, g.created_by, uid);
end;
$$;

-- Matchmaking -----------------------------------------------------------------------

-- Pairs the caller with the longest-waiting user with the same time control,
-- or queues the caller. Returns the game (one row) or nothing when queued.
-- A caller already in an active matchmaking game gets that game back, which
-- is also how a queued user learns about a pairing.
create function public.join_queue(p_time_base_ms int, p_increment_ms int)
returns setof public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_uid();
  g public.games;
  opponent uuid;
begin
  perform public.check_time_control(p_time_base_ms, p_increment_ms);
  -- One matchmaker at a time: nobody can be paired twice.
  perform pg_advisory_xact_lock(hashtext('skak.matchmaking'));

  select * into g from public.games
  where mode = 'matchmaking' and status = 'active' and uid in (white_id, black_id)
  order by created_at desc
  limit 1;
  if found then
    delete from public.matchmaking_queue where user_id = uid;
    return next g;
    return;
  end if;

  select user_id into opponent from public.matchmaking_queue
  where user_id <> uid and time_base_ms = p_time_base_ms and increment_ms = p_increment_ms
  order by created_at
  limit 1
  for update skip locked;

  if opponent is null then
    insert into public.matchmaking_queue (user_id, time_base_ms, increment_ms, rating)
    select uid, p_time_base_ms, p_increment_ms, rating from public.profiles where id = uid
    on conflict (user_id) do update
    set time_base_ms = excluded.time_base_ms,
        increment_ms = excluded.increment_ms,
        rating = excluded.rating,
        created_at = case
          when public.matchmaking_queue.time_base_ms = excluded.time_base_ms
           and public.matchmaking_queue.increment_ms = excluded.increment_ms
          then public.matchmaking_queue.created_at
          else now() end;
    return;
  end if;

  delete from public.matchmaking_queue where user_id in (uid, opponent);
  insert into public.games (mode, time_base_ms, increment_ms, white_ms, black_ms)
  values ('matchmaking', p_time_base_ms, p_increment_ms, p_time_base_ms, p_time_base_ms)
  returning * into g;
  return next public.start_game(g.id, opponent, uid);
end;
$$;

create function public.leave_queue()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.matchmaking_queue where user_id = public.require_uid();
$$;

-- Game actions ----------------------------------------------------------------------
-- Each settles the clock first: a flag beats a late resign or draw.

create function public.resign(p_game uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games := public.lock_my_game(p_game);
begin
  if g.status = 'active' and not public.settle_clock(p_game) then
    perform public.finish_game(
      p_game,
      case when auth.uid() = g.white_id then 'black' else 'white' end,
      'resignation');
  end if;
  select * into g from public.games where id = p_game;
  return g;
end;
$$;

-- Offering when the opponent has already offered accepts their offer.
create function public.offer_draw(p_game uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games := public.lock_my_game(p_game);
begin
  if g.status = 'active' and not public.settle_clock(p_game) then
    if g.draw_offer_by is not null and g.draw_offer_by <> auth.uid() then
      perform public.finish_game(p_game, 'draw', 'agreement');
    else
      update public.games set draw_offer_by = auth.uid() where id = p_game;
    end if;
  end if;
  select * into g from public.games where id = p_game;
  return g;
end;
$$;

create function public.accept_draw(p_game uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games := public.lock_my_game(p_game);
begin
  if g.status = 'active' and not public.settle_clock(p_game) then
    if g.draw_offer_by is null or g.draw_offer_by = auth.uid() then
      raise exception 'NO_DRAW_OFFER';
    end if;
    perform public.finish_game(p_game, 'draw', 'agreement');
  end if;
  select * into g from public.games where id = p_game;
  return g;
end;
$$;

create function public.decline_draw(p_game uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games := public.lock_my_game(p_game);
begin
  update public.games set draw_offer_by = null
  where id = p_game and status = 'active' and draw_offer_by <> auth.uid();
  select * into g from public.games where id = p_game;
  return g;
end;
$$;

-- Ends a game without a result before both players have moved, or cancels
-- the caller's waiting invite.
create function public.abort(p_game uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games := public.lock_my_game(p_game);
begin
  if g.status = 'waiting' then
    perform public.abort_game(p_game, 'aborted');
  elsif g.status = 'active' and not public.settle_clock(p_game) then
    if g.ply >= 2 then
      raise exception 'CANNOT_ABORT';
    end if;
    perform public.abort_game(p_game, 'aborted');
  end if;
  select * into g from public.games where id = p_game;
  return g;
end;
$$;

-- Ends the game if the side to move has run out of time (or missed the
-- first-move deadline). Returns the game either way.
create function public.claim_timeout(p_game uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  g public.games := public.lock_my_game(p_game);
begin
  perform public.settle_clock(p_game);
  select * into g from public.games where id = p_game;
  return g;
end;
$$;

-- Privileges ----------------------------------------------------------------------

revoke execute on function public.require_uid() from public, anon, authenticated;
revoke execute on function public.check_time_control(int, int) from public, anon, authenticated;
revoke execute on function public.random_invite_code() from public, anon, authenticated;
revoke execute on function public.start_game(uuid, uuid, uuid) from public, anon, authenticated, service_role;
revoke execute on function public.lock_my_game(uuid) from public, anon, authenticated, service_role;

revoke execute on function public.set_profile(text, text) from public, anon;
revoke execute on function public.create_invite(int, int) from public, anon;
revoke execute on function public.join_invite(text) from public, anon;
revoke execute on function public.join_queue(int, int) from public, anon;
revoke execute on function public.leave_queue() from public, anon;
revoke execute on function public.resign(uuid) from public, anon;
revoke execute on function public.offer_draw(uuid) from public, anon;
revoke execute on function public.accept_draw(uuid) from public, anon;
revoke execute on function public.decline_draw(uuid) from public, anon;
revoke execute on function public.abort(uuid) from public, anon;
revoke execute on function public.claim_timeout(uuid) from public, anon;
grant execute on function public.set_profile(text, text), public.create_invite(int, int),
  public.join_invite(text), public.join_queue(int, int), public.leave_queue(),
  public.resign(uuid), public.offer_draw(uuid), public.accept_draw(uuid),
  public.decline_draw(uuid), public.abort(uuid), public.claim_timeout(uuid)
  to authenticated;
