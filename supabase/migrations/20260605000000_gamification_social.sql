-- =====================================================================
-- Phân hệ 4: Động lực & Tương tác (Gamification & Social)
--   4.1 Huy hiệu Thành tích (Badges) - cấp tự động
--   4.2 Bảng xếp hạng (Leaderboard) - thi đua tổng quãng đường
--   4.3 Kết nối Cộng đồng - ghép đôi bạn chạy (Matching)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 HUY HIỆU THÀNH TÍCH
-- ---------------------------------------------------------------------

-- Danh mục (catalog) các huy hiệu có thể đạt được.
create table if not exists public.badge_definitions (
  code text primary key,
  name text not null,
  description text not null,
  icon text not null default 'emoji_events',
  -- Cách tính điều kiện đạt huy hiệu:
  --   total_distance   : tổng quãng đường (km) tích luỹ >= threshold_value
  --   activity_count   : tổng số buổi chạy >= threshold_value
  --   single_distance  : có ít nhất một buổi chạy >= threshold_value km
  threshold_type text not null,
  threshold_value numeric not null,
  sort_order integer not null default 0
);

-- Bổ sung cột để liên kết huy hiệu đã cấp với danh mục.
alter table public.badges add column if not exists code text;
alter table public.badges add column if not exists icon text;

-- Mỗi user chỉ nhận mỗi loại huy hiệu một lần.
create unique index if not exists badges_user_code_unique
  on public.badges (user_id, code)
  where code is not null;

-- Cho phép mọi người dùng đã đăng nhập đọc danh mục huy hiệu.
alter table public.badge_definitions enable row level security;
drop policy if exists "Badge definitions are readable" on public.badge_definitions;
create policy "Badge definitions are readable" on public.badge_definitions
  for select to authenticated using (true);

-- Seed danh mục huy hiệu.
insert into public.badge_definitions (code, name, description, icon, threshold_type, threshold_value, sort_order) values
  ('first_run',      'Bước Chân Đầu Tiên', 'Hoàn thành buổi chạy đầu tiên',            'flag',            'activity_count',  1,   1),
  ('runs_10',        'Kiên Trì',           'Hoàn thành 10 buổi chạy',                  'directions_run',  'activity_count',  10,  2),
  ('runs_50',        'Bền Bỉ',             'Hoàn thành 50 buổi chạy',                  'military_tech',   'activity_count',  50,  3),
  ('dist_5k',        'Chinh Phục 5K',      'Hoàn thành một buổi chạy 5km',             'looks_5',         'single_distance', 5,   4),
  ('dist_10k',       'Chinh Phục 10K',     'Hoàn thành một buổi chạy 10km',            'looks_one',       'single_distance', 10,  5),
  ('dist_half',      'Bán Marathon',       'Hoàn thành một buổi chạy 21km',            'emoji_events',    'single_distance', 21,  6),
  ('dist_full',      'Marathon',           'Hoàn thành một buổi chạy 42km',            'workspace_premium','single_distance',42,  7),
  ('total_50',       'Cự Ly 50',           'Tích luỹ tổng 50km',                       'route',           'total_distance',  50,  8),
  ('total_100',      'Cự Ly 100',          'Tích luỹ tổng 100km',                      'route',           'total_distance',  100, 9),
  ('total_500',      'Cự Ly 500',          'Tích luỹ tổng 500km',                      'public',          'total_distance',  500, 10)
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  icon = excluded.icon,
  threshold_type = excluded.threshold_type,
  threshold_value = excluded.threshold_value,
  sort_order = excluded.sort_order;

