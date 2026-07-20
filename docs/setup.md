# Setup Guide

This guide explains how to run Runny AI locally and how to deploy production changes through the Supabase Dashboard.

## 1) Prerequisites

- Flutter SDK (Dart `^3.12.0`)
- Git
- Supabase CLI + Docker (for local backend development)

## 2) Clone and install client dependencies

```bash
git clone https://github.com/k4spi4n/runny-ai.git
cd runny-ai/apps/runny_app
flutter pub get
```

## 3) Configure Flutter client env

Create `apps/runny_app/.env` from the template:

```bash
cp .env.example .env
```

Client `.env` should only contain:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- optional non-secret model hints

Never place provider API keys in client `.env` because web builds bundle this file.

## 4) Run Supabase locally (optional, recommended)

From repository root:

```bash
supabase start
supabase db reset
```

Create server secrets file:

```bash
cp supabase/functions/.env.example supabase/functions/.env
```

Then serve Edge Functions locally:

```bash
supabase functions serve --env-file supabase/functions/.env
```

Keep this process running while developing.

## 5) Required server-side secrets

Configure these in `supabase/functions/.env` for local development (or in Supabase Dashboard secrets for production):

- AI gateway: `GROQ_API_KEY`, `MODAL_ENDPOINT_URL`, `MODAL_PROXY_TOKEN_ID`, `MODAL_PROXY_TOKEN_SECRET`, `CEREBRAS_API_KEY`, `OPENROUTER_API_KEY`
- Weather fallback: `WAQI_API_KEY` (optional fallback/location naming) and/or `OPENWEATHER_API_KEY`
- Strava: `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `STRAVA_REDIRECT_URI`, `STRAVA_VERIFY_TOKEN`, `STRAVA_SUBSCRIPTION_ID`
- Food recognition mode: `FOOD_RECOGNITION_PROVIDER=ai` for production (mock only for local testing)

## 6) Run the Flutter app

From `apps/runny_app/`:

```bash
flutter run -d chrome
```

## 7) Common development commands

From `apps/runny_app/`:

```bash
flutter analyze
flutter test
flutter build web --release
```

From repository root (local backend):

```bash
supabase start
supabase db reset
supabase functions serve --env-file supabase/functions/.env
```

## 8) Production workflow (Supabase Dashboard)

For production, use Supabase Dashboard UI (not CLI):

1. Open **SQL Editor** and apply new migration files.
2. Open **Edge Functions → Secrets** and set server secrets.
3. Deploy/update functions from **Edge Functions** UI.
4. Verify auth settings per function (JWT on/off as required by each function).

Render production site: https://runny-ai.onrender.com/

## Troubleshooting

- `flutter` command not found: install Flutter SDK and add it to `PATH`.
- Edge Function auth errors: check `SUPABASE_URL`, anon key, and user session.
- Weather/AI errors: verify server secrets are present in Supabase.
