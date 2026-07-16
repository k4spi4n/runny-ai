\set ON_ERROR_STOP on

create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
set search_path = public, extensions;

begin;
delete from auth.users
where id = '20000000-0000-4000-8000-000000000001';

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '20000000-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  'payment-concurrency@example.test',
  crypt('test-password', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

insert into public.payment_orders (
  order_code,
  user_id,
  plan_id,
  amount,
  status,
  idempotency_key
)
select
  order_code,
  '20000000-0000-4000-8000-000000000001',
  p.id,
  round(p.price)::integer,
  'pending',
  idempotency_key
from (
  values
    (987654321001::bigint, 'concurrency-test-order-0001'::text),
    (987654321002::bigint, 'concurrency-test-order-0002'::text)
) v(order_code, idempotency_key)
cross join lateral (
  select id, price
  from public.subscription_plans
  where duration_type = 'monthly' and is_active
  order by created_at
  limit 1
) p;
commit;

select plan(4);

do $$
declare
  v_conn text := 'dbname=' || current_database();
begin
  perform dblink_connect('payos_one', v_conn);
  perform dblink_connect('payos_two', v_conn);
  perform dblink_send_query(
    'payos_one',
    'select public.process_payos_payment(987654321001, amount) from public.payment_orders where order_code = 987654321001'
  );
  perform dblink_send_query(
    'payos_two',
    'select public.process_payos_payment(987654321002, amount) from public.payment_orders where order_code = 987654321002'
  );
  perform *
  from dblink_get_result('payos_one') as result(payload jsonb);
  perform *
  from dblink_get_result('payos_two') as result(payload jsonb);
  perform dblink_disconnect('payos_one');
  perform dblink_disconnect('payos_two');
end;
$$;

select is(
  (
    select count(*)::integer
    from public.payment_orders
    where order_code in (987654321001, 987654321002)
      and status = 'paid'
  ),
  2,
  'both concurrent payment callbacks are processed'
);
select is(
  (
    select count(*)::integer
    from public.user_subscriptions
    where user_id = '20000000-0000-4000-8000-000000000001'
      and status = 'active'
  ),
  1,
  'concurrent callbacks leave exactly one active subscription'
);
select ok(
  (
    select end_date
    from public.user_subscriptions
    where user_id = '20000000-0000-4000-8000-000000000001'
      and status = 'active'
  ) >= now() + interval '59 days',
  'both monthly purchases extend the entitlement cumulatively'
);
select ok(
  not exists (
    select 1
    from public.payment_orders
    where order_code in (987654321001, 987654321002)
      and status <> 'paid'
  ),
  'no payment is lost during concurrent settlement'
);

select * from finish();

begin;
delete from auth.users
where id = '20000000-0000-4000-8000-000000000001';
commit;
