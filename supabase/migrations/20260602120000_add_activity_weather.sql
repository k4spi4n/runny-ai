alter table public.activities
add column if not exists start_lat numeric(9,6),
add column if not exists start_lon numeric(9,6),
add column if not exists weather_summary text,
add column if not exists temperature_c numeric(5,2),
add column if not exists aqi integer,
add column if not exists weather_fetched_at timestamptz,
add column if not exists weather_json jsonb;
