-- Section 3: RPCs for signed-in users.
begin;
create extension if not exists pgtap with schema extensions;
select plan(53);

-- A, B, C, D: players. Temp table keeps ids between role switches.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.dev'),
  ('33333333-3333-3333-3333-333333333333', 'c@test.dev'),
  ('44444444-4444-4444-4444-444444444444', 'd@test.dev');
create temp table ids (k text primary key, id uuid, code text);
grant all on ids to authenticated;

-- Fixed games for the game actions (A white, B black, 1+0).
insert into public.games (id, white_id, black_id, status, mode, time_base_ms,
                          increment_ms, ply, white_ms, black_ms, last_move_at)
values
  -- G2, G3, G6: four plies in, plenty of time, white to move.
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 4, 60000, 60000, now()),
  ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 4, 60000, 60000, now()),
  ('aaaaaaaa-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 4, 60000, 60000, now()),
  -- G4, G5: white to move with 1 s left, last move 5 s ago (flagged).
  ('aaaaaaaa-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 4, 1000, 60000,
   now() - interval '5 s'),
  ('aaaaaaaa-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111',
   '22222222-2222-2222-2222-222222222222', 'active', 'invite', 60000, 0, 4, 1000, 60000,
   now() - interval '5 s');

-- Privileges --------------------------------------------------------------------
set local role anon;
select throws_ok($$select public.set_profile('anon_user', null)$$, '42501', null,
  'anon cannot call set_profile');
select throws_ok($$select public.create_invite(60000, 0)$$, '42501', null,
  'anon cannot call create_invite');
select throws_ok($$select public.join_queue(60000, 0)$$, '42501', null,
  'anon cannot call join_queue');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role": "authenticated"}', true);
select throws_ok($$select public.create_invite(60000, 0)$$, 'P0001', 'NOT_SIGNED_IN',
  'a token without a user is rejected');
select throws_ok($$select public.settle_clock('aaaaaaaa-0000-0000-0000-000000000002')$$,
  '42501', null, 'internal helpers are not callable');

-- set_profile -------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
select results_eq($$select username, username_set from public.set_profile('alice', null)$$,
  $$values ('alice'::text, true)$$, 'A picks a username');
select lives_ok($$select public.set_profile('alice', null)$$, 'setting the same name again is fine');
select throws_ok($$select public.set_profile('alice2', null)$$, 'P0001', 'USERNAME_LOCKED',
  'the username can only be set once');
select results_eq($$select username, avatar from public.set_profile(null, 'fox')$$,
  $$values ('alice'::text, 'fox'::text)$$, 'the avatar can change any time');

select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
select throws_ok($$select public.set_profile('alice', null)$$, 'P0001', 'USERNAME_TAKEN',
  'a taken username is rejected');
select throws_ok($$select public.set_profile('Bad Name', null)$$, 'P0001', 'BAD_USERNAME',
  'an invalid username is rejected');
select throws_ok($$select public.set_profile('u_abcdef123456', null)$$, 'P0001', 'BAD_USERNAME',
  'temporary-style usernames are reserved');
select throws_ok($$select public.set_profile(null, 'x y')$$, 'P0001', 'BAD_AVATAR',
  'an invalid avatar key is rejected');
select is((select username_set from public.profiles where id = '22222222-2222-2222-2222-222222222222'),
  false, 'failed attempts leave the profile unchanged');

-- create_invite / join_invite -----------------------------------------------------
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
insert into ids select 'invite', id, invite_code from public.create_invite(300000, 3000);
select results_eq(
  $$select status, mode, created_by, white_ms, black_ms, white_id, black_id
    from public.games where id = (select id from ids where k = 'invite')$$,
  $$values ('waiting'::text, 'invite'::text, '11111111-1111-1111-1111-111111111111'::uuid,
            300000, 300000, null::uuid, null::uuid)$$,
  'create_invite makes a waiting game');
select matches((select code from ids where k = 'invite'), '^[A-HJ-NP-Z2-9]{6}$',
  'invite code is 6 unambiguous characters');
select is((select id from public.create_invite(300000, 3000)), (select id from ids where k = 'invite'),
  'creating the same invite again returns the waiting one');
select throws_ok($$select public.create_invite(1000, 0)$$, 'P0001', 'BAD_TIME_CONTROL',
  'an invalid time control is rejected');
select throws_ok($$select public.join_invite((select code from ids where k = 'invite'))$$,
  'P0001', 'OWN_GAME', 'you cannot join your own invite');

select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
select throws_ok($$select public.join_invite('ZZZZZZ')$$, 'P0001', 'NOT_FOUND',
  'an unknown code is rejected');
select is((select status from public.join_invite((select lower(code) from ids where k = 'invite'))),
  'active', 'B joins with the code in any case');
select results_eq(
  $$select array[white_id, black_id] @> array['11111111-1111-1111-1111-111111111111'::uuid,
                                              '22222222-2222-2222-2222-222222222222'::uuid],
           first_move_deadline > now()
    from public.games where id = (select id from ids where k = 'invite')$$,
  $$values (true, true)$$, 'both players get a colour and a first-move deadline');
select is((select id from public.join_invite((select code from ids where k = 'invite'))),
  (select id from ids where k = 'invite'), 'joining again returns the same game');

select set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333"}', true);
select throws_ok($$select public.join_invite((select code from ids where k = 'invite'))$$,
  'P0001', 'NOT_AVAILABLE', 'a third user cannot join a started game');

-- join_queue / leave_queue -----------------------------------------------------
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
select is((select count(*)::int from public.join_queue(180000, 0)), 0, 'A waits in the queue');
reset role;
update public.matchmaking_queue
set created_at = now() - interval '1 min', seen_at = now() - interval '1 min';
set local role authenticated;
select is((select count(*)::int from public.join_queue(180000, 0)), 0, 'queueing again is fine');
reset role;
select results_eq($$select created_at < now(), seen_at = now() from public.matchmaking_queue$$,
  $$values (true, true)$$, 'queueing again keeps the place in line and refreshes seen_at');
set local role authenticated;
select is((select count(*)::int from public.matchmaking_queue), 1, 'A is queued once');
select throws_ok($$select public.join_queue(180000, 99999999)$$, 'P0001', 'BAD_TIME_CONTROL',
  'queueing with an invalid time control is rejected');

select set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333"}', true);
select is((select count(*)::int from public.join_queue(180000, 2000)), 0,
  'C waits for a different time control');

select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
insert into ids select 'queued', id, null from public.join_queue(180000, 0);
reset role;
select results_eq(
  $$select mode, status, created_by, array[white_id, black_id] @> array[
      '11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid],
      time_base_ms, white_ms
    from public.games where id = (select id from ids where k = 'queued')$$,
  $$values ('matchmaking'::text, 'active'::text, null::uuid, true, 180000, 180000)$$,
  'B is paired with A');
select is(array(select user_id from public.matchmaking_queue),
  array['33333333-3333-3333-3333-333333333333'::uuid], 'A and B left the queue, C waits');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
select is((select id from public.join_queue(180000, 0)), (select id from ids where k = 'queued'),
  'A learns about the pairing by calling join_queue again');

select set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333"}', true);
select lives_ok($$select public.leave_queue()$$, 'C leaves the queue');
reset role;
select is((select count(*)::int from public.matchmaking_queue), 0, 'the queue is empty');
set local role authenticated;

-- abort --------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333"}', true);
select throws_ok($$select public.resign((select id from ids where k = 'invite'))$$,
  'P0001', 'NOT_A_PLAYER', 'a stranger cannot resign');
select throws_ok($$select public.resign('aaaaaaaa-0000-0000-0000-0000000000ff')$$,
  'P0001', 'NOT_FOUND', 'an unknown game is rejected');

select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
select results_eq($$select status, termination from public.abort((select id from ids where k = 'invite'))$$,
  $$values ('aborted'::text, 'aborted'::text)$$, 'a game can be aborted before both moved');
select is((select status from public.abort((select id from ids where k = 'invite'))), 'aborted',
  'aborting again is harmless');

select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
select throws_ok($$select public.abort('aaaaaaaa-0000-0000-0000-000000000003')$$,
  'P0001', 'CANNOT_ABORT', 'no abort once both players moved');
insert into ids select 'waiting', id, null from public.create_invite(60000, 0);
select is((select status from public.abort((select id from ids where k = 'waiting'))), 'aborted',
  'the creator can cancel a waiting invite');

-- Draws ----------------------------------------------------------------------------------
select is((select draw_offer_by from public.offer_draw('aaaaaaaa-0000-0000-0000-000000000002')),
  '11111111-1111-1111-1111-111111111111'::uuid, 'A offers a draw');
select throws_ok($$select public.accept_draw('aaaaaaaa-0000-0000-0000-000000000002')$$,
  'P0001', 'NO_DRAW_OFFER', 'you cannot accept your own offer');
select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
select is((select draw_offer_by from public.decline_draw('aaaaaaaa-0000-0000-0000-000000000002')),
  null, 'B declines');
select is((select draw_offer_by from public.offer_draw('aaaaaaaa-0000-0000-0000-000000000002')),
  '22222222-2222-2222-2222-222222222222'::uuid, 'B offers a draw');
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
select results_eq($$select status, result, termination
                    from public.accept_draw('aaaaaaaa-0000-0000-0000-000000000002')$$,
  $$values ('finished'::text, 'draw'::text, 'agreement'::text)$$, 'A accepts: draw by agreement');

-- Resign ---------------------------------------------------------------------------------
select results_eq($$select result, termination from public.resign('aaaaaaaa-0000-0000-0000-000000000003')$$,
  $$values ('black'::text, 'resignation'::text)$$, 'white resigns: black wins');
select is((select result from public.resign('aaaaaaaa-0000-0000-0000-000000000003')), 'black',
  'resigning again is harmless');
select is((select draw_offer_by from public.offer_draw('aaaaaaaa-0000-0000-0000-000000000003')),
  null, 'no draw offers on a finished game');
reset role;
select is((select count(*)::int from public.rating_history
           where game_id = 'aaaaaaaa-0000-0000-0000-000000000003'), 2, 'the resignation is rated');
set local role authenticated;

-- Clocks ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
select results_eq($$select status, result, termination, white_ms
                    from public.claim_timeout('aaaaaaaa-0000-0000-0000-000000000004')$$,
  $$values ('finished'::text, 'black'::text, 'timeout'::text, 0)$$, 'B claims: white flagged');
select is((select status from public.claim_timeout('aaaaaaaa-0000-0000-0000-000000000006')),
  'active', 'no timeout while time is left');

select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
select is((select termination from public.resign('aaaaaaaa-0000-0000-0000-000000000005')), 'timeout',
  'a flag beats a late resignation');

select * from finish();
rollback;
