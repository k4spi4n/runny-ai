# P0/P1 production rollout

This checklist applies the security and reliability work introduced by:

- `supabase/migrations/20260716000000_p0_security_hotfix.sql`
- `supabase/migrations/20260716010000_p1_training_jobs_and_transactions.sql`

Use the Supabase Dashboard for production. Keep a database backup and a copy of
the currently deployed Edge Function ZIPs before starting.

## 1. Prepare Dashboard upload bundles

From the repository root:

```powershell
pwsh -File scripts/package-supabase-dashboard-functions.ps1
```

The command writes standalone ZIPs and SHA-256 hashes to
`artifacts/supabase-dashboard-functions/`. Each ZIP contains `index.ts`, its
local files, and the `_shared` dependency tree expected by the function.

Supabase's Dashboard editor has no deployment version history or rollback.
Retain these ZIPs and the previous production downloads as release artifacts.

## 2. Apply database migrations

In Supabase Dashboard > SQL Editor:

1. Run `20260716000000_p0_security_hotfix.sql`.
2. Run `20260716010000_p1_training_jobs_and_transactions.sql`.
3. Confirm both scripts finish without errors.

Running migration files through SQL Editor does not update the CLI migration
ledger. Record both filenames in the production change log and reconcile the
ledger before a future `db push`.

Run `supabase/tests/p0_p1_security_test.sql` in a non-production clone or the
local stack. Run `supabase/tests/payment_concurrency_test.sql` only where
`dblink` is available; it opens two database sessions to verify that concurrent
payments preserve all purchased time.

## 3. Configure Edge Function secrets

In Dashboard > Edge Functions > Secrets, set the production values represented
in `supabase/functions/.env.example`.

Required for this rollout:

- `APP_ALLOWED_ORIGINS=https://runny-ai.onrender.com`
- At least one text AI provider key: `GROQ_API_KEY`,
  `CEREBRAS_API_KEY`, or `OPENROUTER_API_KEY`
- `TRAINING_PLAN_WORKER_TOKEN` with at least 32 random characters
- `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, and `PAYOS_CHECKSUM_KEY`
- `APP_BASE_URL=https://runny-ai.onrender.com`
- `WAQI_API_KEY` and/or `OPENWEATHER_API_KEY`
- `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`,
  `STRAVA_REDIRECT_URI=https://runny-ai.onrender.com/`,
  `STRAVA_VERIFY_TOKEN`, and `STRAVA_SUBSCRIPTION_ID`
- `STRAVA_WEBHOOK_WORKER_TOKEN` with at least 32 random characters
- `FOOD_RECOGNITION_PROVIDER=groq` for production

Do not enable `FOOD_RECOGNITION_ALLOW_MOCK` in production. Supabase injects
`SUPABASE_URL` and the service-role key; do not copy either into the Flutter
client or Render environment.

## 4. Deploy Edge Functions

In Dashboard > Edge Functions > Deploy a new function > Via Editor, drag and
drop the matching ZIP and enter the exact function name. For an existing
function, retain the current download first, then deploy the ZIP as its update.

Deploy:

1. `openrouter`
2. `training-plan`
3. `training-plan-worker`
4. `weather`
5. `food-recognition`
6. `strava_oauth`
7. `strava_webhook`
8. `strava-webhook-worker`
9. `payos-create-payment`
10. `payos-webhook`

Verify the platform JWT setting after every deployment:

| Function | Verify JWT |
| --- | --- |
| `openrouter` | On |
| `training-plan` | On |
| `weather` | On |
| `food-recognition` | On |
| `strava_oauth` | On |
| `payos-create-payment` | On |
| `strava_webhook` | Off |
| `strava-webhook-worker` | Off |
| `training-plan-worker` | Off |
| `payos-webhook` | Off |

The functions with JWT disabled authenticate using provider signatures,
subscription identity, or a dedicated worker token in their own handler.

## 5. Schedule durable workers

Enable the Cron and `pg_net` integrations. Store these values in Supabase Vault:

- `runny_project_url`: `https://PROJECT_REF.supabase.co`
- `runny_training_plan_worker_token`: the same value as
  `TRAINING_PLAN_WORKER_TOKEN`
