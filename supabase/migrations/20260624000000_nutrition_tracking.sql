-- =====================================================================
-- Theo dõi dinh dưỡng (Nutrition tracking)
--   - nutrition_goals: mục tiêu calo + tỉ lệ macro của mỗi người dùng
--   - meal_logs: nhật ký các món ăn đã ghi nhận theo bữa và thời gian
-- Trước đây NutritionService chỉ dùng dữ liệu mock; migration này tạo
-- bảng lưu trữ thật để dữ liệu được đồng bộ qua Supabase.
-- =====================================================================

-- Mục tiêu dinh dưỡng (mỗi người dùng một dòng).
create table if not exists public.nutrition_goals (
  user_id uuid primary key references auth.users(id) on delete cascade,
  daily_calories numeric(7,2) not null default 2000,
  protein_percentage numeric(5,2) not null default 30,
  carbs_percentage numeric(5,2) not null default 40,
  fat_percentage numeric(5,2) not null default 30,
  updated_at timestamptz not null default now()
);

alter table public.nutrition_goals enable row level security;

drop policy if exists "Nutrition goals are self-readable" on public.nutrition_goals;
create policy "Nutrition goals are self-readable" on public.nutrition_goals
  for select using (auth.uid() = user_id);

drop policy if exists "Nutrition goals are self-insertable" on public.nutrition_goals;
create policy "Nutrition goals are self-insertable" on public.nutrition_goals
  for insert with check (auth.uid() = user_id);

drop policy if exists "Nutrition goals are self-updatable" on public.nutrition_goals;
create policy "Nutrition goals are self-updatable" on public.nutrition_goals
  for update using (auth.uid() = user_id);

-- Nhật ký món ăn.
create table if not exists public.meal_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  food_name text not null,
  calories numeric(7,2) not null default 0,
  protein numeric(7,2) not null default 0,
  carbs numeric(7,2) not null default 0,
  fat numeric(7,2) not null default 0,
  amount numeric(7,2) not null default 1,
  unit text not null default 'serving',
  meal_type text not null default 'snack'
    check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  consumed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists meal_logs_user_consumed_at_idx
  on public.meal_logs (user_id, consumed_at desc);

alter table public.meal_logs enable row level security;

drop policy if exists "Meal logs are self-readable" on public.meal_logs;
create policy "Meal logs are self-readable" on public.meal_logs
  for select using (auth.uid() = user_id);

drop policy if exists "Meal logs are self-insertable" on public.meal_logs;
create policy "Meal logs are self-insertable" on public.meal_logs
  for insert with check (auth.uid() = user_id);

drop policy if exists "Meal logs are self-updatable" on public.meal_logs;
create policy "Meal logs are self-updatable" on public.meal_logs
  for update using (auth.uid() = user_id);

drop policy if exists "Meal logs are self-deletable" on public.meal_logs;
create policy "Meal logs are self-deletable" on public.meal_logs
  for delete using (auth.uid() = user_id);
