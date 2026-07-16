-- P0 production security hotfix.
--
-- This migration closes authorization gaps that cannot be fixed by row-level
-- policies alone: protected profile columns, aggregate/badge writes, social
-- consent, cross-user recovery feedback, webhook replay handling, and payment
-- concurrency.

set client_min_messages = warning;

-- ---------------------------------------------------------------------------
-- Profiles: authenticated users may update only an explicit presentation and
-- health-preference allowlist. Entitlement/identity/provider-owned fields stay
-- writable only by trusted triggers and service-role code.
-- ---------------------------------------------------------------------------
revoke insert, update on table public.profiles
  from public, anon, authenticated;

grant update (
  display_name,
  weight_kg,
  max_hr,
  bmi,
  has_completed_onboarding,
  height_cm,
  target_weight_kg,
  start_weight_kg,
  preferred_pace_min_per_km,
  city,
  bio,
  looking_for_partner,
  gender,
  coach_name,
  coach_persona,
  leaderboard_visible
) on table public.profiles to authenticated;

-- Client profile insertion is unnecessary because handle_new_user() creates the
-- row atomically. Keeping INSERT revoked also protects canonical_email and the
-- trial anchor if that trigger is ever delayed or changed.

create or replace function public.get_entitlement_status()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'tier',
      case
        when exists (
          select 1
          from public.user_subscriptions us
          where us.user_id = auth.uid()
            and us.status = 'active'
            and us.end_date > now()
        ) then 'paid'
        when p.trial_ends_at is not null and p.trial_ends_at > now() then 'trial'
        else 'free'
      end,
    'trial_ends_at', p.trial_ends_at
  )
  from public.profiles p
  where p.id = auth.uid();
$$;

revoke all on function public.get_entitlement_status() from public, anon;
grant execute on function public.get_entitlement_status() to authenticated;

-- ---------------------------------------------------------------------------
-- Server-maintained activity aggregates: no direct Data API access.
-- ---------------------------------------------------------------------------
alter table public.user_activity_stats enable row level security;
alter table public.user_activity_stats force row level security;
revoke all on table public.user_activity_stats from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Badges are awarded only by trusted trigger/function code.
-- ---------------------------------------------------------------------------
drop policy if exists "Badges are self-insertable" on public.badges;
drop policy if exists "Badges are self-updatable" on public.badges;
drop policy if exists "Badges are self-deletable" on public.badges;
revoke insert, update, delete, truncate, references, trigger
  on table public.badges from public, anon, authenticated;

-- Remove legacy/unrecognized rows before enforcing the catalog relationship.
delete from public.badges b
where b.code is null
   or not exists (
     select 1 from public.badge_definitions d where d.code = b.code
   );

alter table public.badges alter column code set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'badges_code_fkey'
      and conrelid = 'public.badges'::regclass
  ) then
    alter table public.badges
      add constraint badges_code_fkey
      foreign key (code) references public.badge_definitions(code);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Social matching: consent-preserving RPC with durable abuse accounting.
-- ---------------------------------------------------------------------------
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_distinct check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;
alter table public.user_blocks force row level security;

drop policy if exists "Users manage their own blocks" on public.user_blocks;
create policy "Users manage their own blocks"
on public.user_blocks
for all
to authenticated
using (blocker_id = auth.uid())
with check (blocker_id = auth.uid());

revoke all on table public.user_blocks from public, anon;
grant select, insert, delete on table public.user_blocks to authenticated;

create table if not exists private.run_match_request_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists run_match_request_events_user_created_idx
  on private.run_match_request_events(user_id, created_at desc);

revoke all on table private.run_match_request_events
  from public, anon, authenticated;

drop policy if exists "Matches insertable by requester" on public.run_matches;
drop policy if exists "Matches updatable by participants" on public.run_matches;
drop policy if exists "Matches deletable by participants" on public.run_matches;
revoke insert, update, delete on table public.run_matches
  from public, anon, authenticated;

