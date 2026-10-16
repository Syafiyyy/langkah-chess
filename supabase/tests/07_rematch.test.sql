-- offer_rematch: offer, see it from the other side, accept by offering.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.dev'),
  ('33333333-3333-3333-3333-333333333333', 'c@test.dev');

insert into public.games (id, created_by, white_id, black_id, status, mode, time_base_ms,
                          increment_ms, white_ms, black_ms, result, termination)
values
  ('ffffffff-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
   'finished', 'invite', 180000, 2000, 1000, 1000, 'white', 'resignation'),
  ('ffffffff-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
   'active', 'invite', 180000, 2000, 1000, 1000, null, null);

set local role authenticated;

-- A offers.
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);
create temp table offer on commit drop as
  select * from public.offer_rematch('ffffffff-0000-0000-0000-000000000001');
select is((select status from offer), 'waiting', 'an offer is a waiting invite');
select is((select (time_base_ms, increment_ms)::text from offer), '(180000,2000)',
  'with the same time control');
select is((select rematch_by::text from public.games where id = 'ffffffff-0000-0000-0000-000000000001'),
  '11111111-1111-1111-1111-111111111111', 'the old game records who offered');
select is((select id from public.offer_rematch('ffffffff-0000-0000-0000-000000000001')),
  (select id from offer), 'offering again returns the same invite');
select throws_ok($$select public.offer_rematch('ffffffff-0000-0000-0000-000000000002')$$,
  'P0001', 'NOT_FINISHED', 'no rematch while the game runs');

-- B sees the code on the old game and accepts by offering.
select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
select is((select rematch_code from public.games where id = 'ffffffff-0000-0000-0000-000000000001'),
  (select invite_code from offer), 'the opponent can read the rematch code');
create temp table accepted on commit drop as
  select * from public.offer_rematch('ffffffff-0000-0000-0000-000000000001');
select is((select id from accepted), (select id from offer), 'accepting joins the offered game');
select is((select status from accepted), 'active', 'the rematch starts');
select ok((select array[white_id, black_id] @> array[
  '11111111-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid]
  from accepted), 'between the same two players');

-- C is not a player.
select set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333"}', true);
select throws_ok($$select public.offer_rematch('ffffffff-0000-0000-0000-000000000001')$$,
  'P0001', 'NOT_A_PLAYER', 'others cannot offer');

reset role;

-- An expired offer is replaced by a fresh one from whoever offers next.
update public.games set status = 'aborted', termination = 'expired' where id = (select id from offer);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);
select is((select status from public.offer_rematch('ffffffff-0000-0000-0000-000000000001')),
  'waiting', 'a dead offer is replaced by a new invite');
select is((select rematch_by::text from public.games where id = 'ffffffff-0000-0000-0000-000000000001'),
  '22222222-2222-2222-2222-222222222222', 'now offered by the other player');
reset role;

select * from finish();
rollback;
