-- Paywall + quota theo tier + đối soát thanh toán PayOS.
--
-- Mô hình entitlement 3 tier:
--   trial : trong 14 ngày kể từ profiles.trial_ends_at  -> full AI (cap rộng)
--   paid  : có user_subscriptions active & end_date còn hạn -> full AI (cap rộng)
--   free  : hết trial, chưa trả tiền -> chat AI quota nhỏ; KHÓA tạo kế hoạch & nhận diện món ăn
--
-- Gate thật nằm ở server: Edge Function gọi RPC check_ai_access (bên dưới) trước
-- khi gọi nhà cung cấp AI. Client chỉ gate ở mức UX.

-- =============================================================================
-- 1) Trial anchor trên profiles
-- =============================================================================
alter table public.profiles
  add column if not exists trial_ends_at timestamptz;

-- Backfill user cũ: mốc trial = ngày tạo hồ sơ + 14 ngày.
update public.profiles
  set trial_ends_at = created_at + interval '14 days'
  where trial_ends_at is null;

-- User mới: set trial_ends_at khi trigger tạo hồ sơ lúc đăng ký.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, trial_ends_at)
  values (new.id, split_part(new.email, '@', 1), now() + interval '14 days')
  on conflict (id) do nothing;
  return new;
end;
$$;

-- =============================================================================
-- 2) Cập nhật gói: chỉ còn Monthly 29K & Yearly 129K (VND). Ẩn gói cũ.
-- =============================================================================
-- Ẩn mọi gói cũ trước, rồi upsert 2 gói hiện hành theo duration_type.
update public.subscription_plans set is_active = false;

-- Monthly 29K
update public.subscription_plans
  set name = 'Gói Tháng',
      price = 29000,
      currency = 'VND',
      benefits = ARRAY[
        'Mở khóa toàn bộ trợ lý AI',
        'Tạo & điều chỉnh kế hoạch tập không giới hạn',
        'Nhận diện món ăn bằng ảnh',
        'Phân tích & gợi ý cá nhân hóa'
      ],
      is_active = true
  where duration_type = 'monthly';

-- Yearly 129K
update public.subscription_plans
  set name = 'Gói Năm',
      price = 129000,
      currency = 'VND',
      benefits = ARRAY[
        'Mọi quyền lợi của Gói Tháng',
        'Tiết kiệm ~63% so với trả theo tháng',
        'Ưu tiên hỗ trợ'
      ],
      is_active = true
  where duration_type = 'yearly';

-- Phòng trường hợp DB chưa có sẵn 2 gói này (môi trường mới): chèn nếu thiếu.
insert into public.subscription_plans (name, price, currency, duration_type, benefits, is_active)
select 'Gói Tháng', 29000, 'VND', 'monthly',
       ARRAY['Mở khóa toàn bộ trợ lý AI','Tạo & điều chỉnh kế hoạch tập không giới hạn','Nhận diện món ăn bằng ảnh','Phân tích & gợi ý cá nhân hóa'],
       true
where not exists (select 1 from public.subscription_plans where duration_type = 'monthly' and is_active);

insert into public.subscription_plans (name, price, currency, duration_type, benefits, is_active)
select 'Gói Năm', 129000, 'VND', 'yearly',
       ARRAY['Mọi quyền lợi của Gói Tháng','Tiết kiệm ~63% so với trả theo tháng','Ưu tiên hỗ trợ'],
       true
where not exists (select 1 from public.subscription_plans where duration_type = 'yearly' and is_active);

-- =============================================================================
-- 3) payment_orders: đối soát đơn thanh toán PayOS
-- =============================================================================
create table if not exists public.payment_orders (
  order_code  bigint primary key,            -- orderCode gửi sang PayOS
  user_id     uuid not null references auth.users(id) on delete cascade,
  plan_id     uuid not null references public.subscription_plans(id),
  amount      integer not null,
  status      text not null default 'pending' check (status in ('pending', 'paid', 'cancelled')),
  created_at  timestamptz not null default now(),
  paid_at     timestamptz
);

create index if not exists payment_orders_user_id_idx on public.payment_orders(user_id);

-- RLS: user chỉ đọc đơn của mình; chỉ service_role (Edge Function) được ghi.
alter table public.payment_orders enable row level security;
create policy "Payment orders are self-readable" on public.payment_orders
  for select using (auth.uid() = user_id);

