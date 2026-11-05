begin;

-- Preserve sub-second duration and GPS distance when reopening a recorded run.
alter table public.activities
  add column has_gps_route boolean not null default false,
  alter column distance_km type numeric,
  alter column duration_min type numeric;

create table public.activity_routes (
  activity_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  segments jsonb not null,
  foreign key (activity_id, user_id)
    references public.activities(id, user_id) on delete cascade,
  constraint activity_routes_size check (
    jsonb_typeof(segments) = 'array' and pg_column_size(segments) <= 8388608
  )
);
alter table public.activity_routes enable row level security;
revoke all on public.activity_routes from anon, authenticated;
grant select, insert on public.activity_routes to authenticated;
create policy "Route owners can read" on public.activity_routes
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "Route owners can insert" on public.activity_routes
  for insert to authenticated with check ((select auth.uid()) = user_id);

create function public.save_recorded_run(
  p_id uuid, p_started_at timestamptz, p_distance_m double precision,
  p_active_ms bigint, p_segments jsonb, p_name text
) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_activity public.activities;
  v_segment jsonb;
  v_point jsonb;
  v_count integer := 0;
  v_previous_time bigint;
  v_inserted uuid;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  -- Return the committed run on retries, including after a lost HTTP response.
  select a.* into v_activity from public.activities a
    join public.activity_routes r on r.activity_id = a.id and r.user_id = a.user_id
    where a.id = p_id and a.user_id = v_user;
  if found then return to_jsonb(v_activity); end if;

  if p_id is null or p_started_at is null or
      p_started_at > now() + interval '5 minutes' or
      p_distance_m is null or not (p_distance_m between 0 and 1000000) or
      p_active_ms is null or not (p_active_ms between 0 and 604800000) or
      p_name is null or char_length(p_name) > 160 or
      p_segments is null or jsonb_typeof(p_segments) <> 'array' or
      pg_column_size(p_segments) > 8388608 then
    raise exception 'Invalid recorded run' using errcode = '22023';
  end if;
  for v_segment in select value from jsonb_array_elements(p_segments) loop
    if jsonb_typeof(v_segment) <> 'array' then
      raise exception 'Invalid route segment' using errcode = '22023';
    end if;
    if jsonb_array_length(v_segment) = 0 then
      raise exception 'Empty route segment' using errcode = '22023';
    end if;
    for v_point in select value from jsonb_array_elements(v_segment) loop
      if jsonb_typeof(v_point) <> 'array' then
        raise exception 'Invalid GPS point' using errcode = '22023';
      end if;
      if jsonb_array_length(v_point) <> 3 or
          jsonb_typeof(v_point->0) <> 'number' or
          jsonb_typeof(v_point->1) <> 'number' or
          jsonb_typeof(v_point->2) <> 'number' then
        raise exception 'Invalid GPS point' using errcode = '22023';
      end if;
      if not ((v_point->>0)::numeric between -90 and 90) or
          not ((v_point->>1)::numeric between -180 and 180) or
          not ((v_point->>2)::numeric between
            extract(epoch from p_started_at) * 1000 - 10000 and
            extract(epoch from now() + interval '5 minutes') * 1000) or
          (v_previous_time is not null and (v_point->>2)::bigint <= v_previous_time) then
        raise exception 'Invalid GPS coordinates or timestamp' using errcode = '22023';
      end if;
      v_previous_time := (v_point->>2)::bigint;
      v_count := v_count + 1;
      if v_count > 100000 then
        raise exception 'Route too long' using errcode = '22023';
      end if;
    end loop;
  end loop;
  if v_count = 0 then
    raise exception 'Route required' using errcode = '22023';
  end if;

  insert into public.activities(id, user_id, started_at, distance_km, duration_min, name, has_gps_route)
    values (p_id, v_user, p_started_at, p_distance_m / 1000, p_active_ms / 60000.0, p_name, true)
    on conflict (id) do nothing returning id into v_inserted;
  if v_inserted is not null then
    insert into public.activity_routes(activity_id, user_id, segments)
      values (p_id, v_user, p_segments);
  end if;
  -- A concurrent retry waits on the activity PK, then sees the committed route.
  select a.* into v_activity from public.activities a
    join public.activity_routes r on r.activity_id = a.id and r.user_id = a.user_id
    where a.id = p_id and a.user_id = v_user;
  if not found then
    raise exception 'Run ID unavailable' using errcode = '23505';
  end if;
  return to_jsonb(v_activity);
end;
$$;
revoke all on function public.save_recorded_run(uuid, timestamptz, double precision, bigint, jsonb, text) from public, anon;
grant execute on function public.save_recorded_run(uuid, timestamptz, double precision, bigint, jsonb, text) to authenticated;

commit;
