-- Add scheduled_workouts table for granular planning
create table if not exists public.scheduled_workouts (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.training_schedules(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  title text not null,
  description text,
  target_distance_km numeric(7,2),
  target_duration_min numeric(7,2),
  target_pace_min_per_km numeric(5,2),
  status text not null default 'planned', -- planned, completed, skipped, rescheduled
  activity_id uuid references public.activities(id) on delete set null,
  created_at timestamptz not null default now()
);

-- Add goal_description to training_schedules
alter table public.training_schedules add column if not exists goal_description text;
alter table public.training_schedules add column if not exists status text default 'active';

-- Enable RLS for scheduled_workouts
alter table public.scheduled_workouts enable row level security;

-- Policies for scheduled_workouts
create policy "Workouts are self-readable" on public.scheduled_workouts 
  for select using (auth.uid() = user_id);
create policy "Workouts are self-insertable" on public.scheduled_workouts 
  for insert with check (auth.uid() = user_id);
create policy "Workouts are self-updatable" on public.scheduled_workouts 
  for update using (auth.uid() = user_id);
create policy "Workouts are self-deletable" on public.scheduled_workouts 
  for delete using (auth.uid() = user_id);
