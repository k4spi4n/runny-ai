-- Persist interactive AI coach cards and their confirmation state.
alter table public.ai_chat_history
  add column if not exists metadata jsonb not null default '{}'::jsonb;

drop policy if exists "Chat history is self-updatable" on public.ai_chat_history;
create policy "Chat history is self-updatable" on public.ai_chat_history
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
