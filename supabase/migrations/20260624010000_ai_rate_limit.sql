-- Rate limiting cho cổng AI proxy: chống spam/lạm dụng API theo từng người dùng.
-- Bảng giữ bộ đếm theo cửa sổ phút và ngày; RPC tăng đếm + kiểm tra hạn mức một
-- cách atomic (row lock) rồi trả về kết quả cho Edge Function.

create table if not exists public.ai_rate_limit (
  user_id uuid primary key references auth.users(id) on delete cascade,
  minute_start timestamptz not null default now(),
  minute_count integer not null default 0,
  day_start timestamptz not null default now(),
  day_count integer not null default 0,
  updated_at timestamptz not null default now()
);

-- Bật RLS và KHÔNG tạo policy: chỉ service_role (Edge Function) và hàm
-- SECURITY DEFINER bên dưới mới được đụng tới bảng này. Client không truy cập trực tiếp.
alter table public.ai_rate_limit enable row level security;

-- Kiểm tra & ghi nhận một lượt gọi AI. Trả về JSON:
--   { allowed: bool, reason: 'minute'|'day'|null, minute_count, day_count }
create or replace function public.check_ai_rate_limit(
  p_user_id uuid,
  p_max_per_min integer,
  p_max_per_day integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  rec public.ai_rate_limit;
  now_ts timestamptz := now();
  v_allowed boolean := true;
  v_reason text := null;
  v_minute_start timestamptz;
  v_minute_count integer;
  v_day_start timestamptz;
  v_day_count integer;
begin
  if p_user_id is null then
    return jsonb_build_object('allowed', false, 'reason', 'no_user');
  end if;

  select * into rec from public.ai_rate_limit where user_id = p_user_id for update;

  if not found then
    insert into public.ai_rate_limit(user_id, minute_start, minute_count, day_start, day_count, updated_at)
    values (p_user_id, now_ts, 1, now_ts, 1, now_ts);
    return jsonb_build_object('allowed', true, 'reason', null, 'minute_count', 1, 'day_count', 1);
  end if;

  v_minute_start := rec.minute_start;
  v_minute_count := rec.minute_count;
  v_day_start := rec.day_start;
  v_day_count := rec.day_count;

  -- Reset cửa sổ nếu đã hết hạn.
  if now_ts - v_minute_start >= interval '1 minute' then
    v_minute_start := now_ts;
    v_minute_count := 0;
  end if;
  if now_ts - v_day_start >= interval '1 day' then
    v_day_start := now_ts;
    v_day_count := 0;
  end if;

  if v_minute_count >= p_max_per_min then
    v_allowed := false;
    v_reason := 'minute';
  elsif v_day_count >= p_max_per_day then
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
    'minute_count', v_minute_count,
    'day_count', v_day_count
  );
end;
$$;

grant execute on function public.check_ai_rate_limit(uuid, integer, integer) to service_role;
