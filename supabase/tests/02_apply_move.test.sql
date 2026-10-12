-- Section 2: apply_move and finish_game.
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'white@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'black@test.dev');

-- Game A: 5+3, active, nobody moved yet.
insert into public.games (id, white_id, black_id, status, mode, time_base_ms,
                          increment_ms, white_ms, black_ms, first_move_deadline)
values ('aaaaaaaa-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'active', 'invite', 300000, 3000, 300000, 300000, now() + interval '30 s');

-- Privileges.
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select throws_ok(
  $$select public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 1, 'e2e4', 'e4', 'f1',
      null, null, gen_random_uuid(), '11111111-1111-1111-1111-111111111111', true, true)$$,
  '42501', null, 'authenticated users cannot call apply_move');
select throws_ok(
  $$select public.finish_game('aaaaaaaa-0000-0000-0000-000000000001', 'white', 'x')$$,
  '42501', null, 'authenticated users cannot call finish_game');
reset role;
set local role service_role;
select throws_ok(
  $$select public.finish_game('aaaaaaaa-0000-0000-0000-000000000001', 'white', 'x')$$,
  '42501', null, 'service_role cannot call finish_game directly');

-- White's first move: no clock charge, no increment, black gets a deadline.
select is(
  (select ply from public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 1, 'e2e4', 'e4', 'fen1',
      null, null, 'c0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', true, true)),
  1, 'first move applied');
reset role;
select results_eq(
  $$select white_ms, black_ms, fen from public.games where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values (300000, 300000, 'fen1')$$,
  'first moves cost no time and get no increment');
select ok(
  (select first_move_deadline > now() from public.games where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'black gets a first-move deadline');

set local role service_role;
-- Retry with the same client_move_id returns the game, no second move.
select is(
  (select ply from public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 1, 'e2e4', 'e4', 'fen1',
      null, null, 'c0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', true, true)),
  1, 'retry returns the same state');
select is((select count(*)::int from public.moves), 1, 'retry does not duplicate the move');
select throws_ok(
  $$select public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 2, 'e7e5', 'e5', 'fen2',
      null, null, 'c0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', true, true)$$,
  'P0001', 'DUPLICATE_MOVE_ID', 'a reused id from another player is rejected');

-- Wrong turn and stale ply.
select throws_ok(
  $$select public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 2, 'd2d4', 'd4', 'x',
      null, null, gen_random_uuid(), '11111111-1111-1111-1111-111111111111', true, true)$$,
  'P0001', 'NOT_YOUR_TURN', 'white cannot move twice');
select throws_ok(
  $$select public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 1, 'e7e5', 'e5', 'x',
      null, null, gen_random_uuid(), '22222222-2222-2222-2222-222222222222', true, true)$$,
  'P0001', 'STALE', 'an old ply is stale');
select throws_ok(
  $$select public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 3, 'e7e5', 'e5', 'x',
      null, null, gen_random_uuid(), '22222222-2222-2222-2222-222222222222', true, true)$$,
  'P0001', 'STALE', 'a future ply is stale');
select throws_ok(
  $$select public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 2, 'e7e5', 'e5', 'x',
      null, null, gen_random_uuid(), '33333333-3333-3333-3333-333333333333', true, true)$$,
  'P0001', 'NOT_A_PLAYER', 'a stranger cannot move');

-- Black's first move: still free; clocks start now.
select is(
  (select ply from public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 2, 'e7e5', 'e5', 'fen2',
      null, null, gen_random_uuid(), '22222222-2222-2222-2222-222222222222', true, true)),
  2, 'second move applied');
reset role;
select results_eq(
  $$select white_ms, black_ms, first_move_deadline is null from public.games
    where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values (300000, 300000, true)$$,
  'after both first moves: full clocks, no deadline');

-- White thinks 10.5 s: 300000 - 10500 + 3000 increment.
update public.games set last_move_at = now() - interval '10.5 s'
where id = 'aaaaaaaa-0000-0000-0000-000000000001';
set local role service_role;
select is(
  (select white_ms from public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 3, 'g1f3', 'Nf3', 'fen3',
      null, null, gen_random_uuid(), '11111111-1111-1111-1111-111111111111', true, true)),
  292500, 'mover is charged the elapsed time plus increment');
reset role;
select results_eq(
  $$select white_ms, black_ms from public.moves
    where game_id = 'aaaaaaaa-0000-0000-0000-000000000001' and ply = 3$$,
  $$values (292500, 300000)$$,
  'the move row stores the clocks after the move');

-- A pending draw offer is cleared by a move.
update public.games set draw_offer_by = '11111111-1111-1111-1111-111111111111'
where id = 'aaaaaaaa-0000-0000-0000-000000000001';
set local role service_role;
select is(
  (select draw_offer_by from public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 4, 'b8c6', 'Nc6', 'fen4',
      null, null, gen_random_uuid(), '22222222-2222-2222-2222-222222222222', true, true)),
  null, 'a move clears the draw offer');
reset role;

