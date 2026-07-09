-- Drop redundant workout_at column from run_reminders as scheduled_workouts is the single source of truth
alter table public.run_reminders
  drop column if exists workout_at;

-- Notify PostgREST to reload schema cache
select pg_notify('pgrst', 'reload schema');
