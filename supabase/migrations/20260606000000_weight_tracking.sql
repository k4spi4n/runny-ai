-- =====================================================================
-- Issue #30: Quản lý và theo dõi cân nặng
--   - Mục tiêu cân nặng mong muốn (target) + mốc bắt đầu (start)
--   - Nhật ký cân nặng theo thời gian để vẽ tiến trình
-- =====================================================================

-- Mục tiêu cân nặng trên hồ sơ.
alter table public.profiles add column if not exists target_weight_kg numeric(5,2);
-- Cân nặng tại thời điểm đặt mục tiêu (dùng làm mốc 0% của thanh tiến trình).
alter table public.profiles add column if not exists start_weight_kg numeric(5,2);

-- Nhật ký các lần ghi cân nặng.
create table if not exists public.weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric(5,2) not null,
  logged_at timestamptz not null default now(),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists weight_logs_user_logged_at_idx
  on public.weight_logs (user_id, logged_at desc);

alter table public.weight_logs enable row level security;

drop policy if exists "Weight logs are self-readable" on public.weight_logs;
create policy "Weight logs are self-readable" on public.weight_logs
  for select using (auth.uid() = user_id);

drop policy if exists "Weight logs are self-insertable" on public.weight_logs;
create policy "Weight logs are self-insertable" on public.weight_logs
  for insert with check (auth.uid() = user_id);

drop policy if exists "Weight logs are self-updatable" on public.weight_logs;
create policy "Weight logs are self-updatable" on public.weight_logs
  for update using (auth.uid() = user_id);

drop policy if exists "Weight logs are self-deletable" on public.weight_logs;
create policy "Weight logs are self-deletable" on public.weight_logs
  for delete using (auth.uid() = user_id);
