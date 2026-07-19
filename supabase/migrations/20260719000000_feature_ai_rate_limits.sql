-- Per-feature AI quotas. The previous ai_rate_limit row combined chat, plans,
-- and vision into one counter, so an expensive image request could consume the
-- user's unrelated chat allowance. Keep the legacy table for rollback/audit;
-- all new access checks use this feature-scoped table.

create table if not exists public.ai_feature_rate_limit (
  user_id uuid not null references auth.users(id) on delete cascade,
  feature text not null check (
    feature in ('onboarding', 'chat', 'plan', 'vision', 'food')
  ),
  minute_start timestamptz not null default now(),
  minute_count integer not null default 0 check (minute_count >= 0),
  day_start timestamptz not null default now(),
  day_count integer not null default 0 check (day_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, feature)
);

alter table public.ai_feature_rate_limit enable row level security;
revoke all on table public.ai_feature_rate_limit
  from public, anon, authenticated;
grant all on table public.ai_feature_rate_limit to service_role;

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
  rec public.ai_feature_rate_limit;
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
    return jsonb_build_object(
      'allowed', false, 'reason', 'no_user', 'tier', null
    );
  end if;
  if p_feature not in ('onboarding', 'chat', 'plan', 'vision', 'food') then
    return jsonb_build_object(
      'allowed', false, 'reason', 'invalid_feature', 'tier', null
    );
  end if;

  select exists (
    select 1
    from public.user_subscriptions
    where user_id = p_user_id
      and status = 'active'
      and end_date > now_ts
  ) into v_is_paid;

  if v_is_paid then
    v_tier := 'paid';
  else
    select trial_ends_at
    into v_trial_ends
    from public.profiles
    where id = p_user_id;
    v_tier := case
      when v_trial_ends is not null and now_ts < v_trial_ends then 'trial'
      else 'free'
    end;
  end if;

  if v_tier = 'free' then
    -- Hard ceilings keep an accidental environment change from making the
    -- private Modal endpoint an unbounded free-tier provider.
    v_max_min := least(5, greatest(1, coalesce(p_free_max_per_min, 1)));
    v_max_day := least(50, greatest(1, coalesce(p_free_max_per_day, 1)));
  else
    v_max_min := least(100, greatest(1, coalesce(p_max_per_min, 1)));
    v_max_day := least(10000, greatest(1, coalesce(p_max_per_day, 1)));
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      'ai-feature-rate:' || p_user_id::text || ':' || p_feature,
      0
    )
  );

  select *
  into rec
  from public.ai_feature_rate_limit
  where user_id = p_user_id and feature = p_feature
  for update;

  if not found then
    insert into public.ai_feature_rate_limit(
      user_id, feature, minute_start, minute_count,
      day_start, day_count, updated_at
    ) values (
      p_user_id, p_feature, now_ts, 1, now_ts, 1, now_ts
    );
    return jsonb_build_object(
      'allowed', true,
      'reason', null,
      'tier', v_tier,
      'minute_count', 1,
      'day_count', 1,
      'minute_limit', v_max_min,
      'day_limit', v_max_day
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

  update public.ai_feature_rate_limit
  set minute_start = v_minute_start,
      minute_count = v_minute_count,
      day_start = v_day_start,
      day_count = v_day_count,
      updated_at = now_ts
  where user_id = p_user_id and feature = p_feature;

  return jsonb_build_object(
    'allowed', v_allowed,
    'reason', v_reason,
    'tier', v_tier,
    'minute_count', v_minute_count,
    'day_count', v_day_count,
    'minute_limit', v_max_min,
    'day_limit', v_max_day
  );
end;
$$;

revoke all on function
  public.check_ai_access(uuid, text, integer, integer, integer, integer)
  from public, anon, authenticated;
grant execute on function
  public.check_ai_access(uuid, text, integer, integer, integer, integer)
  to service_role;