create or replace function public.request_run_match(p_addressee_id uuid)
returns uuid
language plpgsql
security definer
set search_path = private, public
as $$
declare
  v_requester uuid := auth.uid();
  v_match_id uuid;
begin
  if v_requester is null then
    raise exception 'authentication required' using errcode = 'insufficient_privilege';
  end if;
  if p_addressee_id is null or p_addressee_id = v_requester then
    raise exception 'invalid match recipient' using errcode = 'check_violation';
  end if;

  -- Serialize requests from one user so rate limits and duplicate checks remain
  -- atomic under concurrent browser tabs.
  perform pg_advisory_xact_lock(hashtextextended(v_requester::text, 0));

  delete from private.run_match_request_events
  where created_at < now() - interval '30 days';

  if (
    select count(*) >= 10
    from private.run_match_request_events
    where user_id = v_requester
      and created_at >= now() - interval '1 hour'
  ) then
    raise exception 'match request rate limit exceeded'
      using errcode = 'program_limit_exceeded';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_addressee_id
      and p.looking_for_partner = true
  ) then
    raise exception 'recipient is not accepting match requests'
      using errcode = 'insufficient_privilege';
  end if;

  if exists (
    select 1
    from public.user_blocks b
    where (b.blocker_id = v_requester and b.blocked_id = p_addressee_id)
       or (b.blocker_id = p_addressee_id and b.blocked_id = v_requester)
  ) then
    raise exception 'match request is blocked'
      using errcode = 'insufficient_privilege';
  end if;

  if exists (
    select 1
    from public.run_matches m
    where (m.requester_id = v_requester and m.addressee_id = p_addressee_id)
       or (m.requester_id = p_addressee_id and m.addressee_id = v_requester)
  ) then
    raise exception 'match already exists' using errcode = 'unique_violation';
  end if;

  insert into private.run_match_request_events(user_id, addressee_id)
  values (v_requester, p_addressee_id);

  insert into public.run_matches(requester_id, addressee_id, status)
  values (v_requester, p_addressee_id, 'pending')
  returning id into v_match_id;

  return v_match_id;
end;
$$;

revoke all on function public.request_run_match(uuid) from public, anon;
grant execute on function public.request_run_match(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Recovery feedback must reference an activity owned by the same user.
-- ---------------------------------------------------------------------------
delete from public.activity_recovery_feedback f
where not exists (
  select 1
  from public.activities a
  where a.id = f.activity_id and a.user_id = f.user_id
);

create unique index if not exists activities_id_user_id_unique
  on public.activities(id, user_id);

alter table public.activity_recovery_feedback
  drop constraint if exists activity_recovery_feedback_activity_id_fkey;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'activity_recovery_feedback_activity_owner_fkey'
      and conrelid = 'public.activity_recovery_feedback'::regclass
  ) then
    alter table public.activity_recovery_feedback
      add constraint activity_recovery_feedback_activity_owner_fkey
      foreign key (activity_id, user_id)
      references public.activities(id, user_id)
      on delete cascade;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Entitlement RPC: accept only server-recognized feature classes. Vision,