-- Hàm tự động cấp huy hiệu cho một user dựa trên thống kê hoạt động.
create or replace function public.award_badges(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_distance numeric;
  v_activity_count integer;
  v_max_single numeric;
begin
  select
    coalesce(sum(distance_km), 0),
    coalesce(count(*), 0),
    coalesce(max(distance_km), 0)
  into v_total_distance, v_activity_count, v_max_single
  from public.activities
  where user_id = p_user_id;

  insert into public.badges (user_id, code, name, description, icon)
  select p_user_id, d.code, d.name, d.description, d.icon
  from public.badge_definitions d
  where (
      (d.threshold_type = 'total_distance'  and v_total_distance >= d.threshold_value)
   or (d.threshold_type = 'activity_count'  and v_activity_count >= d.threshold_value)
   or (d.threshold_type = 'single_distance' and v_max_single     >= d.threshold_value)
  )
  and not exists (
    select 1 from public.badges b
    where b.user_id = p_user_id and b.code = d.code
  );
end;
$$;

-- Trigger cấp huy hiệu mỗi khi hoạt động thay đổi.
create or replace function public.handle_activity_badges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.award_badges(coalesce(new.user_id, old.user_id));
  return null;
end;
$$;

drop trigger if exists on_activity_change_award_badges on public.activities;
create trigger on_activity_change_award_badges
after insert or update or delete on public.activities
for each row execute procedure public.handle_activity_badges();

-- ---------------------------------------------------------------------
-- 4.2 BẢNG XẾP HẠNG
-- ---------------------------------------------------------------------

-- Hàm trả về bảng xếp hạng toàn hệ thống theo tổng quãng đường.
-- SECURITY DEFINER để vượt qua RLS self-only của bảng profiles,
-- chỉ phơi bày tên hiển thị + số liệu tổng hợp (không lộ chỉ số cá nhân).
create or replace function public.get_leaderboard(p_limit integer default 50)
returns table (
  user_id uuid,
  display_name text,
  total_distance_km numeric,
  activity_count bigint,
  rank bigint
)
language sql
security definer
set search_path = public
as $$
  select
    p.id as user_id,
    coalesce(p.display_name, 'Runner') as display_name,
    coalesce(sum(a.distance_km), 0)::numeric as total_distance_km,
    coalesce(count(a.id), 0) as activity_count,
    rank() over (order by coalesce(sum(a.distance_km), 0) desc) as rank
  from public.profiles p
  left join public.activities a on a.user_id = p.id
  group by p.id, p.display_name
  order by total_distance_km desc
  limit p_limit;
$$;

-- ---------------------------------------------------------------------
-- 4.3 KẾT NỐI CỘNG ĐỒNG - GHÉP ĐÔI BẠN CHẠY
-- ---------------------------------------------------------------------

-- Thông tin phục vụ matching trên hồ sơ.
alter table public.profiles add column if not exists preferred_pace_min_per_km numeric(5,2);
alter table public.profiles add column if not exists city text;
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists looking_for_partner boolean not null default false;

-- Bảng lời mời/kết nối giữa hai người chạy.
-- requester_id/addressee_id tham chiếu profiles(id) (cũng chính là auth.users id)
-- để PostgREST có thể embed thông tin hồ sơ đối phương qua tên constraint.
create table if not exists public.run_matches (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null constraint run_matches_requester_id_fkey references public.profiles(id) on delete cascade,
  addressee_id uuid not null constraint run_matches_addressee_id_fkey references public.profiles(id) on delete cascade,
  status text not null default 'pending', -- pending, accepted, declined
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint run_matches_distinct check (requester_id <> addressee_id),
  constraint run_matches_unique_pair unique (requester_id, addressee_id)
);

alter table public.run_matches enable row level security;

-- Hai bên trong một lời mời đều có thể đọc.
drop policy if exists "Matches readable by participants" on public.run_matches;
create policy "Matches readable by participants" on public.run_matches
  for select using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- Chỉ người gửi mới tạo lời mời (cho chính mình).
drop policy if exists "Matches insertable by requester" on public.run_matches;
create policy "Matches insertable by requester" on public.run_matches
  for insert with check (auth.uid() = requester_id);

-- Cả hai bên có thể cập nhật (người nhận chấp nhận/từ chối, người gửi huỷ).
drop policy if exists "Matches updatable by participants" on public.run_matches;
create policy "Matches updatable by participants" on public.run_matches
  for update using (auth.uid() = requester_id or auth.uid() = addressee_id);

drop policy if exists "Matches deletable by participants" on public.run_matches;
create policy "Matches deletable by participants" on public.run_matches
  for delete using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- Gợi ý bạn chạy: những người bật looking_for_partner, có pace gần với
-- pace của người dùng hiện tại, ưu tiên cùng thành phố, loại trừ những
-- người đã có lời mời/kết nối.
create or replace function public.get_match_suggestions(p_limit integer default 20)
returns table (
  user_id uuid,
  display_name text,
  city text,
  bio text,
  preferred_pace_min_per_km numeric,
  avg_pace_min_per_km numeric,
  total_distance_km numeric,
  same_city boolean,
  pace_diff numeric
)
language sql
security definer
set search_path = public
as $$
  with me as (
    select
      id,
      city as my_city,
      coalesce(
        preferred_pace_min_per_km,
        (select case when sum(distance_km) > 0
                     then sum(duration_min) / sum(distance_km) end
         from public.activities where user_id = auth.uid())
      ) as my_pace
    from public.profiles
    where id = auth.uid()
  )
  select
    p.id as user_id,
    coalesce(p.display_name, 'Runner') as display_name,
    p.city,
    p.bio,
    p.preferred_pace_min_per_km,
    stats.avg_pace as avg_pace_min_per_km,
    coalesce(stats.total_distance, 0) as total_distance_km,
    (p.city is not null and p.city is not distinct from me.my_city) as same_city,
    abs(
      coalesce(p.preferred_pace_min_per_km, stats.avg_pace, me.my_pace)
      - me.my_pace
    ) as pace_diff
  from public.profiles p
  cross join me
  left join lateral (
    select
      case when sum(a.distance_km) > 0
           then sum(a.duration_min) / sum(a.distance_km) end as avg_pace,
      sum(a.distance_km) as total_distance
    from public.activities a
    where a.user_id = p.id
  ) stats on true
  where p.looking_for_partner = true
    and p.id <> auth.uid()
    and not exists (
      select 1 from public.run_matches m
      where (m.requester_id = auth.uid() and m.addressee_id = p.id)
         or (m.addressee_id = auth.uid() and m.requester_id = p.id)
    )
  order by same_city desc, pace_diff asc nulls last
  limit p_limit;
$$;
