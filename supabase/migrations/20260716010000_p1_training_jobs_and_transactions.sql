-- Durable training-plan jobs and atomic schedule mutations.

create table if not exists private.training_plan_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  schedule_id uuid not null references public.training_schedules(id) on delete cascade,
  idempotency_key text not null,
  goal text not null,
  start_date date not null,
  end_date date,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'failed')),
  attempts integer not null default 0 check (attempts between 0 and 10),
  max_attempts integer not null default 4 check (max_attempts between 1 and 10),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  completed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

revoke all on table private.training_plan_jobs from public, anon, authenticated;
grant all on table private.training_plan_jobs to service_role;

create unique index if not exists training_plan_jobs_one_open_per_user
  on private.training_plan_jobs(user_id)
  where status in ('pending', 'processing');

create index if not exists training_plan_jobs_claim_idx
  on private.training_plan_jobs(status, available_at, created_at)
  where status in ('pending', 'processing');

create or replace function public.enqueue_training_plan_job(
  p_user_id uuid,
  p_goal text,
  p_start_date date,
  p_end_date date,
  p_idempotency_key text
) returns table (
  job_id uuid,
  schedule_id uuid,
  job_status text,
  reused boolean
)
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_existing private.training_plan_jobs%rowtype;
  v_schedule_id uuid;
  v_entitled boolean;
begin
  if p_user_id is null
     or p_goal is null
     or length(btrim(p_goal)) not between 10 and 4000
     or p_idempotency_key is null
     or p_idempotency_key !~ '^[A-Za-z0-9._:-]{16,120}$' then
    raise exception 'invalid training plan request'
      using errcode = 'check_violation';
  end if;
  if p_start_date < current_date - 1
     or p_start_date > current_date + 365
     or (p_end_date is not null and (
       p_end_date <= p_start_date or p_end_date > p_start_date + 365
     )) then
    raise exception 'invalid training plan date range'
      using errcode = 'check_violation';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('training-plan:' || p_user_id::text, 0)
  );

  select *
  into v_existing
  from private.training_plan_jobs j
  where j.user_id = p_user_id
    and j.idempotency_key = p_idempotency_key;
  if found then
    return query
      select v_existing.id, v_existing.schedule_id, v_existing.status, true;
    return;
  end if;

  -- Return an already-running job rather than creating parallel plans for the
  -- same user. Failed/completed jobs do not block a later explicit request.
  select *
  into v_existing
  from private.training_plan_jobs j
  where j.user_id = p_user_id
    and j.status in ('pending', 'processing')
  order by j.created_at desc
  limit 1;
  if found then
    return query
      select v_existing.id, v_existing.schedule_id, v_existing.status, true;
    return;
  end if;

  select
    exists (
      select 1
      from public.user_subscriptions us
      where us.user_id = p_user_id
        and us.status = 'active'
        and us.end_date > now()
    )
    or exists (
      select 1
      from public.profiles p
      where p.id = p_user_id
        and p.trial_ends_at > now()
    )
  into v_entitled;
  if not coalesce(v_entitled, false) then
    raise exception 'upgrade_required'
      using errcode = 'insufficient_privilege';
  end if;

  insert into public.training_schedules (
    user_id,
    title,
    goal_description,
    start_date,
    end_date,
    status,
    source,
    error_message
  ) values (
    p_user_id,
    'AI đang tạo lịch tập...',
    btrim(p_goal),
    p_start_date,
    p_end_date,
    'generating',
    'ai',
    null
  )
  returning id into v_schedule_id;

  insert into private.training_plan_jobs (
    user_id,
    schedule_id,
    idempotency_key,
    goal,
    start_date,
    end_date
  ) values (
    p_user_id,
    v_schedule_id,
    p_idempotency_key,
    btrim(p_goal),
    p_start_date,
    p_end_date
  )
  returning id, status
  into job_id, job_status;

  schedule_id := v_schedule_id;
  reused := false;
  return next;
end;
$$;

