-- Add error_message column to training_schedules to track AI generation failure details
alter table public.training_schedules
  add column if not exists error_message text;

-- Ask PostgREST to refresh its schema cache after the DDL change.
select pg_notify('pgrst', 'reload schema');