-- =============================================================================
-- 4) RPC check_ai_access: xác định tier + áp quota theo tier (atomic, row-lock).
--    Kế thừa vai trò của check_ai_rate_limit, dùng chung bảng ai_rate_limit.
--    Trả JSON: { allowed, reason, tier, day_count }
--      reason ∈ 'minute' | 'day' | 'upgrade_required' | null
-- =============================================================================
create or replace function public.check_ai_access(
  p_user_id uuid,
  p_feature text,                 -- 'chat' | 'plan' | 'food'
  p_max_per_min integer,          -- cap/phút cho trial|paid
  p_max_per_day integer,          -- cap/ngày cho trial|paid
  p_free_max_per_min integer,     -- cap/phút cho free (chỉ feature 'chat')
  p_free_max_per_day integer      -- cap/ngày cho free (chỉ feature 'chat')
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rec public.ai_rate_limit;
  now_ts timestamptz := now();
  v_tier text;
  v_is_paid boolean;
  v_trial_ends timestamptz;
  v_max_min integer;
  v_max_day integer;
  v_allowed boolean := true;
  v_reason text := null;
  v_minute_start timestamptz;
  v_minute_count integer;
  v_day_start timestamptz;
  v_day_count integer;
begin
  if p_user_id is null then
    return jsonb_build_object('allowed', false, 'reason', 'no_user', 'tier', null);
  end if;

  -- Xác định tier.
  select exists (
    select 1 from public.user_subscriptions
    where user_id = p_user_id and status = 'active' and end_date > now_ts
  ) into v_is_paid;

  if v_is_paid then
    v_tier := 'paid';
  else
    select trial_ends_at into v_trial_ends from public.profiles where id = p_user_id;
    if v_trial_ends is not null and now_ts < v_trial_ends then
      v_tier := 'trial';
    else
      v_tier := 'free';
    end if;
  end if;

  -- Free tier: khóa các tính năng cao cấp (tạo kế hoạch, nhận diện món ăn).
  if v_tier = 'free' and p_feature in ('plan', 'food') then
    return jsonb_build_object('allowed', false, 'reason', 'upgrade_required', 'tier', v_tier);
  end if;

  -- Chọn cap theo tier.
  if v_tier = 'free' then
    v_max_min := p_free_max_per_min;
    v_max_day := p_free_max_per_day;
  else
    v_max_min := p_max_per_min;
    v_max_day := p_max_per_day;
  end if;

  -- Đếm cửa sổ phút/ngày (atomic, row-lock) — dùng chung bảng ai_rate_limit.
  select * into rec from public.ai_rate_limit where user_id = p_user_id for update;

  if not found then
    insert into public.ai_rate_limit(user_id, minute_start, minute_count, day_start, day_count, updated_at)
    values (p_user_id, now_ts, 1, now_ts, 1, now_ts);
    return jsonb_build_object('allowed', true, 'reason', null, 'tier', v_tier, 'day_count', 1);
  end if;

  v_minute_start := rec.minute_start;
  v_minute_count := rec.minute_count;
  v_day_start := rec.day_start;
  v_day_count := rec.day_count;

  if now_ts - v_minute_start >= interval '1 minute' then
    v_minute_start := now_ts;
    v_minute_count := 0;
  end if;
  if now_ts - v_day_start >= interval '1 day' then
    v_day_start := now_ts;
    v_day_count := 0;
  end if;

  if v_minute_count >= v_max_min then
    v_allowed := false;
    v_reason := 'minute';
  elsif v_day_count >= v_max_day then
    v_allowed := false;
    v_reason := 'day';
  end if;

  if v_allowed then
    v_minute_count := v_minute_count + 1;
    v_day_count := v_day_count + 1;
  end if;

  update public.ai_rate_limit
    set minute_start = v_minute_start,
        minute_count = v_minute_count,
        day_start = v_day_start,
        day_count = v_day_count,
        updated_at = now_ts
    where user_id = p_user_id;

  return jsonb_build_object(
    'allowed', v_allowed,
    'reason', v_reason,
    'tier', v_tier,
    'day_count', v_day_count
  );
end;
$$;

grant execute on function public.check_ai_access(uuid, text, integer, integer, integer, integer) to service_role;
