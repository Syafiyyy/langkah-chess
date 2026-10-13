-- Fixes from the Supabase advisors (2026-10-13).

-- Security: pin the search_path (function_search_path_mutable).
alter function public.first_move_seconds() set search_path = '';

-- Performance: these foreign keys are ON DELETE SET NULL, so deleting an
-- account scans them (unindexed_foreign_keys).
create index games_draw_offer_by_idx on public.games (draw_offer_by);
create index moves_played_by_idx on public.moves (played_by);

-- rating_history: the unique pair becomes the primary key (no_primary_key).
alter table public.rating_history
  drop constraint rating_history_game_id_user_id_key,
  add primary key (game_id, user_id);
