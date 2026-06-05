-- Suppress notices for already existing extensions
set client_min_messages = warning;
create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  display_name text,
  weight_kg numeric(5,2),
  max_hr integer,
  bmi numeric(5,2)
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  started_at timestamptz not null,
  distance_km numeric(7,2) not null,
  duration_min numeric(7,2) not null,
  avg_hr integer,
  elevation_gain_m numeric(7,2),
  notes text,
  data_points jsonb
);

create table if not exists public.training_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  title text not null,
  target_pace_min_per_km numeric(5,2),
  target_distance_km numeric(7,2),
  start_date date,
  end_date date
);

create table if not exists public.ai_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  activity_id uuid references public.activities(id) on delete set null,
  content text not null
);

create table if not exists public.badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  name text not null,
  description text
);

create view public.leaderboard_totals as
select
  p.id as user_id,
  coalesce(p.display_name, 'Runner') as display_name,
  coalesce(sum(a.distance_km), 0) as total_distance_km,
  coalesce(count(a.id), 0) as activity_count
from public.profiles p
left join public.activities a on a.user_id = p.id
group by p.id, p.display_name;

alter table public.profiles enable row level security;
alter table public.activities enable row level security;
alter table public.training_schedules enable row level security;
alter table public.ai_insights enable row level security;
alter table public.badges enable row level security;

create policy "Profiles are self-readable" on public.profiles
  for select using (auth.uid() = id);
create policy "Profiles are self-updatable" on public.profiles
  for update using (auth.uid() = id);
create policy "Profiles are self-insertable" on public.profiles
  for insert with check (auth.uid() = id);

create policy "Activities are self-readable" on public.activities
  for select using (auth.uid() = user_id);
create policy "Activities are self-insertable" on public.activities
  for insert with check (auth.uid() = user_id);
create policy "Activities are self-updatable" on public.activities
  for update using (auth.uid() = user_id);
create policy "Activities are self-deletable" on public.activities
  for delete using (auth.uid() = user_id);

create policy "Schedules are self-readable" on public.training_schedules
  for select using (auth.uid() = user_id);
create policy "Schedules are self-insertable" on public.training_schedules
  for insert with check (auth.uid() = user_id);
create policy "Schedules are self-updatable" on public.training_schedules
  for update using (auth.uid() = user_id);
create policy "Schedules are self-deletable" on public.training_schedules
  for delete using (auth.uid() = user_id);

create policy "Insights are self-readable" on public.ai_insights
  for select using (auth.uid() = user_id);
create policy "Insights are self-insertable" on public.ai_insights
  for insert with check (auth.uid() = user_id);
create policy "Insights are self-updatable" on public.ai_insights
  for update using (auth.uid() = user_id);
create policy "Insights are self-deletable" on public.ai_insights
  for delete using (auth.uid() = user_id);

create policy "Badges are self-readable" on public.badges
  for select using (auth.uid() = user_id);
create policy "Badges are self-insertable" on public.badges
  for insert with check (auth.uid() = user_id);
create policy "Badges are self-updatable" on public.badges
  for update using (auth.uid() = user_id);
create policy "Badges are self-deletable" on public.badges
  for delete using (auth.uid() = user_id);

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, split_part(new.email, '@', 1))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();
