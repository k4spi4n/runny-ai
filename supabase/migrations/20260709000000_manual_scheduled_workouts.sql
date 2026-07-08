-- Support manually created scheduled workouts while preserving AI-generated plans.
alter table public.training_schedules
  add column if not exists source text not null default 'ai'
    check (source in ('ai', 'manual'));

alter table public.scheduled_workouts
  add column if not exists start_time time,
  add column if not exists workout_type text,
  add column if not exists source text not null default 'ai'
    check (source in ('ai', 'manual'));

-- Ask PostgREST to refresh its schema cache after the DDL change.
select pg_notify('pgrst', 'reload schema');
