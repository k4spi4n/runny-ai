-- Hỗ trợ tự động nhập hoạt động từ Strava (webhook + đồng bộ thủ công).
-- - source: nguồn hoạt động ('manual' | 'strava' | ...).
-- - strava_activity_id: id hoạt động bên Strava, dùng để chống nhập trùng.
alter table public.activities
  add column if not exists source text not null default 'manual',
  add column if not exists strava_activity_id bigint;

-- Mỗi hoạt động Strava chỉ được nhập một lần cho mỗi người dùng.
-- Index KHÔNG dùng partial WHERE để PostgREST/upsert suy luận được ON CONFLICT.
-- Hoạt động thủ công có strava_activity_id = NULL; NULL là phân biệt trong unique
-- index (NULLS DISTINCT) nên vẫn cho phép nhiều hoạt động thủ công mỗi người.
create unique index if not exists activities_user_strava_activity_uidx
  on public.activities (user_id, strava_activity_id);

-- Webhook tra cứu người dùng theo Strava athlete id (owner_id) -> đánh index.
create index if not exists profiles_strava_id_idx
  on public.profiles (strava_id)
  where strava_id is not null;