create or replace function public.claim_training_plan_job(p_job_id uuid)
returns table (
  id uuid,
  user_id uuid,
  schedule_id uuid,
  goal text,
  start_date date,
  end_date date,
  attempts integer
)
language sql
security definer
set search_path = public, private
as $$
  with candidate as (
    select j.id
    from private.training_plan_jobs j
    where j.id = p_job_id
      and j.attempts < j.max_attempts
      and (
        (j.status = 'pending' and j.available_at <= now())
        or (j.status = 'processing' and j.locked_at < now() - interval '10 minutes')
      )
    for update skip locked
  )
  update private.training_plan_jobs j
  set status = 'processing',
      attempts = j.attempts + 1,
      locked_at = now(),
      updated_at = now(),
      last_error = null
  from candidate c
  where j.id = c.id
  returning j.id, j.user_id, j.schedule_id, j.goal, j.start_date,
            j.end_date, j.attempts;
$$;

create or replace function public.claim_next_training_plan_jobs(p_limit integer)
returns table (
  id uuid,
  user_id uuid,
  schedule_id uuid,
  goal text,
  start_date date,
  end_date date,
  attempts integer
)
language sql
security definer
set search_path = public, private
as $$
  with candidate as (
    select j.id
    from private.training_plan_jobs j
    where j.attempts < j.max_attempts
      and (
        (j.status = 'pending' and j.available_at <= now())
        or (j.status = 'processing' and j.locked_at < now() - interval '10 minutes')
      )
    order by j.available_at, j.created_at
    limit greatest(1, least(coalesce(p_limit, 5), 20))
    for update skip locked
  )
  update private.training_plan_jobs j
  set status = 'processing',
      attempts = j.attempts + 1,
      locked_at = now(),
      updated_at = now(),
      last_error = null
  from candidate c
  where j.id = c.id
  returning j.id, j.user_id, j.schedule_id, j.goal, j.start_date,
            j.end_date, j.attempts;
$$;

create or replace function public.finish_training_plan_job(
  p_job_id uuid,
  p_error text
) returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_job private.training_plan_jobs%rowtype;
  v_terminal boolean;
begin
  select * into v_job
  from private.training_plan_jobs
  where id = p_job_id
  for update;
  if not found or v_job.status <> 'processing' then
    return;
  end if;

  v_terminal := v_job.attempts >= v_job.max_attempts;
  update private.training_plan_jobs
  set status = case when v_terminal then 'failed' else 'pending' end,
      available_at = case
        when v_terminal then available_at
        else now() + make_interval(secs => least(300, 15 * (2 ^ greatest(v_job.attempts - 1, 0)))::integer)
      end,
      locked_at = null,
      last_error = left(coalesce(p_error, 'training_plan_failed'), 200),
      updated_at = now()
  where id = p_job_id;

  if v_terminal then
    update public.training_schedules
    set status = 'failed',
        error_message = 'Không thể tạo lịch tập lúc này. Vui lòng thử lại.'
    where id = v_job.schedule_id
      and user_id = v_job.user_id;
  end if;
end;
$$;

