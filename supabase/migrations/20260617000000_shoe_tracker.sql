-- Create shoes table
create table if not exists public.shoes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  name text not null,
  brand text,
  model text,
  acquired_at date not null default current_date,
  distance_km numeric(7,2) not null default 0.0,
  is_active boolean not null default true
);

-- Add shoe_id to activities table
alter table public.activities add column if not exists shoe_id uuid references public.shoes(id) on delete set null;

-- Enable RLS for shoes
alter table public.shoes enable row level security;

-- Policies for shoes
create policy "Shoes are self-readable" on public.shoes
  for select using (auth.uid() = user_id);
create policy "Shoes are self-insertable" on public.shoes
  for insert with check (auth.uid() = user_id);
create policy "Shoes are self-updatable" on public.shoes
  for update using (auth.uid() = user_id);
create policy "Shoes are self-deletable" on public.shoes
  for delete using (auth.uid() = user_id);

-- Function to recalculate shoe distance on activity change
create or replace function public.recalculate_shoe_distance()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    if new.shoe_id is not null then
      update public.shoes
      set distance_km = distance_km + new.distance_km
      where id = new.shoe_id;
    end if;
  elsif tg_op = 'UPDATE' then
    if coalesce(old.shoe_id, '00000000-0000-0000-0000-000000000000'::uuid) <> coalesce(new.shoe_id, '00000000-0000-0000-0000-000000000000'::uuid) or old.distance_km <> new.distance_km then
      if old.shoe_id is not null then
        update public.shoes
        set distance_km = greatest(0.0, distance_km - old.distance_km)
        where id = old.shoe_id;
      end if;
      if new.shoe_id is not null then
        update public.shoes
        set distance_km = distance_km + new.distance_km
        where id = new.shoe_id;
      end if;
    end if;
  elsif tg_op = 'DELETE' then
    if old.shoe_id is not null then
      update public.shoes
      set distance_km = greatest(0.0, distance_km - old.distance_km)
      where id = old.shoe_id;
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- Trigger to execute the function
create or replace trigger on_activity_shoe_distance_change
after insert or update or delete on public.activities
for each row execute function public.recalculate_shoe_distance();
