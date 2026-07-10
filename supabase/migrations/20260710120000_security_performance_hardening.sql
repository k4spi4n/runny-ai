-- Security and performance hardening.  This migration deliberately treats all
-- OAuth credentials previously stored in `profiles` as compromised browser data:
-- connections are retained as disconnected metadata and must be authorised again.

set client_min_messages = warning;

-- ---------------------------------------------------------------------------
-- Private integration credentials and one-time OAuth state.
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.strava_connections (
  user_id uuid primary key references auth.users(id) on delete cascade,
  athlete_id text unique,
  access_token text,
  refresh_token text,
  expires_at timestamptz,
  requires_reauth boolean not null default true,
  connected_at timestamptz,
  updated_at timestamptz not null default now()
);

insert into private.strava_connections (user_id, athlete_id, requires_reauth)
select id, strava_id, true
from (
  select distinct on (strava_id) id, strava_id
  from public.profiles
  where strava_id is not null
  order by strava_id, created_at asc, id asc
) legacy_connection
on conflict (user_id) do update set
  athlete_id = excluded.athlete_id,
  requires_reauth = true,
  access_token = null,
  refresh_token = null,
  expires_at = null,
  updated_at = now();

create table if not exists private.oauth_states (
  state text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('strava')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists oauth_states_expires_at_idx on private.oauth_states(expires_at);

create or replace function public.get_strava_connection(p_user_id uuid)
returns table(user_id uuid, athlete_id text, access_token text, refresh_token text, expires_at timestamptz, requires_reauth boolean)
language sql security definer set search_path = private, public as $$
  select user_id, athlete_id, access_token, refresh_token, expires_at, requires_reauth
  from private.strava_connections where user_id = p_user_id;
$$;
create or replace function public.get_strava_connection_by_athlete(p_athlete_id text)
returns table(user_id uuid, athlete_id text, access_token text, refresh_token text, expires_at timestamptz, requires_reauth boolean)
language sql security definer set search_path = private, public as $$
  select user_id, athlete_id, access_token, refresh_token, expires_at, requires_reauth
  from private.strava_connections where athlete_id = p_athlete_id and not requires_reauth;
$$;
create or replace function public.save_strava_connection(p_user_id uuid, p_athlete_id text, p_access_token text, p_refresh_token text, p_expires_at timestamptz)
returns void language sql security definer set search_path = private, public as $$
  insert into private.strava_connections(user_id, athlete_id, access_token, refresh_token, expires_at, requires_reauth, connected_at, updated_at)
  values (p_user_id, p_athlete_id, p_access_token, p_refresh_token, p_expires_at, false, now(), now())
  on conflict (user_id) do update set athlete_id = excluded.athlete_id, access_token = excluded.access_token,
    refresh_token = excluded.refresh_token, expires_at = excluded.expires_at, requires_reauth = false, connected_at = now(), updated_at = now();
$$;
create or replace function public.disconnect_strava_connection(p_user_id uuid)
returns void language sql security definer set search_path = private, public as $$
  update private.strava_connections set athlete_id = null, access_token = null, refresh_token = null,
    expires_at = null, requires_reauth = true, updated_at = now() where user_id = p_user_id;
$$;
create or replace function public.create_oauth_state(p_user_id uuid, p_state text, p_provider text)
returns void language sql security definer set search_path = private, public as $$
  delete from private.oauth_states where expires_at < now() or user_id = p_user_id and provider = p_provider;
  insert into private.oauth_states(state, user_id, provider, expires_at) values (p_state, p_user_id, p_provider, now() + interval '10 minutes');
$$;
create or replace function public.consume_oauth_state(p_user_id uuid, p_state text, p_provider text)
returns boolean language plpgsql security definer set search_path = private, public as $$
begin
  delete from private.oauth_states where state = p_state and user_id = p_user_id and provider = p_provider and expires_at >= now();
  return found;
end;
$$;

alter table public.profiles
  drop column if exists strava_access_token,
  drop column if exists strava_refresh_token,
  drop column if exists strava_expires_at;
-- Existing credentials are intentionally not copied, so the public status hint
-- must not claim that a legacy connection is still usable.
update public.profiles set strava_id = null where strava_id is not null;

-- Keep the non-secret athlete identifier as a connection-status hint only.
alter table public.profiles add column if not exists leaderboard_visible boolean not null default false;
alter table public.profiles add constraint profiles_display_name_length_check
  check (display_name is null or char_length(display_name) <= 80) not valid;
alter table public.profiles add constraint profiles_social_text_length_check
  check ((city is null or char_length(city) <= 120) and (bio is null or char_length(bio) <= 500)) not valid;

-- ---------------------------------------------------------------------------
-- Data integrity and bounded user-controlled payloads.
-- ---------------------------------------------------------------------------
alter table public.activities add constraint activities_nonnegative_check
  check (distance_km >= 0 and duration_min >= 0 and (elevation_gain_m is null or elevation_gain_m >= 0)
    and (avg_hr is null or avg_hr between 0 and 300)
    and (avg_cadence is null or avg_cadence between 0 and 300)) not valid;
alter table public.activities add constraint activities_text_length_check
  check ((name is null or char_length(name) <= 160) and (notes is null or char_length(notes) <= 4000)) not valid;
alter table public.activities add constraint activities_data_points_size_check
  check (data_points is null or pg_column_size(data_points) <= 262144) not valid;

alter table public.scheduled_workouts add constraint scheduled_workouts_status_check
  check (status in ('planned', 'completed', 'skipped', 'rescheduled')) not valid;
alter table public.scheduled_workouts add constraint scheduled_workouts_nonnegative_check
  check ((target_distance_km is null or target_distance_km >= 0)
    and (target_duration_min is null or target_duration_min >= 0)
    and (target_pace_min_per_km is null or target_pace_min_per_km >= 0)) not valid;
alter table public.weight_logs add constraint weight_logs_positive_check
  check (weight_kg > 0) not valid;
alter table public.meal_logs add constraint meal_logs_nonnegative_check
  check (calories >= 0 and protein >= 0 and carbs >= 0 and fat >= 0 and amount > 0) not valid;

create or replace function public.assert_related_row_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  related_user uuid;
begin
  if tg_table_name = 'activities' and new.shoe_id is not null then
    select user_id into related_user from public.shoes where id = new.shoe_id;
    if related_user is distinct from new.user_id then
      raise exception 'shoe must belong to the activity owner' using errcode = 'foreign_key_violation';
    end if;
  elsif tg_table_name = 'scheduled_workouts' then
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
  elsif tg_table_name = 'run_reminders' then
    select user_id into related_user from public.scheduled_workouts where id = new.workout_id;
    if related_user is distinct from new.user_id then
      raise exception 'workout must belong to the reminder owner' using errcode = 'foreign_key_violation';
    end if;
  elsif tg_table_name = 'ai_insights' and new.activity_id is not null then
    select user_id into related_user from public.activities where id = new.activity_id;
    if related_user is distinct from new.user_id then
      raise exception 'activity must belong to the insight owner' using errcode = 'foreign_key_violation';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists assert_activity_related_owner on public.activities;
create trigger assert_activity_related_owner before insert or update of user_id, shoe_id on public.activities
for each row execute function public.assert_related_row_owner();
drop trigger if exists assert_workout_related_owner on public.scheduled_workouts;
create trigger assert_workout_related_owner before insert or update of user_id, schedule_id, activity_id on public.scheduled_workouts
for each row execute function public.assert_related_row_owner();
drop trigger if exists assert_reminder_related_owner on public.run_reminders;
create trigger assert_reminder_related_owner before insert or update of user_id, workout_id on public.run_reminders
for each row execute function public.assert_related_row_owner();
drop trigger if exists assert_insight_related_owner on public.ai_insights;
create trigger assert_insight_related_owner before insert or update of user_id, activity_id on public.ai_insights
for each row execute function public.assert_related_row_owner();

-- ---------------------------------------------------------------------------
-- Incremental aggregates keep read hot paths off the activity event table.
-- ---------------------------------------------------------------------------
create table if not exists public.user_activity_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  total_distance_km numeric(12,2) not null default 0,
  total_duration_min numeric(12,2) not null default 0,
  activity_count bigint not null default 0,
  hr_sum bigint not null default 0,
  hr_count bigint not null default 0,
  max_single_distance_km numeric(7,2) not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.user_activity_stats (user_id, total_distance_km, total_duration_min, activity_count, hr_sum, hr_count, max_single_distance_km)
select user_id, coalesce(sum(distance_km), 0), coalesce(sum(duration_min), 0), count(*),
       coalesce(sum(avg_hr), 0), count(avg_hr), coalesce(max(distance_km), 0)
from public.activities
group by user_id
on conflict (user_id) do update set
  total_distance_km = excluded.total_distance_km,
  total_duration_min = excluded.total_duration_min,
  activity_count = excluded.activity_count,
  hr_sum = excluded.hr_sum,
  hr_count = excluded.hr_count,
  max_single_distance_km = excluded.max_single_distance_km,
  updated_at = now();

create or replace function public.maintain_activity_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_needs_max_refresh boolean := false;
begin
  v_user_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  insert into public.user_activity_stats(user_id) values (v_user_id)
  on conflict (user_id) do nothing;

  if tg_op = 'INSERT' then
    update public.user_activity_stats set
      total_distance_km = total_distance_km + new.distance_km,
      total_duration_min = total_duration_min + new.duration_min,
      activity_count = activity_count + 1,
      hr_sum = hr_sum + coalesce(new.avg_hr, 0),
      hr_count = hr_count + case when new.avg_hr is null then 0 else 1 end,
      max_single_distance_km = greatest(max_single_distance_km, new.distance_km),
      updated_at = now()
    where user_id = v_user_id;
  elsif tg_op = 'DELETE' then
    update public.user_activity_stats set
      total_distance_km = greatest(0, total_distance_km - old.distance_km),
      total_duration_min = greatest(0, total_duration_min - old.duration_min),
      activity_count = greatest(0, activity_count - 1),
      hr_sum = greatest(0, hr_sum - coalesce(old.avg_hr, 0)),
      hr_count = greatest(0, hr_count - case when old.avg_hr is null then 0 else 1 end),
      updated_at = now()
    where user_id = v_user_id;
    v_needs_max_refresh := true;
  else
    if new.user_id <> old.user_id then
      raise exception 'activity owner cannot change' using errcode = 'check_violation';
    end if;
    update public.user_activity_stats set
      total_distance_km = greatest(0, total_distance_km + new.distance_km - old.distance_km),
      total_duration_min = greatest(0, total_duration_min + new.duration_min - old.duration_min),
      hr_sum = greatest(0, hr_sum + coalesce(new.avg_hr, 0) - coalesce(old.avg_hr, 0)),
      hr_count = greatest(0, hr_count + case when new.avg_hr is null then 0 else 1 end - case when old.avg_hr is null then 0 else 1 end),
      max_single_distance_km = greatest(max_single_distance_km, new.distance_km),
      updated_at = now()
    where user_id = v_user_id;
    v_needs_max_refresh := new.distance_km < old.distance_km;
  end if;

  if v_needs_max_refresh then
    update public.user_activity_stats set max_single_distance_km = coalesce(
      (select max(distance_km) from public.activities where user_id = v_user_id), 0)
    where user_id = v_user_id;
  end if;
  return null;
end;
$$;

drop trigger if exists maintain_activity_stats on public.activities;
create trigger maintain_activity_stats after insert or update or delete on public.activities
for each row execute function public.maintain_activity_stats();

create or replace function public.award_badges(p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare stats public.user_activity_stats;
begin
  select * into stats from public.user_activity_stats where user_id = p_user_id;
  if not found then return; end if;
  insert into public.badges (user_id, code, name, description, icon)
  select p_user_id, d.code, d.name, d.description, d.icon
  from public.badge_definitions d
  where ((d.threshold_type = 'total_distance' and stats.total_distance_km >= d.threshold_value)
      or (d.threshold_type = 'activity_count' and stats.activity_count >= d.threshold_value)
      or (d.threshold_type = 'single_distance' and stats.max_single_distance_km >= d.threshold_value))
  on conflict (user_id, code) where code is not null do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Safe social APIs.  Views run with owner privileges by default, so remove the
-- unused public view instead of relying on RLS through it.
-- ---------------------------------------------------------------------------
drop view if exists public.leaderboard_totals;
drop function if exists public.get_leaderboard(integer);
create function public.get_leaderboard(p_limit integer default 50)
returns table (user_id uuid, display_name text, total_distance_km numeric, activity_count bigint, rank bigint, is_pro boolean)
language sql security definer set search_path = public as $$
  with visible as (
    select p.id, coalesce(p.display_name, 'Runner') as display_name,
           s.total_distance_km, s.activity_count,
           exists (select 1 from public.user_subscriptions us join public.subscription_plans sp on sp.id = us.plan_id
                   where us.user_id = p.id and us.status = 'active' and us.end_date > now()
                     and sp.duration_type in ('monthly', 'yearly')) as is_pro
    from public.profiles p join public.user_activity_stats s on s.user_id = p.id
    where p.leaderboard_visible and auth.uid() is not null
  )
  select id, display_name, total_distance_km, activity_count,
         rank() over (order by total_distance_km desc), is_pro
  from visible order by total_distance_km desc, id asc limit greatest(1, least(coalesce(p_limit, 50), 100));
$$;

create or replace function public.get_match_suggestions(p_limit integer default 20)
returns table (user_id uuid, display_name text, city text, bio text, preferred_pace_min_per_km numeric,
               avg_pace_min_per_km numeric, total_distance_km numeric, same_city boolean, pace_diff numeric)
language sql security definer set search_path = public as $$
  with me as (
    select p.id, p.city as my_city,
      coalesce(p.preferred_pace_min_per_km,
        case when s.total_distance_km > 0 then s.total_duration_min / s.total_distance_km end) as my_pace
    from public.profiles p left join public.user_activity_stats s on s.user_id = p.id
    where p.id = auth.uid()
  )
  select p.id, coalesce(p.display_name, 'Runner'), p.city, p.bio, p.preferred_pace_min_per_km,
    case when s.total_distance_km > 0 then s.total_duration_min / s.total_distance_km end,
    coalesce(s.total_distance_km, 0),
    (p.city is not null and p.city is not distinct from me.my_city),
    abs(coalesce(p.preferred_pace_min_per_km,
      case when s.total_distance_km > 0 then s.total_duration_min / s.total_distance_km end, me.my_pace) - me.my_pace)
  from public.profiles p cross join me left join public.user_activity_stats s on s.user_id = p.id
  where auth.uid() is not null and p.looking_for_partner and p.id <> auth.uid()
    and not exists (select 1 from public.run_matches m where (m.requester_id = auth.uid() and m.addressee_id = p.id)
      or (m.addressee_id = auth.uid() and m.requester_id = p.id))
  order by 8 desc, 9 asc nulls last, p.id asc
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$$;

drop policy if exists "Matches updatable by participants" on public.run_matches;
drop policy if exists "Matches deletable by participants" on public.run_matches;
create or replace function public.respond_to_match(p_match_id uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.run_matches set status = case when p_accept then 'accepted' else 'declined' end, updated_at = now()
  where id = p_match_id and addressee_id = auth.uid() and status = 'pending';
  if not found then raise exception 'match request is not pending for current user' using errcode = 'insufficient_privilege'; end if;
end;
$$;
create or replace function public.cancel_match(p_match_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.run_matches where id = p_match_id and requester_id = auth.uid() and status = 'pending';
  if not found then raise exception 'only the requester can cancel a pending match' using errcode = 'insufficient_privilege'; end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Atomic payment and common multi-row client operations.
-- ---------------------------------------------------------------------------
create sequence if not exists public.payment_order_code_seq start with 1000000000;
create or replace function public.create_payment_order(p_user_id uuid, p_plan_id uuid)
returns table(order_code bigint, amount integer, plan_id uuid)
language plpgsql security definer set search_path = public as $$
declare v_price numeric;
begin
  select price into v_price from public.subscription_plans where id = p_plan_id and is_active;
  if v_price is null or v_price <= 0 then raise exception 'invalid subscription plan' using errcode = 'check_violation'; end if;
  order_code := nextval('public.payment_order_code_seq'); amount := round(v_price)::integer; plan_id := p_plan_id;
  insert into public.payment_orders(order_code, user_id, plan_id, amount, status) values (order_code, p_user_id, plan_id, amount, 'pending');
  return next;
end;
$$;

create or replace function public.process_payos_payment(p_order_code bigint, p_amount integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o public.payment_orders; v_duration text; v_base timestamptz; v_end timestamptz;
begin
  select * into o from public.payment_orders where order_code = p_order_code for update;
  if not found then return jsonb_build_object('processed', false, 'reason', 'order_not_found'); end if;
  if o.status = 'paid' then return jsonb_build_object('processed', false, 'reason', 'already_paid'); end if;
  if o.amount <> p_amount then raise exception 'payment amount mismatch' using errcode = 'check_violation'; end if;
  select duration_type into v_duration from public.subscription_plans where id = o.plan_id;
  if v_duration is null then raise exception 'subscription plan not found' using errcode = 'foreign_key_violation'; end if;
  select greatest(now(), coalesce(max(end_date), now())) into v_base from public.user_subscriptions where user_id = o.user_id and status = 'active';
  v_end := v_base + case v_duration when 'weekly' then interval '7 days' when 'yearly' then interval '365 days' else interval '30 days' end;
  update public.user_subscriptions set status = 'cancelled' where user_id = o.user_id and status = 'active';
  insert into public.user_subscriptions(user_id, plan_id, status, start_date, end_date) values (o.user_id, o.plan_id, 'active', now(), v_end);
  update public.payment_orders set status = 'paid', paid_at = now() where order_code = p_order_code;
  return jsonb_build_object('processed', true, 'end_date', v_end);
end;
$$;

create or replace function public.log_weight_atomic(p_weight_kg numeric, p_logged_at timestamptz default now(), p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or p_weight_kg <= 0 then raise exception 'invalid weight log' using errcode = 'check_violation'; end if;
  insert into public.weight_logs(user_id, weight_kg, logged_at, note) values (auth.uid(), p_weight_kg, p_logged_at, p_note);
  update public.profiles set weight_kg = p_weight_kg, start_weight_kg = coalesce(start_weight_kg, p_weight_kg) where id = auth.uid();
end;
$$;

create or replace function public.complete_scheduled_workout(p_workout_id uuid, p_activity_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.scheduled_workouts set activity_id = p_activity_id, status = 'completed'
  where id = p_workout_id and user_id = auth.uid();
  if not found then raise exception 'workout not found' using errcode = 'insufficient_privilege'; end if;
end;
$$;

create or replace function public.get_activity_summary()
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'totalDistance', coalesce(s.total_distance_km, 0),
    'totalSessions', coalesce(s.activity_count, 0),
    'avgPace', case when coalesce(s.total_distance_km, 0) > 0 then s.total_duration_min / s.total_distance_km else 0 end,
    'avgHr', case when coalesce(s.hr_count, 0) > 0 then s.hr_sum / s.hr_count else 0 end
  ) from public.user_activity_stats s where s.user_id = auth.uid();
$$;

-- Indexes match RLS filters, ordering and foreign-key maintenance.
create index if not exists activities_user_started_at_idx on public.activities(user_id, started_at desc, id desc);
create index if not exists activities_shoe_id_idx on public.activities(shoe_id) where shoe_id is not null;
create index if not exists training_schedules_user_status_created_idx on public.training_schedules(user_id, status, created_at desc);
create index if not exists scheduled_workouts_user_schedule_date_idx on public.scheduled_workouts(user_id, schedule_id, date);
create index if not exists scheduled_workouts_activity_id_idx on public.scheduled_workouts(activity_id) where activity_id is not null;
create index if not exists ai_chat_history_user_created_idx on public.ai_chat_history(user_id, created_at desc, id desc);
create index if not exists ai_insights_user_created_idx on public.ai_insights(user_id, created_at desc);
create index if not exists shoes_user_active_name_idx on public.shoes(user_id, is_active, name);
create index if not exists run_matches_addressee_status_created_idx on public.run_matches(addressee_id, status, created_at desc);
create index if not exists run_matches_requester_status_idx on public.run_matches(requester_id, status);
create index if not exists profiles_match_visible_idx on public.profiles(city) where looking_for_partner;
create index if not exists user_subscriptions_active_end_idx on public.user_subscriptions(user_id, end_date desc) where status = 'active';

-- Security-definer functions are implementation details unless explicitly API-facing.
revoke execute on function public.award_badges(uuid) from public, anon, authenticated;
revoke execute on function public.maintain_activity_stats() from public, anon, authenticated;
revoke execute on function public.assert_related_row_owner() from public, anon, authenticated;
revoke execute on function public.create_payment_order(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.process_payos_payment(bigint, integer) from public, anon, authenticated;
grant execute on function public.create_payment_order(uuid, uuid) to service_role;
grant execute on function public.process_payos_payment(bigint, integer) to service_role;
revoke execute on function public.get_strava_connection(uuid), public.get_strava_connection_by_athlete(text),
  public.save_strava_connection(uuid, text, text, text, timestamptz), public.disconnect_strava_connection(uuid),
  public.create_oauth_state(uuid, text, text), public.consume_oauth_state(uuid, text, text) from public, anon, authenticated;
grant execute on function public.get_strava_connection(uuid), public.get_strava_connection_by_athlete(text),
  public.save_strava_connection(uuid, text, text, text, timestamptz), public.disconnect_strava_connection(uuid),
  public.create_oauth_state(uuid, text, text), public.consume_oauth_state(uuid, text, text) to service_role;
revoke execute on function public.get_leaderboard(integer) from public;
revoke execute on function public.get_match_suggestions(integer) from public;
revoke execute on function public.respond_to_match(uuid, boolean), public.cancel_match(uuid) from public;
revoke execute on function public.log_weight_atomic(numeric, timestamptz, text),
  public.complete_scheduled_workout(uuid, uuid) from public;
grant execute on function public.get_leaderboard(integer), public.get_match_suggestions(integer),
  public.respond_to_match(uuid, boolean), public.cancel_match(uuid),
  public.log_weight_atomic(numeric, timestamptz, text), public.complete_scheduled_workout(uuid, uuid) to authenticated;
revoke execute on function public.get_activity_summary() from public;
grant execute on function public.get_activity_summary() to authenticated;
