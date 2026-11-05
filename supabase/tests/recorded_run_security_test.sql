-- Local stack: supabase test db supabase/tests/recorded_run_security_test.sql
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

insert into auth.users(instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid, id::uuid,
  'authenticated', 'authenticated', email, crypt('run-test-password', gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
from (values
  ('61103000-0000-4000-8000-000000000001', 'gps-runner-a@example.test'),
  ('61103000-0000-4000-8000-000000000002', 'gps-runner-b@example.test')
) as users(id, email);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"61103000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($test$
  select public.save_recorded_run(
    '61103000-0000-4000-8000-000000000010', now() - interval '60 seconds',
    120.123456, 30500,
    jsonb_build_array(
      jsonb_build_array(jsonb_build_array(10, 106, floor(extract(epoch from now() - interval '60 seconds') * 1000))),
      jsonb_build_array(jsonb_build_array(10.001, 106, floor(extract(epoch from now() - interval '10 seconds') * 1000)))
    ), 'Outdoor run')
$test$, 'owner saves activity and separate route segments atomically');
select is((select count(*)::int from public.activity_routes), 1, 'owner reads own GPS route');
select is((select jsonb_array_length(segments) from public.activity_routes), 2, 'route segments survive storage');
select is((select round(duration_min * 60000)::bigint from public.activities
  where id = '61103000-0000-4000-8000-000000000010'), 30500::bigint, 'active duration keeps milliseconds');
select lives_ok($test$
  -- A retry returns the first committed values, even if the caller sends new values.
  select public.save_recorded_run('61103000-0000-4000-8000-000000000010', now(),
    0, 0, '[]', 'Retry')
$test$, 'save retry returns committed run');
select is((select count(*)::int from public.activities
  where id = '61103000-0000-4000-8000-000000000010'), 1, 'retry cannot duplicate activity');
select is((select name from public.activities
  where id = '61103000-0000-4000-8000-000000000010'), 'Outdoor run', 'retry cannot overwrite original stats or route');

select set_config('request.jwt.claims', '{"sub":"61103000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from public.activity_routes), 0, 'second account cannot read GPS');
select is((select count(*)::int from public.activities
  where id = '61103000-0000-4000-8000-000000000010'), 0, 'second account cannot read run');
select throws_ok($test$
  insert into public.activity_routes(activity_id, user_id, segments)
  values ('61103000-0000-4000-8000-000000000010', '61103000-0000-4000-8000-000000000001', '[]')
$test$, '42501', 'new row violates row-level security policy for table "activity_routes"', 'second account cannot write owner route');
select ok(not has_table_privilege('authenticated', 'public.activity_routes', 'UPDATE'),
  'client cannot change route ownership or overwrite route');

reset role;
select * from finish();
rollback;
