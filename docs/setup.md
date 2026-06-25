# Setup Guide

This guide will help you get the Runny AI project up and running on your local machine.

## Prerequisites

- **Flutter SDK**: `^3.12.0`
- **Dart SDK**: `^3.0.0`
- **Supabase CLI**: For local backend development (optional but recommended)
- **Git**

## Installation

### 1. Clone the repository
```bash
git clone https://github.com/your-repo/runny-ai.git
cd runny-ai
```

### 2. Frontend Setup (Flutter)
```bash
cd apps/runny_app
flutter pub get
```

### 3. Backend Setup (Supabase)
1. Create a new project on [Supabase](https://supabase.com/).
2. Run the SQL migrations from `supabase/migrations/` in order on your Supabase SQL Editor.
3. Deploy Edge Functions (if using Supabase CLI):
```bash
supabase functions deploy openrouter
supabase functions deploy strava_webhook
supabase functions deploy weather
```

### 4. Environment Variables
Copy the `.env.example` to `.env` in the `apps/runny_app` directory:
```bash
cp .env.example .env
```
Fill in the required keys:
- `SUPABASE_URL` & `SUPABASE_ANON_KEY`: From your Supabase Project Settings.
- `OPENROUTER_API_KEY`: From [OpenRouter](https://openrouter.ai/).
- `GEMINI_API_KEY`: From [Google AI Studio](https://aistudio.google.com/).
- `STRAVA_CLIENT_ID` & `STRAVA_CLIENT_SECRET`: From [Strava API Settings](https://www.strava.com/settings/api).

## Running the App

To run the Flutter app on your connected device or emulator:
```bash
flutter run
```

## Troubleshooting
- **Missing Dependencies**: Ensure `flutter pub get` is run in `apps/runny_app`.
- **API Errors**: Check your `.env` file for correct keys and ensure Supabase Edge Functions are correctly deployed and accessible.

