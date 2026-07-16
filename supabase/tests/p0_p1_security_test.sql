begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(25);

select is(
  (
    select coalesce(
      array_agg(column_name::text order by column_name),
      array[]::text[]
    )
    from information_schema.column_privileges
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'profiles'
      and privilege_type = 'UPDATE'
  ),
  array[
    'bio',
    'bmi',
    'city',
    'coach_name',
    'coach_persona',
    'display_name',
    'gender',
    'has_completed_onboarding',
    'height_cm',
    'leaderboard_visible',
    'looking_for_partner',
    'max_hr',
    'preferred_pace_min_per_km',
    'start_weight_kg',
    'target_weight_kg',
    'weight_kg'
  ]::text[],
  'profiles exposes exactly the intended client-update allowlist'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'trial_ends_at',
    'UPDATE'
  ),
  'authenticated cannot update trial_ends_at'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'canonical_email',
    'UPDATE'
  ),
  'authenticated cannot update canonical_email'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.user_activity_stats',
    'SELECT'
  ),
  'aggregate table is not directly readable'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.user_activity_stats',
    'UPDATE'
  ),
  'aggregate table is not directly writable'
);
select ok(
  not has_table_privilege('authenticated', 'public.badges', 'INSERT'),
  'clients cannot self-award badges'
);
select ok(
  not has_table_privilege('authenticated', 'public.run_matches', 'INSERT'),
  'clients cannot insert run matches directly'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.request_run_match(uuid)',
    'EXECUTE'
  ),
  'authenticated users use the consent-aware match RPC'
);
select ok(
  position(
    'FOREIGN KEY (activity_id, user_id) REFERENCES activities(id, user_id)'
    in (
      select pg_get_constraintdef(oid)
      from pg_constraint
      where conname = 'activity_recovery_feedback_activity_owner_fkey'
    )
  ) > 0,
  'recovery feedback has a composite activity-owner foreign key'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.check_ai_access(uuid,text,integer,integer,integer,integer)',
    'EXECUTE'
  ),
  'AI entitlement checks are service-only'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.check_ai_access(uuid,text,integer,integer,integer,integer)',
    'EXECUTE'
  ),
  'service role can execute AI entitlement checks'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.process_payos_payment(bigint,integer)',
    'EXECUTE'
  ),
  'payment settlement is service-only'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.enqueue_training_plan_job(uuid,text,date,date,text)',
    'EXECUTE'
  ),
  'durable plan enqueue is service-only'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'private.training_plan_jobs',
    'SELECT'
  ),
  'durable job rows are private'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.reschedule_scheduled_workout(uuid,date,time,boolean)',
    'EXECUTE'
  ),
  'rescheduling uses an authenticated transactional RPC'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.apply_training_plan_adjustments(jsonb)',
    'EXECUTE'
  ),
  'AI adjustment acceptance uses an authenticated transactional RPC'
);
select ok(
  to_regclass('private.training_plan_jobs') is not null,
  'durable training plan queue exists'
);
select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'private'
      and indexname = 'training_plan_jobs_one_open_per_user'
  ),
  'only one open training plan job is allowed per user'
);
select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'payment_orders_user_idempotency_unique'
  ),
  'payment idempotency key is unique per user'
);

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
  '10000000-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  'p0-p1-security@example.test',
  crypt('test-password', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

update public.profiles
set trial_ends_at = now() - interval '1 day'
where id = '10000000-0000-4000-8000-000000000001';

select is(
  (
    public.check_ai_access(
      '10000000-0000-4000-8000-000000000001',
      'plan',
      100,
      1000,
      100,
      1000
    ) ->> 'reason'
  ),
  'upgrade_required',
  'free users cannot access plan generation'
);
select is(
  (
    public.check_ai_access(
      '10000000-0000-4000-8000-000000000001',
      'vision',
      100,
      1000,
      100,
      1000
    ) ->> 'reason'
  ),
  'upgrade_required',
  'free users cannot access vision by changing payload shape'
);
select is(
  (
    public.check_ai_access(
      '10000000-0000-4000-8000-000000000001',
      'not-a-feature',
      100,
      1000,
      100,
      1000
    ) ->> 'reason'
  ),
  'invalid_feature',
  'unknown AI feature identifiers fail closed'
);
select ok(
  (
    public.check_ai_access(
      '10000000-0000-4000-8000-000000000001',
      'chat',
      100,
      1000,
      100,
      1000
    ) ->> 'allowed'
  )::boolean,
  'free users retain the explicitly allowed chat feature'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.badges'::regclass
      and conname = 'badges_code_fkey'
  ),
  'badge codes are constrained to server-defined badge catalog'
);
select ok(
  has_column_privilege(
    'authenticated',
    'public.profiles',
    'display_name',
    'UPDATE'
  ),
  'authenticated can update an allowlisted profile field'
);

select * from finish();
rollback;
