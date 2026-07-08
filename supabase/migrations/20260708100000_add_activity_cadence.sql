-- Add optional avg_cadence column to activities table.
alter table public.activities
  add column if not exists avg_cadence integer;

comment on column public.activities.avg_cadence is 'Average running cadence (optional, steps per minute)';