- `runny_strava_worker_token`: the same value as
  `STRAVA_WEBHOOK_WORKER_TOKEN`

Then run this in Dashboard > SQL Editor:

```sql
select cron.unschedule(jobid)
from cron.job
where jobname in (
  'runny-training-plan-worker',
  'runny-strava-webhook-worker'
);

select cron.schedule(
  'runny-training-plan-worker',
  '* * * * *',
  $$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'runny_project_url'
    ) || '/functions/v1/training-plan-worker',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-worker-token', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'runny_training_plan_worker_token'
      )
    ),
    body := '{"limit":2}'::jsonb
  );
  $$
);

select cron.schedule(
  'runny-strava-webhook-worker',
  '* * * * *',
  $$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'runny_project_url'
    ) || '/functions/v1/strava-webhook-worker',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-worker-token', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'runny_strava_worker_token'
      )
    ),
    body := '{"limit":10}'::jsonb
  );
  $$
);
```

Use Dashboard > Integrations > Cron to confirm both jobs execute every minute
and return successful HTTP requests.

## 6. Deploy the Render web app

Deploy the repository revision containing `render.yaml` and
`render-build.sh`. The Render service must use:

- Build command: `bash render-build.sh`
- Publish directory: `apps/runny_app/build/web`
- Environment: only `SUPABASE_URL` and `SUPABASE_ANON_KEY`

If the existing service is not managed by a Render Blueprint, copy the routes
and headers from `render.yaml` into its Dashboard settings. Confirm the deployed
response includes CSP, HSTS, `nosniff`, Referrer Policy, Permissions Policy, and
Cross-Origin-Opener-Policy.

## 7. Native release signing

Android:

1. Create the production upload keystore outside source control.
2. Copy `apps/runny_app/android/key.properties.example` to
   `apps/runny_app/android/key.properties` and enter the real values.
3. Build the signed bundle with `flutter build appbundle --release`.

iOS and macOS:

1. Open the respective Runner project in Xcode.
2. Select the production Apple Developer Team for the Runner target.
3. Keep automatic signing enabled and register `com.runnyai.app`.
4. Archive and validate before distribution.

The repository now provides the production bundle identity, usage
descriptions, Android network permission, and macOS network-client entitlement.
Signing credentials remain operator-owned and must never be committed.

## 8. Production smoke checks

Before reopening traffic:

1. As an authenticated user, a direct profile update containing
   `trial_ends_at`, `canonical_email`, `strava_id`, or `garmin_id` fails.
2. Authenticated and anonymous Data API requests cannot read or write
   `user_activity_stats`.
3. A free account receives an upgrade response for `training-plan`, vision, and
   food inference; chat remains subject to the free quota.
4. An invalid Strava subscription ID receives `403` and creates no queue row.
5. Duplicate valid Strava events do not create duplicate jobs.
6. A PayOS webhook with a changed outer or signed amount fails; a valid signed
   payment extends the current entitlement exactly once.
7. Creating a plan returns a generating schedule quickly, and the worker later
   fills it atomically.
8. Rescheduling and accepting AI adjustments update all affected workouts in
   one RPC transaction.
9. Import a sparse TCX/FIT and a multi-segment GPX; charts remain aligned and
   preserve peaks.
10. Review Edge Function and Cron logs for rejected auth, retries, and timeout
    spikes for at least one full worker interval.

If a function smoke check fails, redeploy its previously downloaded ZIP. Do not
reverse the security migrations destructively; fix forward with a new migration.

## Coverage status

The P0/P1 risk-bearing coverage gate is implemented in
`apps/runny_app/tool/check_coverage.dart` and runs in CI after
`flutter test --coverage`.

Verified on this rollout:

- Activity parser: 86.9%
- Entitlement provider: 83.0%
- Subscription service: 49.1%
- AI insight service: 85.1%
- Screenshot import service: 39.1%
- Training service as a whole: 6.9%; the durable enqueue/paywall contract has
  explicit tests, while unrelated legacy service operations remain uncovered

The broad instrumented-service aggregate is 11.3%, below the report's 50%
long-term target. The gate prevents regression in the P0/P1 slices without
misrepresenting that broader target as complete. Reaching 50% requires further
dependency injection and service decomposition beyond this hotfix rollout.
