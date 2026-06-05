create table if not exists public.ai_chat_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  role text not null check (role in ('user', 'assistant')),
  content text not null
);

alter table public.ai_chat_history enable row level security;

create policy "Chat history is self-readable" on public.ai_chat_history
  for select using (auth.uid() = user_id);

create policy "Chat history is self-insertable" on public.ai_chat_history
  for insert with check (auth.uid() = user_id);

create policy "Chat history is self-deletable" on public.ai_chat_history
  for delete using (auth.uid() = user_id);
