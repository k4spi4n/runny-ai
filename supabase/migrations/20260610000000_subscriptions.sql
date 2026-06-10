
-- Create subscription_plans table
create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null,
  price numeric not null,
  currency text not null default 'VND',
  duration_type text not null check (duration_type in ('weekly', 'monthly', 'yearly')),
  benefits text[] default '{}',
  is_active boolean default true
);

-- Create user_subscriptions table
create table if not exists public.user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id),
  status text not null check (status in ('active', 'expired', 'cancelled')),
  start_date timestamptz not null default now(),
  end_date timestamptz not null,
  cancel_at_period_end boolean default false
);

-- RLS for subscription_plans
alter table public.subscription_plans enable row level security;
create policy "Subscription plans are readable by everyone" on public.subscription_plans
  for select using (true);

-- RLS for user_subscriptions
alter table public.user_subscriptions enable row level security;
create policy "User subscriptions are self-readable" on public.user_subscriptions
  for select using (auth.uid() = user_id);
create policy "User subscriptions are self-updatable" on public.user_subscriptions
  for update using (auth.uid() = user_id);
create policy "User subscriptions are self-insertable" on public.user_subscriptions
  for insert with check (auth.uid() = user_id);

-- Seed data
insert into public.subscription_plans (name, price, duration_type, benefits)
values 
  ('Weekly Plan', 99000, 'weekly', ARRAY['Full access to AI Coach', 'Unlimited training plans', 'Advanced analytics']),
  ('Monthly Plan', 199000, 'monthly', ARRAY['Full access to AI Coach', 'Unlimited training plans', 'Advanced analytics', 'Priority support']),
  ('Yearly Plan', 2000000, 'yearly', ARRAY['Full access to AI Coach', 'Unlimited training plans', 'Advanced analytics', 'Priority support', 'Personalized training roadmap']);
