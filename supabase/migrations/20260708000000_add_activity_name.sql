-- Separate activity display name from free-form notes.
alter table public.activities
  add column if not exists name text;

-- Backfill previously imported activities where notes were used as the title.
update public.activities
set name = notes
where name is null
  and notes is not null
  and btrim(notes) <> '';
