-- The sweep aborts waiting invites older than 24 hours.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.dev');

insert into public.games (id, created_by, white_id, black_id, status, mode, time_base_ms,
                          white_ms, black_ms, invite_code, created_at, first_move_deadline)
values
  -- Waiting for 25 h: expires.
  ('eeeeeeee-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', null, null,
   'waiting', 'invite', 60000, 60000, 60000, 'OLDOLD', now() - interval '25 hours', null),
  -- Waiting for 23 h: stays.
  ('eeeeeeee-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', null, null,
   'waiting', 'invite', 60000, 60000, 60000, 'NEWNEW', now() - interval '23 hours', null),
  -- Created 25 h ago but joined and running: not an invite any more.
  ('eeeeeeee-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
   'active', 'invite', 60000, 60000, 60000, 'RUNRUN', now() - interval '25 hours',
   now() + interval '20 s');

select is(public.sweep_games(), 1, 'the sweep ends one game');
select results_eq(
  $$select id::text, status, termination from public.games
    where id::text like 'eeeeeeee%' order by id$$,
  $$values
    ('eeeeeeee-0000-0000-0000-000000000001', 'aborted', 'expired'),
    ('eeeeeeee-0000-0000-0000-000000000002', 'waiting', null),
    ('eeeeeeee-0000-0000-0000-000000000003', 'active', null)$$,
  'only the 24-hour-old waiting invite is aborted');
select is((select count(*)::int from public.rating_history), 0, 'expiry is not rated');

set local role authenticated;
select throws_ok($$select public.sweep_games()$$, '42501', null,
  'users still cannot run the sweep');
reset role;

select * from finish();
rollback;
