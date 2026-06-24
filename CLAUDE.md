# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Runny AI is an AI-powered running coach and community platform. A **Flutter** client (`apps/runny_app`) talks to a **Supabase** backend (PostgreSQL + Auth + Deno Edge Functions). External AI/weather providers are never called directly from the client — they are proxied through Edge Functions so API keys stay server-side.

The product UI and most code comments are in **Vietnamese**; the app ships English + Vietnamese locales (default Vietnamese).

## Commands

All Flutter commands run from `apps/runny_app/`:

```bash
flutter pub get                 # install deps
flutter run -d chrome           # run app (web is the primary v0.1.0 target)
flutter analyze                 # lint/static analysis (flutter_lints)
flutter test                    # run all tests
flutter test test/activity_parser_test.dart   # run a single test file
flutter build web --release     # production web build
```

Supabase backend (from repo root, requires Docker + Supabase CLI):

```bash
supabase start                  # boot local stack (API on :34321, see supabase/config.toml)
supabase db reset               # apply all migrations + seed.sql
supabase functions serve --env-file supabase/functions/.env   # serve Edge Functions locally (keep open)
supabase functions deploy openrouter   # deploy a single function (also: strava_webhook, weather, food-recognition)
```

Deploy to Render (static web): `bash render-build.sh` (installs Flutter SDK, writes `.env` from env vars, builds web).

### Production & preferences
- Production web is deployed on **Render** at https://runny-ai.onrender.com/ (env vars set in the Render dashboard), backed by **Supabase Cloud**.
- The maintainer manages the cloud backend through the **Supabase Dashboard UI**, not the CLI. For production tasks (running migrations/SQL, setting secrets, deploying Edge Functions, managing auth/storage), give **dashboard (UI) instructions**; treat the `supabase` CLI as local-development-only. The CLI commands above still apply to the local stack.

## Configuration

- **Client** `.env` (in `apps/runny_app/`, gitignored; template `.env.example`): only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and non-secret model hints (`OPENROUTER_MODEL`, `OPENROUTER_MODELS`). **Never put provider API keys here** — the web build bundles `.env` into the client.
- **Server** secrets: set via `supabase secrets set ...` for cloud, or `supabase/functions/.env` (gitignored) for local. Keys: `GROQ_API_KEY`, `OPENROUTER_API_KEY`, `WAQI_API_KEY`, `OPENWEATHER_API_KEY`, plus Strava vars.

## Architecture

### Client (`apps/runny_app/lib`)
- `main.dart` loads `.env`, initializes Supabase, and wires top-level `provider` `ChangeNotifier`s (`ThemeProvider`, `LanguageProvider`, `NutritionService`). State management is **Provider**.
- `app.dart` → `AuthGate`: a `StreamBuilder` on `auth.onAuthStateChange` routes between `LandingPage` (logged out), `OnboardingPage` (profile missing or `has_completed_onboarding == false`), and `DashboardPage`.
- `services/` — one class per domain (chat, training, nutrition, social, weight, weather, subscription, integration, food recognition, gemini, speech). Services hold `Supabase.instance.client` and contain all data access / RPC / Edge Function calls. **Put backend logic here, not in pages.**
  - `speech_service*.dart` uses conditional imports (`_stub` / `_web`) for platform-specific implementations.
- `pages/` — full screens; `widgets/` — reusable UI; `models/` — plain Dart data classes (these are what the unit tests cover).
- `theme/` — `AppTheme.light()/dark()` + `ThemeProvider`.

### AI proxy (key design point)
The client's `GeminiService` does **not** call any LLM directly — it invokes the Supabase `openrouter` Edge Function (`supabase/functions/openrouter/index.ts`). Despite the name, that function is a multi-provider proxy: **Groq is primary** (fast LPU), **OpenRouter is the fallback** when Groq is missing/rate-limited/erroring. Both are OpenAI-compatible so request/response bodies pass through unchanged.

The Edge Function enforces server-side **guardrails** in order: (1) require an authenticated user (JWT `role == authenticated`), (2) validate payload size/length, (3) per-user rate limiting via the `check_ai_rate_limit` Postgres RPC (fail-open), (4) inject a running-only topic system prompt for free-form chat (skipped when `response_format` is set, e.g. internal JSON requests like plan generation). Provider used is reported back in the `X-AI-Provider` response header. When adding AI features, send model hints via `model` or `models` and let the function handle fallback.

### Backend (`supabase/`)
- `migrations/` — timestamped SQL, applied in order. New tables follow a consistent pattern: `user_id uuid references auth.users(id) on delete cascade` + Row Level Security policies scoping rows to the owner. Add a new migration file rather than editing existing ones.
- `functions/` — Deno/TypeScript Edge Functions: `openrouter` (AI proxy), `weather` (OpenWeather/WAQI proxy), `strava_webhook` (Strava OAuth/webhook ingest), `food-recognition` (currently a mock provider).

### Localization
Custom JSON-based l10n (not ARB/gen_l10n). Strings live in `lib/l10n/locales/{en,vi}.json`; access via `context.translate('key')` (extension in `lib/l10n/app_localizations.dart`), with `%s` positional args. Add new user-facing strings to **both** locale files.

## Docs
Deeper docs (Vietnamese) live in `docs/`: `architecture.md`, `api.md`, `setup.md`, `tech-stack.md`, `product-vision.md`.
