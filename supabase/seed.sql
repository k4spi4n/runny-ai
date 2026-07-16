insert into public.badges (user_id, code, name, description, icon)
select auth.uid(), d.code, d.name, d.description, d.icon
from public.badge_definitions d
where auth.uid() is not null and d.code = 'first_run'
on conflict (user_id, code) where code is not null do nothing;
