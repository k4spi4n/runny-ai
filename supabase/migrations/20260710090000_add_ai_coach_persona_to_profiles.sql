alter table public.profiles
  add column if not exists coach_name text not null default 'Runny',
  add column if not exists coach_persona text not null default 'calm';

alter table public.profiles
  add constraint profiles_coach_persona_check
  check (coach_persona in ('calm', 'disciplined', 'energetic', 'scientific', 'concise'))
  not valid;

alter table public.profiles
  validate constraint profiles_coach_persona_check;
