-- Security hardening (2026-07-02) — dong cac lo hong paywall/entitlement truoc
-- giai doan 0–10K user. An toan cho auto-deploy (GitHub -> Supabase): idempotent,
-- khong di chuyen du lieu.
--
--   1) user_subscriptions: user KHONG duoc tu ghi -> chan tu cap "paid" mien phi.
--   2) RPC entitlement chi service_role goi -> chan griefing quota nguoi khac.
--   3) recalculate_shoe_distance: pin search_path (definer an toan).

set client_min_messages = warning;

-- =============================================================================
-- 1) user_subscriptions: chi PayOS webhook (service_role) duoc INSERT/UPDATE.
--    Xoa 2 policy tu-ghi (self-insert/self-update) — day la lo hong cho phep bat
--    ky user nao chay 1 cau INSERT de tu cap tier "paid" (check_ai_access doc
--    truc tiep bang nay). Giu lai policy self-SELECT de user van xem duoc goi.
-- =============================================================================
drop policy if exists "User subscriptions are self-updatable" on public.user_subscriptions;
drop policy if exists "User subscriptions are self-insertable" on public.user_subscriptions;

-- Huy-cuoi-ky di qua RPC SECURITY DEFINER (khong mo UPDATE thang vao bang, tranh
-- user sua status/end_date). Chi tac dong len subscription active CUA CHINH MINH.
create or replace function public.request_subscription_cancellation()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.user_subscriptions
    set cancel_at_period_end = true
    where user_id = auth.uid() and status = 'active';
end;
$$;

revoke execute on function public.request_subscription_cancellation() from public;
grant execute on function public.request_subscription_cancellation() to authenticated;

-- Hot-path index: check_ai_access loc user_subscriptions(user_id, status) moi lan
-- goi AI. Re va co ich khi bang lon dan.
create index if not exists user_subscriptions_user_status_idx
  on public.user_subscriptions(user_id, status);

-- =============================================================================
-- 2) RPC entitlement/rate-limit: chi service_role (Edge Function) duoc goi.
--    Postgres mac dinh cap EXECUTE cho PUBLIC -> thu hoi de user khong tu goi
--    voi p_user_id cua nguoi khac (dot quota nan nhan). Edge Function goi bang
--    service key nen khong bi anh huong.
-- =============================================================================
revoke execute on function
  public.check_ai_access(uuid, text, integer, integer, integer, integer)
  from public, authenticated;
revoke execute on function
  public.check_ai_rate_limit(uuid, integer, integer)
  from public, authenticated;

-- =============================================================================
-- 3) recalculate_shoe_distance: pin search_path = public (moi definer function
--    khac trong repo deu da pin; day la ngoai le duy nhat).
-- =============================================================================
create or replace function public.recalculate_shoe_distance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.shoe_id is not null then
      update public.shoes
      set distance_km = distance_km + new.distance_km
      where id = new.shoe_id;
    end if;
  elsif tg_op = 'UPDATE' then
    if coalesce(old.shoe_id, '00000000-0000-0000-0000-000000000000'::uuid) <> coalesce(new.shoe_id, '00000000-0000-0000-0000-000000000000'::uuid) or old.distance_km <> new.distance_km then
      if old.shoe_id is not null then
        update public.shoes
        set distance_km = greatest(0.0, distance_km - old.distance_km)
        where id = old.shoe_id;
      end if;
      if new.shoe_id is not null then
        update public.shoes
        set distance_km = distance_km + new.distance_km
        where id = new.shoe_id;
      end if;
    end if;
  elsif tg_op = 'DELETE' then
    if old.shoe_id is not null then
      update public.shoes
      set distance_km = greatest(0.0, distance_km - old.distance_km)
      where id = old.shoe_id;
    end if;
  end if;
  return null;
end;
$$;