-- training-plan, and food workloads are always paid/trial features.
-- ---------------------------------------------------------------------------
create or replace function public.check_ai_access(
  p_user_id uuid,
  p_feature text,
  p_max_per_min integer,
  p_max_per_day integer,
  p_free_max_per_min integer,
  p_free_max_per_day integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rec public.ai_rate_limit;
  now_ts timestamptz := now();
  v_tier text;
  v_is_paid boolean;
  v_trial_ends timestamptz;
  v_max_min integer;
  v_max_day integer;
  v_allowed boolean := true;
  v_reason text := null;
  v_minute_start timestamptz;
  v_minute_count integer;
  v_day_start timestamptz;
  v_day_count integer;
begin
  if p_user_id is null then
    return jsonb_build_object('allowed', false, 'reason', 'no_user', 'tier', null);
  end if;
  if p_feature not in ('chat', 'plan', 'vision', 'food') then
    return jsonb_build_object('allowed', false, 'reason', 'invalid_feature', 'tier', null);
  end if;

  select exists (
    select 1
    from public.user_subscriptions
    where user_id = p_user_id and status = 'active' and end_date > now_ts
  ) into v_is_paid;

  if v_is_paid then
    v_tier := 'paid';
  else
    select trial_ends_at
    into v_trial_ends
    from public.profiles
    where id = p_user_id;

    if v_trial_ends is not null and now_ts < v_trial_ends then
      v_tier := 'trial';
    else
      v_tier := 'free';
    end if;
  end if;

  if v_tier = 'free' and p_feature <> 'chat' then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'upgrade_required',
      'tier', v_tier
    );
  end if;

  if v_tier = 'free' then
    v_max_min := greatest(1, p_free_max_per_min);
    v_max_day := greatest(1, p_free_max_per_day);
  else
    v_max_min := greatest(1, p_max_per_min);
    v_max_day := greatest(1, p_max_per_day);
  end if;

  -- Serialize the first insert as well as later counter updates. Without this
  -- lock, two simultaneous first requests can both observe no row and race on
  -- the ai_rate_limit primary key.
  perform pg_advisory_xact_lock(
    hashtextextended('ai-rate:' || p_user_id::text, 0)
  );

  select *
  into rec
  from public.ai_rate_limit
  where user_id = p_user_id
  for update;

  if not found then
    insert into public.ai_rate_limit(
      user_id, minute_start, minute_count, day_start, day_count, updated_at
    )
    values (p_user_id, now_ts, 1, now_ts, 1, now_ts);

    return jsonb_build_object(
      'allowed', true,
      'reason', null,
      'tier', v_tier,
      'day_count', 1
    );
  end if;

  v_minute_start := rec.minute_start;
  v_minute_count := rec.minute_count;
  v_day_start := rec.day_start;
  v_day_count := rec.day_count;

  if now_ts - v_minute_start >= interval '1 minute' then
    v_minute_start := now_ts;
    v_minute_count := 0;
  end if;
  if now_ts - v_day_start >= interval '1 day' then
    v_day_start := now_ts;
    v_day_count := 0;
  end if;

  if v_minute_count >= v_max_min then
    v_allowed := false;
    v_reason := 'minute';
  elsif v_day_count >= v_max_day then
    v_allowed := false;
    v_reason := 'day';
  end if;

  if v_allowed then
    v_minute_count := v_minute_count + 1;
    v_day_count := v_day_count + 1;
  end if;

  update public.ai_rate_limit
  set minute_start = v_minute_start,
      minute_count = v_minute_count,
      day_start = v_day_start,
      day_count = v_day_count,
      updated_at = now_ts
  where user_id = p_user_id;

  return jsonb_build_object(
    'allowed', v_allowed,
    'reason', v_reason,
    'tier', v_tier,
    'day_count', v_day_count
  );
end;
$$;

revoke all on function
  public.check_ai_access(uuid, text, integer, integer, integer, integer)
  from public, anon, authenticated;
grant execute on function
  public.check_ai_access(uuid, text, integer, integer, integer, integer)
  to service_role;

-- ---------------------------------------------------------------------------
-- Strava reconciliation state and durable webhook queue.
-- ---------------------------------------------------------------------------
alter table public.activities
  add column if not exists source_status text not null default 'active',
  add column if not exists source_deleted_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'activities_source_status_check'
      and conrelid = 'public.activities'::regclass
  ) then
    alter table public.activities
      add constraint activities_source_status_check
      check (source_status in ('active', 'deleted_at_source'));
  end if;
end;
$$;

