-- Drop the existing get_leaderboard function because we are changing the return columns signature (adding is_pro)
drop function if exists public.get_leaderboard(integer);

-- Re-create get_leaderboard with the additional is_pro column
create or replace function public.get_leaderboard(p_limit integer default 50)
returns table (
  user_id uuid,
  display_name text,
  total_distance_km numeric,
  activity_count bigint,
  rank bigint,
  is_pro boolean
)
language sql
security definer
set search_path = public
as $$
  select
    p.id as user_id,
    coalesce(p.display_name, 'Runner') as display_name,
    coalesce(sum(a.distance_km), 0)::numeric as total_distance_km,
    coalesce(count(a.id), 0) as activity_count,
    rank() over (order by coalesce(sum(a.distance_km), 0) desc) as rank,
    exists (
      select 1 from public.user_subscriptions us
      join public.subscription_plans sp on us.plan_id = sp.id
      where us.user_id = p.id
        and us.status = 'active'
        and us.end_date > now()
        and sp.duration_type in ('monthly', 'yearly')
    ) as is_pro
  from public.profiles p
  left join public.activities a on a.user_id = p.id
  group by p.id, p.display_name
  order by total_distance_km desc, p.id asc
  limit p_limit;
$$;
