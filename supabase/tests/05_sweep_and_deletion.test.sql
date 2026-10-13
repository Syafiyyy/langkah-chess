-- Section 4: sweep_games (pg_cron) and prepare_account_deletion.
begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.dev'),
  ('33333333-3333-3333-3333-333333333333', 'c@test.dev');

-- Sweep fixtures (A white, B black, 1+0).
insert into public.games (id, white_id, black_id, status, mode, time_base_ms, increment_ms,
                          ply, white_ms, black_ms, last_move_at, first_move_deadline,
                          white_can_mate, black_can_mate)
values
  -- S1: nobody moved, deadline passed.
  ('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 0, 60000, 60000,
   null, now() - interval '1 s', true, true),
  -- S2: white moved, black missed the deadline.
  ('bbbbbbbb-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 1, 60000, 60000,
   now() - interval '31 s', now() - interval '1 s', true, true),
  -- S3: deadline still ahead.
  ('bbbbbbbb-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 0, 60000, 60000,
   null, now() + interval '20 s', true, true),
  -- S4: black to move, flagged; white can mate.
  ('bbbbbbbb-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 5, 60000, 1000,
   now() - interval '5 s', null, true, true),
  -- S5: white to move, flagged; black has no mating material.
  ('bbbbbbbb-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 4, 1000, 60000,
   now() - interval '5 s', null, true, false),
  -- S6: time left.
  ('bbbbbbbb-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 4, 60000, 60000,
   now() - interval '5 s', null, true, true);
-- S7: finished long ago, would look flagged.
insert into public.games (id, white_id, black_id, status, mode, time_base_ms, ply, white_ms,
                          black_ms, last_move_at, result, termination, finished_at)
values ('bbbbbbbb-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222', 'finished', 'invite', 60000, 4, 1000, 60000,
        now() - interval '1 day', 'white', 'checkmate', now() - interval '1 day');

insert into public.matchmaking_queue (user_id, time_base_ms, increment_ms, rating, seen_at) values
  ('11111111-1111-1111-1111-111111111111', 60000, 0, 1200, now() - interval '3 min'),
  ('22222222-2222-2222-2222-222222222222', 60000, 0, 1200, now() - interval '30 s');

-- Privileges --------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
select throws_ok($$select public.sweep_games()$$, '42501', null,
  'users cannot run the sweep');
select throws_ok($$select public.prepare_account_deletion('11111111-1111-1111-1111-111111111111')$$,
  '42501', null, 'users cannot call prepare_account_deletion');
reset role;
set local role service_role;
select throws_ok($$select public.sweep_games()$$, '42501', null,
  'service_role cannot run the sweep either (cron runs it as postgres)');
reset role;

-- Sweep ----------------------------------------------------------------------------
select is(public.sweep_games(), 4, 'the sweep settles four games');
select results_eq(
  $$select id::text, status, result, termination from public.games
    where id::text like 'bbbbbbbb%' order by id$$,
  $$values
    ('bbbbbbbb-0000-0000-0000-000000000001', 'aborted', null, 'firstMoveTimeout'),
    ('bbbbbbbb-0000-0000-0000-000000000002', 'aborted', null, 'firstMoveTimeout'),
    ('bbbbbbbb-0000-0000-0000-000000000003', 'active', null, null),
    ('bbbbbbbb-0000-0000-0000-000000000004', 'finished', 'white', 'timeout'),
    ('bbbbbbbb-0000-0000-0000-000000000005', 'finished', 'draw', 'timeout'),
    ('bbbbbbbb-0000-0000-0000-000000000006', 'active', null, null),
    ('bbbbbbbb-0000-0000-0000-000000000007', 'finished', 'white', 'checkmate')$$,
  'deadlines abort, flags finish (draw without mating material), the rest is untouched');
select is((select count(*)::int from public.rating_history
           where game_id in ('bbbbbbbb-0000-0000-0000-000000000004',
                             'bbbbbbbb-0000-0000-0000-000000000005')), 4,
  'swept timeouts are rated');
select is((select count(*)::int from public.rating_history
           where game_id in ('bbbbbbbb-0000-0000-0000-000000000001',
                             'bbbbbbbb-0000-0000-0000-000000000002')), 0,
  'aborted games are not rated');
select is(array(select user_id from public.matchmaking_queue),
  array['22222222-2222-2222-2222-222222222222'::uuid],
  'queue entries not seen for 2 minutes are removed');
select is(public.sweep_games(), 0, 'a second sweep finds nothing');

