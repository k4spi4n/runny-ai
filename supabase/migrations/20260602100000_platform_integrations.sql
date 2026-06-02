-- Migration to add integration fields and height to profiles
alter table public.profiles 
add column if not exists height_cm numeric(5,2),
add column if not exists strava_id text,
add column if not exists garmin_id text,
add column if not exists strava_access_token text,
add column if not exists strava_refresh_token text,
add column if not exists strava_expires_at timestamptz;