create or replace function public.complete_training_plan_job(
  p_job_id uuid,
  p_plan jsonb
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_job private.training_plan_jobs%rowtype;
  v_workout jsonb;
  v_workouts jsonb;
  v_weeks integer;
  v_end_date date;
  v_offset integer;
  v_date date;
  v_title text;
  v_description text;
  v_type text;
  v_start_time time;
  v_distance numeric;
  v_duration numeric;
  v_pace numeric;
  v_count integer;
  v_min_date date;
  v_max_date date;
begin
  select * into v_job
  from private.training_plan_jobs
  where id = p_job_id
  for update;
  if not found or v_job.status <> 'processing' then
    raise exception 'training plan job is not claimed'
      using errcode = 'object_not_in_prerequisite_state';
  end if;
  if jsonb_typeof(p_plan) <> 'object' then
    raise exception 'invalid training plan payload'
      using errcode = 'check_violation';
  end if;

  v_workouts := p_plan -> 'workouts';
  if jsonb_typeof(v_workouts) <> 'array'
     or jsonb_array_length(v_workouts) < 1
     or jsonb_array_length(v_workouts) > 200 then
    raise exception 'invalid training plan workouts'
      using errcode = 'check_violation';
  end if;
  v_weeks := greatest(1, least(52, coalesce((p_plan ->> 'weeks')::integer, 4)));
  v_end_date := coalesce(
    v_job.end_date,
    v_job.start_date + least(v_weeks * 7, 365)
  );

  update public.training_schedules
  set title = left(coalesce(nullif(btrim(p_plan ->> 'title'), ''), 'Lịch tập của bạn'), 160),
      target_distance_km = greatest(0, least(99999.99, coalesce((p_plan ->> 'target_distance_km')::numeric, 0))),
      target_pace_min_per_km = greatest(0, least(999.99, coalesce((p_plan ->> 'target_pace_min_per_km')::numeric, 0))),
      goal_description = v_job.goal,
      start_date = v_job.start_date,
      end_date = v_end_date,
      status = 'draft',
      error_message = null
  where id = v_job.schedule_id
    and user_id = v_job.user_id;
  if not found then
    raise exception 'training schedule missing'
      using errcode = 'foreign_key_violation';
  end if;

  delete from public.scheduled_workouts
  where schedule_id = v_job.schedule_id
    and user_id = v_job.user_id;

  for v_workout in select value from jsonb_array_elements(v_workouts)
  loop
    if jsonb_typeof(v_workout) <> 'object'
       or coalesce(v_workout ->> 'source', 'ai') <> 'ai' then
      raise exception 'invalid generated workout source'
        using errcode = 'check_violation';
    end if;
    v_offset := (v_workout ->> 'day_offset')::integer;
    if v_offset < 0 or v_offset > (v_end_date - v_job.start_date) then
      raise exception 'workout day is outside plan range'
        using errcode = 'check_violation';
    end if;
    v_date := v_job.start_date + v_offset;
    v_title := btrim(v_workout ->> 'title');
    v_description := nullif(btrim(v_workout ->> 'description'), '');
    v_type := v_workout ->> 'workout_type';
    if v_title is null or length(v_title) not between 1 and 160
       or v_type not in ('easy_run', 'long_run', 'interval', 'tempo', 'recovery') then
      raise exception 'invalid generated workout'
        using errcode = 'check_violation';
    end if;
    if coalesce(v_workout ->> 'start_time', '') !~
       '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' then
      raise exception 'invalid workout start time'
        using errcode = 'check_violation';
    end if;
    v_start_time := (v_workout ->> 'start_time')::time;
    v_distance := greatest(
      0,
      least(
        99999.99,
        coalesce((v_workout ->> 'target_distance_km')::numeric, 0)
      )
    );
    v_duration := greatest(
      0,
      least(
        99999.99,
        coalesce((v_workout ->> 'target_duration_min')::numeric, 0)
      )
    );
    v_pace := greatest(
      0,
      least(
        999.99,
        coalesce((v_workout ->> 'target_pace_min_per_km')::numeric, 0)
      )
    );

    if exists (
      select 1
      from public.scheduled_workouts generated
      where generated.schedule_id = v_job.schedule_id
        and generated.source = 'ai'
        and generated.date = v_date
    ) then
      raise exception 'multiple AI workouts on one day'
        using errcode = 'check_violation';
    end if;

    -- Manual workouts are authoritative and are copied below from the current
    -- active schedule. Do not place an AI workout on the same day.
    if exists (
      select 1
      from public.scheduled_workouts mw
      join public.training_schedules ms on ms.id = mw.schedule_id
      where ms.user_id = v_job.user_id
        and ms.status = 'active'
        and mw.source = 'manual'
        and mw.date = v_date
    ) then
      continue;
    end if;

    insert into public.scheduled_workouts (
      schedule_id, user_id, date, title, description,
      target_distance_km, target_duration_min, target_pace_min_per_km,
      status, source, workout_type, start_time
    ) values (
      v_job.schedule_id, v_job.user_id, v_date, v_title, v_description,
      v_distance, v_duration, v_pace,
      'planned', 'ai', v_type, v_start_time
    );
  end loop;

  select count(*) into v_count
  from public.scheduled_workouts
  where schedule_id = v_job.schedule_id
    and source = 'ai';
  if v_count = 0 then
    raise exception 'generated plan contains no usable AI workouts'
      using errcode = 'check_violation';
  end if;

  with active_schedule as (
    select s.id
    from public.training_schedules s
    where s.user_id = v_job.user_id
      and s.status = 'active'
      and s.id <> v_job.schedule_id
    order by s.created_at desc
    limit 1
  )
  insert into public.scheduled_workouts (
    schedule_id, user_id, date, title, description,
    target_distance_km, target_duration_min, target_pace_min_per_km,
    status, activity_id, source, workout_type, start_time
  )
  select
    v_job.schedule_id, v_job.user_id, w.date, w.title, w.description,
    w.target_distance_km, w.target_duration_min, w.target_pace_min_per_km,
    w.status, w.activity_id, 'manual', w.workout_type, w.start_time
  from public.scheduled_workouts w
  join active_schedule a on a.id = w.schedule_id
  where w.source = 'manual'
    and w.date >= v_job.start_date;

  select min(w.date), max(w.date)
  into v_min_date, v_max_date
  from public.scheduled_workouts w
  where w.schedule_id = v_job.schedule_id;

  update public.training_schedules
  set start_date = least(coalesce(start_date, v_min_date), v_min_date),
      end_date = greatest(coalesce(end_date, v_max_date), v_max_date)
  where id = v_job.schedule_id
    and user_id = v_job.user_id;

  update private.training_plan_jobs
  set status = 'completed',
      completed_at = now(),
      locked_at = null,
      last_error = null,
      updated_at = now()
  where id = p_job_id;

  return v_job.schedule_id;
end;
$$;

create or replace function public.reschedule_scheduled_workout(
  p_workout_id uuid,
  p_new_date date,
  p_start_time time,
  p_shift_following boolean default false
) returns table (
  workout_id uuid,
  workout_date date,
  workout_start_time time
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_schedule_id uuid;
  v_original_date date;
  v_status text;
  v_shift integer;
  v_following_ids uuid[];
  v_affected_ids uuid[] := array[p_workout_id];
  v_min_date date;
  v_max_date date;
begin
  if auth.uid() is null or p_new_date is null or p_start_time is null then
    raise exception 'invalid reschedule request'
      using errcode = 'check_violation';
  end if;

  select w.schedule_id, w.date, w.status
  into v_schedule_id, v_original_date, v_status
  from public.scheduled_workouts w
  where w.id = p_workout_id
    and w.user_id = auth.uid()
  for update;
  if not found or v_status = 'completed' then
    raise exception 'workout cannot be rescheduled'
      using errcode = 'insufficient_privilege';
  end if;

  perform 1
  from public.training_schedules s
  where s.id = v_schedule_id
    and s.user_id = auth.uid()
  for update;
  if not found then
    raise exception 'schedule not found'
      using errcode = 'insufficient_privilege';
  end if;

  v_shift := p_new_date - v_original_date;
  if coalesce(p_shift_following, false) and v_shift <> 0 then
    select array_agg(w.id order by w.date, w.id)
    into v_following_ids
    from public.scheduled_workouts w
    where w.schedule_id = v_schedule_id
      and w.user_id = auth.uid()
      and w.date > v_original_date
      and w.status in ('planned', 'rescheduled');

    if v_following_ids is not null then
      update public.scheduled_workouts w
      set date = w.date + v_shift,
          status = 'planned'
      where w.id = any(v_following_ids);
      v_affected_ids := v_affected_ids || v_following_ids;
    end if;
  end if;

  update public.scheduled_workouts
  set date = p_new_date,
      start_time = p_start_time,
      status = 'planned'
  where id = p_workout_id;

  select min(w.date), max(w.date)
  into v_min_date, v_max_date
  from public.scheduled_workouts w
  where w.schedule_id = v_schedule_id;

  update public.training_schedules
  set start_date = least(coalesce(start_date, v_min_date), v_min_date),
      end_date = greatest(coalesce(end_date, v_max_date), v_max_date)
  where id = v_schedule_id
    and user_id = auth.uid();

  return query
    select w.id, w.date, w.start_time
    from public.scheduled_workouts w
    where w.id = any(v_affected_ids)
    order by w.date, w.id;
end;
$$;

create or replace function public.apply_training_plan_adjustments(
  p_adjustments jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_workout public.scheduled_workouts%rowtype;
  v_schedule_id uuid;
  v_id uuid;
  v_new_date date;
  v_new_distance numeric;
  v_reason text;
  v_expected integer;
  v_unique integer;
  v_min_date date;
  v_max_date date;
begin
  if auth.uid() is null
     or jsonb_typeof(p_adjustments) <> 'array'
     or jsonb_array_length(p_adjustments) not between 1 and 50 then
    raise exception 'invalid adjustments payload'
      using errcode = 'check_violation';
  end if;

  v_expected := jsonb_array_length(p_adjustments);
  select count(distinct value ->> 'workout_id')
  into v_unique
  from jsonb_array_elements(p_adjustments);
  if v_unique <> v_expected then
    raise exception 'duplicate workout adjustment'
      using errcode = 'check_violation';
  end if;

  for v_item in select value from jsonb_array_elements(p_adjustments)
  loop
    v_id := (v_item ->> 'workout_id')::uuid;
    select * into v_workout
    from public.scheduled_workouts w
    where w.id = v_id
      and w.user_id = auth.uid()
    for update;
    if not found
       or v_workout.source <> 'ai'
       or v_workout.status not in ('planned', 'rescheduled') then
      raise exception 'workout adjustment is not allowed'
        using errcode = 'insufficient_privilege';
    end if;
    if v_schedule_id is null then
      v_schedule_id := v_workout.schedule_id;
      perform 1
      from public.training_schedules s
      where s.id = v_schedule_id
        and s.user_id = auth.uid()
      for update;
      if not found then
        raise exception 'schedule not found'
          using errcode = 'insufficient_privilege';
      end if;
    elsif v_schedule_id <> v_workout.schedule_id then
      raise exception 'adjustments must target one schedule'
        using errcode = 'check_violation';
    end if;

    v_new_date := case
      when nullif(v_item ->> 'new_date', '') is null then null
      else (v_item ->> 'new_date')::date
    end;
    v_new_distance := case
      when v_item -> 'new_distance_km' is null
           or jsonb_typeof(v_item -> 'new_distance_km') = 'null' then null
      else (v_item ->> 'new_distance_km')::numeric
    end;
    if v_new_distance is not null
       and (v_new_distance < 0 or v_new_distance > 99999.99) then
      raise exception 'invalid workout distance'
        using errcode = 'check_violation';
    end if;
    if v_new_date is null and v_new_distance is null then
      raise exception 'adjustment has no change'
        using errcode = 'check_violation';
    end if;
    v_reason := left(nullif(btrim(v_item ->> 'reason'), ''), 500);

    update public.scheduled_workouts
    set date = coalesce(v_new_date, date),
        target_distance_km = coalesce(v_new_distance, target_distance_km),
        description = case
          when v_reason is null then description
          else 'Đã điều chỉnh bởi AI: ' || v_reason
        end
    where id = v_id;
  end loop;

  select min(w.date), max(w.date)
  into v_min_date, v_max_date
  from public.scheduled_workouts w
  where w.schedule_id = v_schedule_id;

  update public.training_schedules
  set last_ai_adjusted_at = now(),
      start_date = least(coalesce(start_date, v_min_date), v_min_date),
      end_date = greatest(coalesce(end_date, v_max_date), v_max_date)
  where id = v_schedule_id
    and user_id = auth.uid();
end;
$$;

revoke all on function
  public.enqueue_training_plan_job(uuid, text, date, date, text),
  public.claim_training_plan_job(uuid),
  public.claim_next_training_plan_jobs(integer),
  public.finish_training_plan_job(uuid, text),
  public.complete_training_plan_job(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function
  public.enqueue_training_plan_job(uuid, text, date, date, text),
  public.claim_training_plan_job(uuid),
  public.claim_next_training_plan_jobs(integer),
  public.finish_training_plan_job(uuid, text),
  public.complete_training_plan_job(uuid, jsonb)
  to service_role;

revoke all on function
  public.reschedule_scheduled_workout(uuid, date, time, boolean),
  public.apply_training_plan_adjustments(jsonb)
  from public, anon;
grant execute on function
  public.reschedule_scheduled_workout(uuid, date, time, boolean),
  public.apply_training_plan_adjustments(jsonb)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