-- Cron ------------------------------------------------------------------------------
select is((select schedule from cron.job where jobname = 'skak-sweep'), '* * * * *',
  'the sweep runs every minute');
select is((select command from cron.job where jobname = 'skak-sweep'),
  'select public.sweep_games()', 'the cron job calls sweep_games');

-- Account deletion -------------------------------------------------------------------
-- A plays: D1 (vs B, ply 4, A white), D2 (A's waiting invite), D3 (vs C, nobody
-- moved), D4 (finished vs C). A is queued.
insert into public.games (id, created_by, white_id, black_id, status, mode, time_base_ms,
                          ply, white_ms, black_ms, last_move_at, invite_code)
values
  ('dddddddd-0000-0000-0000-000000000001', null, '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'matchmaking', 60000, 4, 60000, 60000,
   now(), null),
  ('dddddddd-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', null, null,
   'waiting', 'invite', 60000, 0, 60000, 60000, null, 'ABCDEF'),
  ('dddddddd-0000-0000-0000-000000000003', null, '33333333-3333-3333-3333-333333333333',
   '11111111-1111-1111-1111-111111111111', 'active', 'matchmaking', 60000, 0, 60000, 60000,
   null, null);
insert into public.games (id, white_id, black_id, status, mode, time_base_ms, ply, white_ms,
                          black_ms, result, termination, finished_at)
values ('dddddddd-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
        '33333333-3333-3333-3333-333333333333', 'finished', 'matchmaking', 60000, 30, 1000, 1000,
        'black', 'resignation', now() - interval '1 day');
insert into public.moves (game_id, ply, uci, san, fen_after, white_ms, black_ms,
                          client_move_id, played_by)
values ('dddddddd-0000-0000-0000-000000000001', 1, 'e2e4', 'e4', 'x', 60000, 60000,
        gen_random_uuid(), '11111111-1111-1111-1111-111111111111');
insert into public.matchmaking_queue (user_id, time_base_ms, increment_ms, rating)
values ('11111111-1111-1111-1111-111111111111', 60000, 0, 1200);

set local role service_role;
select lives_ok($$select public.prepare_account_deletion('11111111-1111-1111-1111-111111111111')$$,
  'service_role prepares the deletion');
select lives_ok($$select public.prepare_account_deletion('11111111-1111-1111-1111-111111111111')$$,
  'preparing twice is harmless');
reset role;
select results_eq(
  $$select id::text, status, result, termination from public.games
    where id::text like 'dddddddd%' order by id$$,
  $$values
    ('dddddddd-0000-0000-0000-000000000001', 'finished', 'black', 'resignation'),
    ('dddddddd-0000-0000-0000-000000000002', 'aborted', null, 'aborted'),
    ('dddddddd-0000-0000-0000-000000000003', 'aborted', null, 'aborted'),
    ('dddddddd-0000-0000-0000-000000000004', 'finished', 'black', 'resignation')$$,
  'running games are resigned, unstarted ones aborted, finished ones untouched');
select is((select count(*)::int from public.rating_history
           where game_id = 'dddddddd-0000-0000-0000-000000000001'), 2,
  'the opponent gets the win on their rating');
select is((select count(*)::int from public.matchmaking_queue
           where user_id = '11111111-1111-1111-1111-111111111111'), 0,
  'the queue entry is removed');

-- The Edge Function then deletes the auth user.
delete from auth.users where id = '11111111-1111-1111-1111-111111111111';
select is((select count(*)::int from public.profiles
           where id = '11111111-1111-1111-1111-111111111111'), 0, 'the profile is gone');
select is((select count(*)::int from public.rating_history
           where user_id = '11111111-1111-1111-1111-111111111111'), 0,
  'their rating history is gone');
select ok((select count(*) > 0 from public.rating_history
           where user_id = '22222222-2222-2222-2222-222222222222'),
  'opponents keep their rating history');
select results_eq(
  $$select white_id, black_id from public.games where id = 'dddddddd-0000-0000-0000-000000000001'$$,
  $$values (null::uuid, '22222222-2222-2222-2222-222222222222'::uuid)$$,
  'games stay for the opponent, the deleted player becomes null');
select is((select played_by from public.moves
           where game_id = 'dddddddd-0000-0000-0000-000000000001' and ply = 1), null,
  'their moves stay without the player');
select is((select created_by from public.games where id = 'dddddddd-0000-0000-0000-000000000002'),
  null, 'their invites lose the creator');
select is((select count(*)::int from public.games where id::text like 'dddddddd%'), 4,
  'no game is deleted');

select * from finish();
rollback;
