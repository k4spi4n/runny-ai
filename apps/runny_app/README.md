# Runny App (Flutter Client)

Flutter client for Runny AI.

## Main commands

From this directory (`apps/runny_app/`):

```bash
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
flutter build web --release
```

## Environment

Create `.env` from `.env.example`:

```bash
cp .env.example .env
```

Client `.env` must only include non-secret values like `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
All AI/weather/Strava provider keys belong to Supabase Edge Function secrets.
