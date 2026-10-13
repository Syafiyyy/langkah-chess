-- Advisor fixes (search_path, FK indexes, rating_history primary key).
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select is(
  (select proconfig from pg_proc where oid = 'public.first_move_seconds()'::regprocedure),
  array['search_path=""'], 'first_move_seconds has a fixed search_path');
select has_index('public', 'games', 'games_draw_offer_by_idx', array['draw_offer_by'],
  'games.draw_offer_by is indexed');
select has_index('public', 'moves', 'moves_played_by_idx', array['played_by'],
  'moves.played_by is indexed');
select col_is_pk('public', 'rating_history', array['game_id', 'user_id'],
  'rating_history has a primary key');

select * from finish();
rollback;
