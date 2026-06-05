insert into public.badges (user_id, name, description)
select auth.uid(), 'First Run', 'Complete your first activity'
where auth.uid() is not null;
