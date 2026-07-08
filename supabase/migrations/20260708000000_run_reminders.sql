create table if not exists public.run_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_id uuid not null references public.scheduled_workouts(id) on delete cascade,
  workout_at timestamptz not null,
  lead_minutes integer not null default 10
    check (lead_minutes in (0, 5, 10, 30, 60)),
  enabled boolean not null default true,
  notification_id integer not null,
  scheduled_for timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workout_id)
);

create index if not exists run_reminders_user_id_idx
  on public.run_reminders(user_id);

create index if not exists run_reminders_scheduled_for_idx
  on public.run_reminders(scheduled_for)
  where enabled = true;

alter table public.run_reminders enable row level security;

create policy "Run reminders are self-readable" on public.run_reminders
  for select using (auth.uid() = user_id);

create policy "Run reminders are self-insertable" on public.run_reminders
  for insert with check (auth.uid() = user_id);

create policy "Run reminders are self-updatable" on public.run_reminders
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Run reminders are self-deletable" on public.run_reminders
  for delete using (auth.uid() = user_id);
