-- Readiness & recovery: subjective post-run load and daily recovery check-ins.
create table public.activity_recovery_feedback (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null unique references public.activities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rpe smallint not null check (rpe between 1 and 10),
  notes text check (char_length(notes) <= 500),
  recorded_at timestamptz not null default now()
);

create table public.daily_recovery_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  checkin_date date not null default current_date,
  sleep_quality smallint not null check (sleep_quality between 1 and 5),
  sleep_hours numeric(3,1) check (sleep_hours between 0 and 16),
  soreness smallint not null check (soreness between 0 and 10),
  pain_flag boolean not null default false,
  notes text check (char_length(notes) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, checkin_date)
);

alter table public.activity_recovery_feedback enable row level security;
alter table public.daily_recovery_checkins enable row level security;

create policy "Activity recovery feedback is owner-only" on public.activity_recovery_feedback
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Recovery check-ins are owner-only" on public.daily_recovery_checkins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.set_recovery_checkin_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
create trigger set_daily_recovery_checkin_updated_at before update on public.daily_recovery_checkins
  for each row execute function public.set_recovery_checkin_updated_at();

-- sRPE = subjective RPE x activity duration.  Chronic load is expressed as a
-- weekly average across the last 28 days, so ACWR compares like-for-like loads.
create or replace function public.get_readiness_snapshot()
returns table (
  readiness_score integer,
  readiness_status text,
  acute_load numeric,
  chronic_load numeric,
  acwr numeric,
  has_sufficient_load_data boolean,
  pain_flag boolean,
  checkin_date date,
  factors jsonb
)
language sql stable security invoker set search_path = public as $$
  with recent_load as (
    select coalesce(sum(case when a.started_at >= now() - interval '7 days' then f.rpe * a.duration_min else 0 end), 0)::numeric as acute,
           coalesce(sum(case when a.started_at >= now() - interval '28 days' then f.rpe * a.duration_min else 0 end) / 4, 0)::numeric as chronic,
           count(*) filter (where a.started_at >= now() - interval '28 days') as samples
    from activities a join activity_recovery_feedback f on f.activity_id = a.id
    where a.user_id = auth.uid()
  ), latest as (
    select * from daily_recovery_checkins where user_id = auth.uid() order by checkin_date desc limit 1
  ), values_ as (
    select l.acute, l.chronic, l.samples, c.checkin_date, coalesce(c.pain_flag, false) as pain,
           c.sleep_quality, c.sleep_hours, c.soreness,
           case when l.chronic > 0 then round(l.acute / l.chronic, 2) end as ratio
    from recent_load l left join latest c on true
  )
  select greatest(0, least(100,
           80 - case when pain then 50 else 0 end - coalesce((soreness - 3) * 4, 0)
              - case when sleep_quality is not null and sleep_quality <= 2 then 15 else 0 end
              - case when sleep_hours is not null and sleep_hours < 6 then 10 else 0 end
              - case when ratio > 1.5 then 15 when ratio > 1.3 then 8 else 0 end
         ))::integer,
         case when pain then 'rest' when ratio > 1.5 or coalesce(soreness, 0) >= 7 then 'low' when ratio > 1.3 or coalesce(soreness, 0) >= 5 then 'caution' else 'ready' end,
         acute, chronic, ratio, samples >= 3, pain, checkin_date,
         jsonb_strip_nulls(jsonb_build_object('sleep_quality', sleep_quality, 'sleep_hours', sleep_hours, 'soreness', soreness, 'acwr_high', ratio > 1.3, 'needs_checkin', checkin_date is distinct from current_date))
  from values_;
$$;

select pg_notify('pgrst', 'reload schema');
