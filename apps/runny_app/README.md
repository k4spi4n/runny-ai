# Runny AI — Flutter app

## Run in Android Studio

1. Open this folder (`apps/runny_app`), which contains `pubspec.yaml`.
2. Enable the Flutter and Dart plugins and select your installed Flutter SDK.
3. Copy `.env.example` to `.env` if needed, then set `SUPABASE_URL` and
   `SUPABASE_ANON_KEY` for your Supabase project. Never add provider API keys.
4. Run **Pub get** from `pubspec.yaml` after changing dependencies.
5. In **Device Manager**, start an Android virtual device, or connect an Android
   phone with USB debugging enabled. An Android 15 / API 35 virtual phone works
   for local testing; its system image must finish downloading first.
6. Select the **main.dart** run configuration and the **Android device** in the
   toolbar, then click the green **Run** button. This builds and installs a debug
   app using the debug signing key automatically.

Select Android rather than Windows or Chrome to test GPS recording. Recording
is mobile-only; the web app can display routes of previously saved runs.

Verified on 2026-11-05: the debug build installed and opened the Runny AI landing
page on the **Medium Phone / Android 15 (API 35)** emulator. Sign in to reach the
activity screen and recording flow.

## Build an APK

For a local debug APK, run from this folder:

```sh
flutter build apk --debug
```

The result is `build/app/outputs/flutter-apk/app-debug.apk`.

Android Studio's **Build → Flutter → Build APK** command requests a release
build. Release builds intentionally require `android/key.properties` and your
production keystore; see `android/key.properties.example`. Use **Run main.dart**
for development without a production signing key.

## GPS recording and backend setup

Sign in and finish onboarding, then tap the **red Record button in the center of
the bottom menu**. It returns to an existing run or draft when one is present.
The fixed menu contains Home, History, Record, Community, and More; Training,
AI Coach, Nutrition, and Profile are under More. Allow precise location access
and wait for GPS before starting.

For your real current location, run on a physical Android/iOS phone and enable
**Precise Location** for Runny AI. Android Studio's emulator reports simulated
coordinates; changing its city does not locate your computer or track you.
The map shows the device's estimated accuracy radius and hides expired fixes.

Saving GPS runs requires the new database migration. Apply it through
**Supabase Dashboard → SQL Editor**, following the
[outdoor recording guide](../../docs/outdoor-run-recording.md). The guide also
covers pause/resume, offline drafts, background recording, and device checks.