create table if not exists private.strava_webhook_jobs (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  subscription_id bigint not null,
  owner_id text not null,
  object_id bigint not null,
  object_type text not null,
  aspect_type text not null check (aspect_type in ('create', 'update', 'delete')),
  event_time timestamptz,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed', 'failed')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  locked_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists strava_webhook_jobs_pending_idx
  on private.strava_webhook_jobs(status, next_attempt_at, created_at);
create index if not exists strava_webhook_jobs_owner_created_idx
  on private.strava_webhook_jobs(owner_id, created_at desc);

revoke all on table private.strava_webhook_jobs
  from public, anon, authenticated;

create or replace function public.enqueue_strava_webhook_job(
  p_event_key text,
  p_subscription_id bigint,
  p_owner_id text,
  p_object_id bigint,
  p_object_type text,
  p_aspect_type text,
  p_event_time timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = private, public
as $$
declare
  v_job_id uuid;
begin
  if p_event_key is null or char_length(p_event_key) > 300
     or p_subscription_id is null
     or p_owner_id is null or p_owner_id !~ '^[0-9]+$'
     or p_object_id is null or p_object_id <= 0
     or p_object_type <> 'activity'
     or p_aspect_type not in ('create', 'update', 'delete') then
    return jsonb_build_object('accepted', false, 'reason', 'invalid');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('strava:' || p_owner_id, 0));

  delete from private.strava_webhook_jobs
  where status in ('completed', 'failed')
    and created_at < now() - interval '30 days';

  if exists (
    select 1 from private.strava_webhook_jobs where event_key = p_event_key
  ) then
    return jsonb_build_object('accepted', false, 'reason', 'duplicate');
  end if;

  if (
    select count(*) >= 30
    from private.strava_webhook_jobs
    where owner_id = p_owner_id
      and created_at >= now() - interval '1 minute'
  ) then
    return jsonb_build_object('accepted', false, 'reason', 'rate_limited');
  end if;

  insert into private.strava_webhook_jobs(
    event_key,
    subscription_id,
    owner_id,
    object_id,
    object_type,
    aspect_type,
    event_time
  )
  values (
    p_event_key,
    p_subscription_id,
    p_owner_id,
    p_object_id,
    p_object_type,
    p_aspect_type,
    p_event_time
  )
  returning id into v_job_id;

  return jsonb_build_object(
    'accepted', true,
    'reason', null,
    'job_id', v_job_id
  );
end;
$$;

create or replace function public.claim_strava_webhook_job(p_job_id uuid)
returns table (
  id uuid,
  owner_id text,
  object_id bigint,
  object_type text,
  aspect_type text,
  event_time timestamptz,
  attempts integer
)
language sql
security definer
set search_path = private, public
as $$
  update private.strava_webhook_jobs j
  set status = 'processing',
      attempts = attempts + 1,
      locked_at = now(),
      updated_at = now()
  where j.id = p_job_id
    and j.attempts < 5
    and (
      (j.status = 'pending' and j.next_attempt_at <= now())
      or (j.status = 'processing' and j.locked_at < now() - interval '10 minutes')
    )
  returning j.id, j.owner_id, j.object_id, j.object_type, j.aspect_type,
            j.event_time, j.attempts;
$$;

create or replace function public.claim_next_strava_webhook_jobs(
  p_limit integer default 10
)
returns table (
  id uuid,
  owner_id text,
  object_id bigint,
  object_type text,
  aspect_type text,
  event_time timestamptz,
  attempts integer
)
language sql
security definer
set search_path = private, public
as $$
  with candidates as (
    select j.id
    from private.strava_webhook_jobs j
    where j.attempts < 5
      and (
        (j.status = 'pending' and j.next_attempt_at <= now())
        or (j.status = 'processing' and j.locked_at < now() - interval '10 minutes')
    )
    order by j.created_at
    limit greatest(1, least(coalesce(p_limit, 10), 50))
    for update skip locked
  )
  update private.strava_webhook_jobs j
  set status = 'processing',
      attempts = attempts + 1,
      locked_at = now(),
      updated_at = now()
  from candidates c
  where j.id = c.id
  returning j.id, j.owner_id, j.object_id, j.object_type, j.aspect_type,
            j.event_time, j.attempts;
$$;

create or replace function public.finish_strava_webhook_job(
  p_job_id uuid,
  p_success boolean,
  p_error text default null
) returns void
language plpgsql
security definer
set search_path = private, public
as $$
declare
  v_attempts integer;
begin
  select attempts into v_attempts
  from private.strava_webhook_jobs
  where id = p_job_id
  for update;

  if not found then
    return;
  end if;

  if p_success then
    update private.strava_webhook_jobs
    set status = 'completed',
        locked_at = null,
        last_error = null,
        updated_at = now()
    where id = p_job_id;
  elsif v_attempts >= 5 then
    update private.strava_webhook_jobs
    set status = 'failed',
        locked_at = null,
        last_error = left(coalesce(p_error, 'processing failed'), 500),
        next_attempt_at = 'infinity'::timestamptz,
        updated_at = now()
    where id = p_job_id;
  else
    update private.strava_webhook_jobs
    set status = 'pending',
        locked_at = null,
        last_error = left(coalesce(p_error, 'processing failed'), 500),
        next_attempt_at = now() + make_interval(
          secs => least(900, (30 * power(2, greatest(0, v_attempts - 1)))::integer)
        ),
        updated_at = now()
    where id = p_job_id;
  end if;
end;
$$;

revoke all on function public.enqueue_strava_webhook_job(
  text, bigint, text, bigint, text, text, timestamptz
) from public, anon, authenticated;
revoke all on function public.claim_strava_webhook_job(uuid)
  from public, anon, authenticated;
revoke all on function public.claim_next_strava_webhook_jobs(integer)
  from public, anon, authenticated;
revoke all on function public.finish_strava_webhook_job(uuid, boolean, text)
  from public, anon, authenticated;
grant execute on function public.enqueue_strava_webhook_job(
  text, bigint, text, bigint, text, text, timestamptz
) to service_role;
grant execute on function public.claim_strava_webhook_job(uuid) to service_role;
grant execute on function public.claim_next_strava_webhook_jobs(integer)
  to service_role;
grant execute on function public.finish_strava_webhook_job(uuid, boolean, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- PayOS: serialize entitlement updates per user and enforce one active row.
-- ---------------------------------------------------------------------------
alter table public.payment_orders
  add column if not exists idempotency_key text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'payment_orders_idempotency_key_check'
      and conrelid = 'public.payment_orders'::regclass
  ) then
    alter table public.payment_orders
      add constraint payment_orders_idempotency_key_check
      check (
        idempotency_key is null
        or idempotency_key ~ '^[A-Za-z0-9._:-]{16,120}$'
      );
  end if;
end;
$$;

create unique index if not exists payment_orders_user_idempotency_unique
  on public.payment_orders(user_id, idempotency_key)
  where idempotency_key is not null;

create or replace function public.create_payment_order(
  p_user_id uuid,
  p_plan_id uuid,
  p_idempotency_key text
)
returns table (
  order_code bigint,
  amount integer,
  plan_id uuid,
  plan_name text,
  duration_type text,
  reused boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan public.subscription_plans;
  v_existing public.payment_orders;
begin
  if p_user_id is null
     or p_idempotency_key is null
     or p_idempotency_key !~ '^[A-Za-z0-9._:-]{16,120}$' then
    raise exception 'invalid payment request'
      using errcode = 'check_violation';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('payos-create:' || p_user_id::text, 0)
  );

  select *
  into v_plan
  from public.subscription_plans
  where id = p_plan_id and is_active = true and price > 0;
  if not found then
    raise exception 'invalid subscription plan'
      using errcode = 'check_violation';
  end if;

  select *
  into v_existing
  from public.payment_orders
  where user_id = p_user_id
    and idempotency_key = p_idempotency_key
  for update;

  if found and v_existing.plan_id <> p_plan_id then
    raise exception 'payment idempotency key conflicts with another plan'
      using errcode = 'unique_violation';
  end if;

  if found and v_existing.status = 'pending' then
    order_code := v_existing.order_code;
    amount := v_existing.amount;
    plan_id := v_existing.plan_id;
    plan_name := v_plan.name;
    duration_type := v_plan.duration_type;
    reused := true;
    return next;
    return;
  elsif found then
    raise exception 'payment idempotency key was already consumed'
      using errcode = 'unique_violation';
  end if;

  if (
    select count(*) >= 5
    from public.payment_orders
    where user_id = p_user_id
      and created_at >= now() - interval '10 minutes'
  ) then
    raise exception 'payment creation rate limit exceeded'
      using errcode = 'program_limit_exceeded';
  end if;

  order_code := nextval('public.payment_order_code_seq');
  amount := round(v_plan.price)::integer;
  plan_id := v_plan.id;
  plan_name := v_plan.name;
  duration_type := v_plan.duration_type;
  reused := false;

  insert into public.payment_orders(
    order_code,
    user_id,
    plan_id,
    amount,
    status,
    idempotency_key
  )
  values (
    order_code,
    p_user_id,
    plan_id,
    amount,
    'pending',
    p_idempotency_key
  );
  return next;
end;
$$;

create or replace function public.cancel_payment_order(
  p_order_code bigint,
  p_user_id uuid
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.payment_orders
  set status = 'cancelled',
      idempotency_key = null
  where order_code = p_order_code
    and user_id = p_user_id
    and status = 'pending';
$$;

revoke all on function public.create_payment_order(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.cancel_payment_order(bigint, uuid)
  from public, anon, authenticated;
grant execute on function public.create_payment_order(uuid, uuid, text)
  to service_role;
grant execute on function public.cancel_payment_order(bigint, uuid)
  to service_role;

with ranked_active as (
  select id,
         row_number() over (
           partition by user_id
           order by end_date desc, created_at desc, id desc
         ) as row_num
  from public.user_subscriptions
  where status = 'active'
)
update public.user_subscriptions us
set status = 'cancelled'
from ranked_active r
where us.id = r.id and r.row_num > 1;

create unique index if not exists user_subscriptions_one_active_per_user
  on public.user_subscriptions(user_id)
  where status = 'active';

create or replace function public.process_payos_payment(
  p_order_code bigint,
  p_amount integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.payment_orders;
  v_duration text;
  v_base timestamptz;
  v_end timestamptz;
begin
  select *
  into o
  from public.payment_orders
  where order_code = p_order_code
  for update;

  if not found then
    return jsonb_build_object('processed', false, 'reason', 'order_not_found');
  end if;
  if o.status = 'paid' then
    return jsonb_build_object('processed', false, 'reason', 'already_paid');
  end if;
  if o.status <> 'pending' then
    return jsonb_build_object('processed', false, 'reason', 'order_not_pending');
  end if;
  if o.amount <> p_amount then
    raise exception 'payment amount mismatch' using errcode = 'check_violation';
  end if;

  -- Different paid orders for the same user can arrive concurrently. This lock
  -- ensures each order sees and extends the entitlement produced by the one
  -- before it.
  perform pg_advisory_xact_lock(hashtextextended('payos:' || o.user_id::text, 0));

  select duration_type
  into v_duration
  from public.subscription_plans
  where id = o.plan_id;

  if v_duration is null then
    raise exception 'subscription plan not found'
      using errcode = 'foreign_key_violation';
  end if;

  perform 1
  from public.user_subscriptions
  where user_id = o.user_id and status = 'active'
  for update;

  select greatest(now(), coalesce(max(end_date), now()))
  into v_base
  from public.user_subscriptions
  where user_id = o.user_id and status = 'active';

  v_end := v_base + case v_duration
    when 'weekly' then interval '7 days'
    when 'yearly' then interval '365 days'
    else interval '30 days'
  end;

  update public.user_subscriptions
  set status = 'cancelled'
  where user_id = o.user_id and status = 'active';

  insert into public.user_subscriptions(
    user_id, plan_id, status, start_date, end_date
  )
  values (o.user_id, o.plan_id, 'active', now(), v_end);

  update public.payment_orders
  set status = 'paid', paid_at = now()
  where order_code = p_order_code;

  return jsonb_build_object('processed', true, 'end_date', v_end);
end;
$$;

revoke all on function public.process_payos_payment(bigint, integer)
  from public, anon, authenticated;
grant execute on function public.process_payos_payment(bigint, integer)
  to service_role;

select pg_notify('pgrst', 'reload schema');
