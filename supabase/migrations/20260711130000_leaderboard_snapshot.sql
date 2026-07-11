-- A personal, always-available leaderboard surface. Public ranking remains
-- strictly opt-in; Pro status is decorative and never changes the order.
create or replace function public.get_leaderboard_snapshot(p_limit integer default 50)
returns jsonb
language sql security definer set search_path = public as $$
  with ranked as (
    select p.id, coalesce(p.display_name, 'Runner') as display_name,
           s.total_distance_km, s.activity_count,
           rank() over (order by s.total_distance_km desc) as rank,
           exists (
             select 1 from public.user_subscriptions us
             join public.subscription_plans sp on sp.id = us.plan_id
             where us.user_id = p.id and us.status = 'active' and us.end_date > now()
               and sp.duration_type in ('monthly', 'yearly')
           ) as is_pro
    from public.profiles p
    join public.user_activity_stats s on s.user_id = p.id
    where p.leaderboard_visible and s.activity_count > 0
  ), me as (
    select p.leaderboard_visible, coalesce(s.total_distance_km, 0) as total_distance_km,
           coalesce(s.activity_count, 0) as activity_count,
           exists (
             select 1 from public.user_subscriptions us
             join public.subscription_plans sp on sp.id = us.plan_id
             where us.user_id = p.id and us.status = 'active' and us.end_date > now()
               and sp.duration_type in ('monthly', 'yearly')
           ) as is_pro
    from public.profiles p
    left join public.user_activity_stats s on s.user_id = p.id
    where p.id = auth.uid()
  )
  select jsonb_build_object(
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', id, 'display_name', display_name,
        'total_distance_km', total_distance_km, 'activity_count', activity_count,
        'rank', rank, 'is_pro', is_pro
      ) order by rank, id)
      from (select * from ranked order by rank, id limit greatest(1, least(coalesce(p_limit, 50), 100))) top_entries
    ), '[]'::jsonb),
    'visible_runner_count', (select count(*) from ranked),
    'personal', coalesce((
      select jsonb_build_object(
        'total_distance_km', me.total_distance_km, 'activity_count', me.activity_count,
        'is_visible', me.leaderboard_visible, 'is_pro', me.is_pro,
        'rank', (select rank from ranked where id = auth.uid())
      ) from me
    ), '{}'::jsonb)
  )
  where auth.uid() is not null;
$$;

revoke execute on function public.get_leaderboard_snapshot(integer) from public, anon;
grant execute on function public.get_leaderboard_snapshot(integer) to authenticated;