-- Timeout: white's clock ran out before this move. Black has material → black wins.
update public.games set last_move_at = now() - interval '293 s'
where id = 'aaaaaaaa-0000-0000-0000-000000000001';
set local role service_role;
select results_eq(
  $$select ply, status, result, termination, white_ms from public.apply_move(
      'aaaaaaaa-0000-0000-0000-000000000001', 5, 'f1c4', 'Bc4', 'fen5',
      null, null, gen_random_uuid(), '11111111-1111-1111-1111-111111111111', true, true)$$,
  $$values (4, 'finished', 'black', 'timeout', 0)$$,
  'a move after the flag ends the game on time without the move');
reset role;
select is((select count(*)::int from public.moves where ply = 5), 0, 'the late move is not stored');

-- Rating: equal 1200s, both new (K=32): black +16, white -16, once.
select results_eq(
  $$select rating, games_played from public.profiles order by id$$,
  $$values (1184, 1), (1216, 1)$$,
  'Elo applied to both players');
select is((select count(*)::int from public.rating_history), 2, 'two rating history rows');
select public.finish_game('aaaaaaaa-0000-0000-0000-000000000001', 'white', 'resignation');
select results_eq(
  $$select rating, games_played from public.profiles order by id$$,
  $$values (1184, 1), (1216, 1)$$,
  'finish_game called again changes nothing');
select is(
  (select result from public.games where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'black', 'the first result stands');
set local role service_role;
select throws_ok(
  $$select public.apply_move('aaaaaaaa-0000-0000-0000-000000000001', 5, 'f1c4', 'Bc4', 'x',
      null, null, gen_random_uuid(), '11111111-1111-1111-1111-111111111111', true, true)$$,
  'P0001', 'GAME_OVER', 'no moves after the game ended');
reset role;

-- Game B: timeout while the opponent has no mating material → draw.
insert into public.games (id, white_id, black_id, status, mode, time_base_ms,
                          white_ms, black_ms, ply, last_move_at, black_can_mate)
values ('bbbbbbbb-0000-0000-0000-000000000002',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'active', 'invite', 60000, 1000, 5000, 40, now() - interval '2 s', false);
set local role service_role;
select results_eq(
  $$select status, result, termination from public.apply_move(
      'bbbbbbbb-0000-0000-0000-000000000002', 41, 'e1e2', 'Ke2', 'x',
      null, null, gen_random_uuid(), '11111111-1111-1111-1111-111111111111', true, false)$$,
  $$values ('finished', 'draw', 'timeout')$$,
  'timeout vs insufficient material is a draw');
reset role;

-- Game C: a mating move finishes the game with the given result.
insert into public.games (id, white_id, black_id, status, mode, time_base_ms,
                          white_ms, black_ms, ply, last_move_at)
values ('cccccccc-0000-0000-0000-000000000003',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'active', 'invite', 60000, 60000, 60000, 3, now());
set local role service_role;
select results_eq(
  $$select ply, status, result, termination from public.apply_move(
      'cccccccc-0000-0000-0000-000000000003', 4, 'd8h4', 'Qh4#', 'matefen',
      'black', 'checkmate', gen_random_uuid(), '22222222-2222-2222-2222-222222222222', true, true)$$,
  $$values (4, 'finished', 'black', 'checkmate')$$,
  'a result from make_move finishes the game');
reset role;
select is(
  (select fen from public.games where id = 'cccccccc-0000-0000-0000-000000000003'),
  'matefen', 'the final move is stored');

-- Game D: white missed the first-move deadline → aborted, no rating.
insert into public.games (id, white_id, black_id, status, mode, time_base_ms,
                          white_ms, black_ms, first_move_deadline)
values ('dddddddd-0000-0000-0000-000000000004',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'active', 'invite', 60000, 60000, 60000, now() - interval '1 s');
set local role service_role;
select results_eq(
  $$select ply, status, termination from public.apply_move(
      'dddddddd-0000-0000-0000-000000000004', 1, 'e2e4', 'e4', 'x',
      null, null, gen_random_uuid(), '11111111-1111-1111-1111-111111111111', true, true)$$,
  $$values (0, 'aborted', 'firstMoveTimeout')$$,
  'a first move after the deadline aborts the game');
reset role;
select is(
  (select count(*)::int from public.rating_history where game_id = 'dddddddd-0000-0000-0000-000000000004'),
  0, 'aborted games are not rated');

-- Elo with unequal ratings and the K switch at 30 games.
update public.profiles set rating = 1500, games_played = 30 where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set rating = 1300, games_played = 5 where id = '22222222-2222-2222-2222-222222222222';
insert into public.games (id, white_id, black_id, status, mode, time_base_ms, white_ms, black_ms, ply)
values ('eeeeeeee-0000-0000-0000-000000000005',
        '11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222',
        'active', 'invite', 60000, 60000, 60000, 10);
select public.finish_game('eeeeeeee-0000-0000-0000-000000000005', 'draw', 'agreement');
-- Expected for 1500 vs 1300: 0.7597. White K=20: 1500 + 20*(0.5-0.7597) = 1494.8 → 1495.
-- Black K=32: 1300 + 32*(0.5-0.2403) = 1308.3 → 1308.
select results_eq(
  $$select rating from public.profiles order by id$$,
  $$values (1495), (1308)$$,
  'Elo uses K=20 from 30 games and K=32 before');

select * from finish();
rollback;
