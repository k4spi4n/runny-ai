-- Record when a user last accepted an AI adjustment to a training plan.
alter table public.training_schedules
  add column if not exists last_ai_adjusted_at timestamptz;

-- Make the new field available to PostgREST immediately after migration.
select pg_notify('pgrst', 'reload schema');
