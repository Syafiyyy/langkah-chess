-- F2a section 1: online schema + RLS.
-- Clients only SELECT. Every write goes through SECURITY DEFINER functions
-- (later migrations) or the make_move Edge Function (ADR-0004).

-- Profiles ------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique
    check (username ~ '^[a-z0-9_]{3,20}$'),
  username_set boolean not null default false,
  avatar text,
  rating int not null default 1200,
  games_played int not null default 0,
  created_at timestamptz not null default now()
);

-- A row for every new user, with a temporary username ("u_" + 12 hex chars)
-- until they pick one with set_profile.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, 'u_' || substr(replace(new.id::text, '-', ''), 1, 12));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Games ---------------------------------------------------------------------

create table public.games (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.profiles (id) on delete set null,
  white_id uuid references public.profiles (id) on delete set null,
  black_id uuid references public.profiles (id) on delete set null,
  status text not null default 'waiting'
    check (status in ('waiting', 'active', 'finished', 'aborted')),
  mode text not null check (mode in ('invite', 'matchmaking')),
  time_base_ms int not null check (time_base_ms between 60000 and 3600000),
  increment_ms int not null default 0 check (increment_ms between 0 and 60000),
  fen text not null
    default 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  ply int not null default 0 check (ply >= 0),
  white_ms int not null,
  black_ms int not null,
  -- Mating material per side after the last move (computed by make_move).
  -- Used to turn a timeout into a draw without chess code in SQL.
  white_can_mate boolean not null default true,
  black_can_mate boolean not null default true,
  last_move_at timestamptz,
  first_move_deadline timestamptz,
  result text check (result in ('white', 'black', 'draw')),
  termination text,
  invite_code text unique,
  draw_offer_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create index games_white_idx on public.games (white_id);
create index games_black_idx on public.games (black_id);
create index games_created_by_idx on public.games (created_by);
create index games_active_idx on public.games (status)
  where status in ('waiting', 'active');

-- Moves ---------------------------------------------------------------------

create table public.moves (
  game_id uuid not null references public.games (id) on delete cascade,
  ply int not null check (ply >= 1),
  uci text not null check (uci ~ '^[a-h][1-8][a-h][1-8][qrbn]?$'),
  san text not null,
  fen_after text not null,
  white_ms int not null,
  black_ms int not null,
  client_move_id uuid not null unique,
  played_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (game_id, ply)
);

-- Matchmaking queue -----------------------------------------------------------

create table public.matchmaking_queue (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  time_base_ms int not null,
  increment_ms int not null,
  rating int not null,
  created_at timestamptz not null default now()
);

create index matchmaking_queue_tc_idx
  on public.matchmaking_queue (time_base_ms, increment_ms, created_at);

-- Rating history ----------------------------------------------------------------

create table public.rating_history (
  game_id uuid not null references public.games (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  before int not null,
  after int not null,
  created_at timestamptz not null default now(),
  unique (game_id, user_id)
);

create index rating_history_user_idx on public.rating_history (user_id);

-- Privileges: read-only for signed-in users, nothing for anon ----------------

revoke all on public.profiles, public.games, public.moves,
  public.matchmaking_queue, public.rating_history from anon, authenticated;
grant select on public.profiles, public.games, public.moves,
  public.matchmaking_queue, public.rating_history to authenticated;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- RLS -----------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.games enable row level security;
alter table public.moves enable row level security;
alter table public.matchmaking_queue enable row level security;
alter table public.rating_history enable row level security;

create policy "profiles are readable by signed-in users"
  on public.profiles for select to authenticated
  using (true);

create policy "players read their own games"
  on public.games for select to authenticated
  using ((select auth.uid()) in (white_id, black_id, created_by));

create policy "players read the moves of their games"
  on public.moves for select to authenticated
  using (exists (
    select 1 from public.games g
    where g.id = game_id
      and (select auth.uid()) in (g.white_id, g.black_id, g.created_by)
  ));

create policy "users read their own queue entry"
  on public.matchmaking_queue for select to authenticated
  using (user_id = (select auth.uid()));

create policy "rating history is readable by signed-in users"
  on public.rating_history for select to authenticated
  using (true);

-- Realtime: games only (a "something changed" hint, ADR-0005) ---------------

alter publication supabase_realtime add table public.games;
