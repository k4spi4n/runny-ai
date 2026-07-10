-- Drop old triggers referencing the shared function
drop trigger if exists assert_activity_related_owner on public.activities;
drop trigger if exists assert_workout_related_owner on public.scheduled_workouts;
drop trigger if exists assert_reminder_related_owner on public.run_reminders;
drop trigger if exists assert_insight_related_owner on public.ai_insights;

-- Drop the buggy shared trigger function
drop function if exists public.assert_related_row_owner();

-- 1. Trigger function for activities
create or replace function public.assert_activity_shoe_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  related_user uuid;
begin
  if new.shoe_id is not null then
    select user_id into related_user from public.shoes where id = new.shoe_id;
    if related_user is distinct from new.user_id then
      raise exception 'shoe must belong to the activity owner' using errcode = 'foreign_key_violation';
    end if;
  end if;
  return new;
end;
$$;

create trigger assert_activity_related_owner 
  before insert or update of user_id, shoe_id on public.activities
  for each row execute function public.assert_activity_shoe_owner();


-- 2. Trigger function for scheduled_workouts
create or replace function public.assert_workout_owners()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  related_user uuid;
begin
  select user_id into related_user from public.training_schedules where id = new.schedule_id;
  if related_user is distinct from new.user_id then
    raise exception 'schedule must belong to the workout owner' using errcode = 'foreign_key_violation';
  end if;
  
  if new.activity_id is not null then
    select user_id into related_user from public.activities where id = new.activity_id;
    if related_user is distinct from new.user_id then
      raise exception 'activity must belong to the workout owner' using errcode = 'foreign_key_violation';
    end if;
  end if;
  return new;
end;
$$;

create trigger assert_workout_related_owner 
  before insert or update of user_id, schedule_id, activity_id on public.scheduled_workouts
  for each row execute function public.assert_workout_owners();


-- 3. Trigger function for run_reminders
create or replace function public.assert_reminder_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  related_user uuid;
begin
  select user_id into related_user from public.scheduled_workouts where id = new.workout_id;
  if related_user is distinct from new.user_id then
    raise exception 'workout must belong to the reminder owner' using errcode = 'foreign_key_violation';
  end if;
  return new;
end;
$$;

create trigger assert_reminder_related_owner 
  before insert or update of user_id, workout_id on public.run_reminders
  for each row execute function public.assert_reminder_owner();


-- 4. Trigger function for ai_insights
create or replace function public.assert_insight_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  related_user uuid;
begin
  if new.activity_id is not null then
    select user_id into related_user from public.activities where id = new.activity_id;
    if related_user is distinct from new.user_id then
      raise exception 'activity must belong to the insight owner' using errcode = 'foreign_key_violation';
    end if;
  end if;
  return new;
end;
$$;

create trigger assert_insight_related_owner 
  before insert or update of user_id, activity_id on public.ai_insights
  for each row execute function public.assert_insight_owner();


-- Ask PostgREST to reload schema
select pg_notify('pgrst', 'reload schema');
