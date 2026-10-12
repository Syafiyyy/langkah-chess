-- Section 1: RLS and privileges.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

-- Three users: two players and a stranger. The signup trigger makes profiles.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'white@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'black@test.dev'),
  ('33333333-3333-3333-3333-333333333333', 'stranger@test.dev');

select is(
  (select username from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'u_111111111111',
  'signup trigger creates a profile with a temporary username'
);
select is(
  (select rating from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  1200,
  'new profiles start at 1200'
);

insert into public.games (id, created_by, white_id, black_id, status, mode,
                          time_base_ms, white_ms, black_ms)
values ('aaaaaaaa-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'active', 'invite', 300000, 300000, 300000);
insert into public.moves (game_id, ply, uci, san, fen_after, white_ms, black_ms,
                          client_move_id, played_by)
values ('aaaaaaaa-0000-0000-0000-000000000001', 1, 'e2e4', 'e4',
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        300000, 300000, gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111');
insert into public.matchmaking_queue (user_id, time_base_ms, increment_ms, rating)
values ('33333333-3333-3333-3333-333333333333', 300000, 0, 1200);
insert into public.rating_history (game_id, user_id, before, after)
values ('aaaaaaaa-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111', 1200, 1216);

-- anon: no grants at all.
set local role anon;
select throws_ok($$select * from public.games$$, '42501', null, 'anon cannot read games');
select throws_ok($$select * from public.profiles$$, '42501', null, 'anon cannot read profiles');

-- A player.
set local role authenticated;
set local request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select results_eq($$select count(*) from public.games$$, array[1::bigint], 'a player reads their game');
select results_eq($$select count(*) from public.moves$$, array[1::bigint], 'a player reads its moves');
select results_eq($$select count(*) from public.profiles$$, array[3::bigint], 'profiles are readable');
select is_empty($$select * from public.matchmaking_queue$$, 'a player does not see other queue rows');

-- Nobody writes directly, not even a player in the game.
select throws_ok($$update public.games set result = 'black'$$, '42501', null, 'player cannot update games');
select throws_ok(
  $$insert into public.moves (game_id, ply, uci, san, fen_after, white_ms, black_ms, client_move_id)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 2, 'e7e5', 'e5', 'x', 1, 1, gen_random_uuid())$$,
  '42501', null, 'player cannot insert moves');
select throws_ok($$delete from public.moves$$, '42501', null, 'player cannot delete moves');
select throws_ok(
  $$insert into public.games (mode, time_base_ms, white_ms, black_ms) values ('invite', 60000, 60000, 60000)$$,
  '42501', null, 'player cannot insert games');
select throws_ok($$update public.profiles set rating = 3000$$, '42501', null, 'player cannot change ratings');
select throws_ok(
  $$insert into public.matchmaking_queue (user_id, time_base_ms, increment_ms, rating)
    values ('22222222-2222-2222-2222-222222222222', 60000, 0, 1200)$$,
  '42501', null, 'player cannot insert into the queue');
select throws_ok(
  $$insert into public.rating_history (game_id, user_id, before, after)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 1, 2)$$,
  '42501', null, 'player cannot write rating history');

-- A stranger.
set local request.jwt.claims = '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';
select is_empty($$select * from public.games$$, 'a stranger cannot read the game');
select is_empty($$select * from public.moves$$, 'a stranger cannot read its moves');
select results_eq($$select count(*) from public.matchmaking_queue$$, array[1::bigint], 'a user reads their own queue row');

reset role;
select ok(
  (select relrowsecurity from pg_class where oid = 'public.games'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.moves'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.matchmaking_queue'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.rating_history'::regclass),
  'RLS is on for every table'
);
select is(
  (select string_agg(tablename::text, ',') from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'),
  'games',
  'only games is in the realtime publication'
);

select * from finish();
rollback;
