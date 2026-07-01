-- Chống lạm dụng đăng ký để "farm" lại trial 14 ngày (bảo vệ mô hình freemium).
--
-- Hai lớp phòng vệ, đều enforce phía server:
--   1) Chặn email dùng-một-lần / tạm thời (mailinator, 10minutemail, ...).
--   2) Chặn "salting" email: cùng một hòm thư thật nhưng biến tấu bằng dấu chấm,
--      thẻ +tag, hay alias (Gmail dot/plus trick, googlemail.com) để né giới hạn
--      1 trial / người.
--
-- Điểm chốt chặn thật là trigger BEFORE INSERT trên auth.users (bên dưới); client
-- chỉ pre-check để báo lỗi thân thiện. Password đã được GoTrue băm + salt sẵn
-- (bcrypt) nên không xử lý ở đây.

set client_min_messages = warning;

-- =============================================================================
-- 1) Chuẩn hóa (canonicalize) email để gom mọi biến tấu về một dạng duy nhất.
-- =============================================================================
create or replace function public.canonicalize_email(p_email text)
returns text
language plpgsql
immutable
as $$
declare
  v_email text := lower(trim(p_email));
  v_local text;
  v_domain text;
begin
  if v_email is null or position('@' in v_email) = 0 then
    return v_email;
  end if;

  v_local  := split_part(v_email, '@', 1);
  v_domain := split_part(v_email, '@', 2);

  -- Bỏ phần plus-addressing: "user+bất_kỳ@..." -> "user@..."
  v_local := split_part(v_local, '+', 1);

  -- Gmail bỏ qua dấu chấm trong local-part và coi googlemail.com == gmail.com.
  if v_domain in ('gmail.com', 'googlemail.com') then
    v_domain := 'gmail.com';
    v_local  := replace(v_local, '.', '');
  end if;

  return v_local || '@' || v_domain;
end;
$$;

-- =============================================================================
-- 2) Blocklist domain email dùng-một-lần. Bảo trì thêm qua Dashboard (bảng này).
-- =============================================================================
create table if not exists public.disposable_email_domains (
  domain text primary key
);

-- Bật RLS mà KHÔNG tạo policy: chỉ hàm security-definer / service_role đọc được,
-- anon/authenticated không select thẳng vào blocklist.
alter table public.disposable_email_domains enable row level security;

insert into public.disposable_email_domains(domain) values
  ('mailinator.com'), ('10minutemail.com'), ('guerrillamail.com'),
  ('guerrillamail.info'), ('grr.la'), ('sharklasers.com'),
  ('temp-mail.org'), ('tempmail.com'), ('tempmailo.com'), ('tempr.email'),
  ('throwawaymail.com'), ('yopmail.com'), ('yopmail.fr'), ('getnada.com'),
  ('nada.email'), ('dispostable.com'), ('trashmail.com'), ('mailnesia.com'),
  ('maildrop.cc'), ('mohmal.com'), ('fakeinbox.com'), ('spam4.me'),
  ('mytemp.email'), ('emailondeck.com'), ('mailcatch.com'), ('inboxkitten.com'),
  ('moakt.com'), ('tmail.ws'), ('20minutemail.com'), ('33mail.com'),
  ('anonbox.net'), ('burnermail.io'), ('discard.email'), ('einrot.com'),
  ('fakemail.net'), ('gmailnator.com'), ('mailsac.com'), ('mintemail.com'),
  ('mvrht.net'), ('spambog.com'), ('tempinbox.com'), ('trashmail.de'),
  ('wegwerfmail.de'), ('luxusmail.org'), ('emltmp.com'), ('cs.email')
on conflict (domain) do nothing;

-- =============================================================================
-- 3) canonical_email trên profiles: khóa duy nhất theo "hòm thư thật".
-- =============================================================================
alter table public.profiles
  add column if not exists canonical_email text;

-- Backfill user cũ từ auth.users.email.
update public.profiles p
  set canonical_email = public.canonicalize_email(u.email)
  from auth.users u
  where u.id = p.id and p.canonical_email is null;

-- Unique index (nhiều NULL vẫn được phép) — backstop chống race giữa 2 lần đăng
-- ký cùng canonical: bản thứ hai sẽ vỡ ở đây khi handle_new_user ghi profile.
create unique index if not exists profiles_canonical_email_key
  on public.profiles(canonical_email);

-- Lúc tạo hồ sơ khi đăng ký: lưu luôn canonical_email.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, trial_ends_at, canonical_email)
  values (
    new.id,
    split_part(new.email, '@', 1),
    now() + interval '14 days',
    public.canonicalize_email(new.email)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- =============================================================================
-- 4) Trigger chốt chặn: chạy TRƯỚC khi GoTrue chèn user mới vào auth.users.
--    RAISE EXCEPTION -> hủy transaction -> đăng ký thất bại.
-- =============================================================================
create or replace function public.guard_auth_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_domain    text;
  v_canonical text;
begin
  -- Không có email (đăng ký qua phone/OAuth ẩn email...) thì bỏ qua.
  if new.email is null or new.email = '' then
    return new;
  end if;

  v_domain    := lower(split_part(new.email, '@', 2));
  v_canonical := public.canonicalize_email(new.email);

  -- 4a) Email dùng-một-lần / tạm thời.
  if exists (
    select 1 from public.disposable_email_domains where domain = v_domain
  ) then
    raise exception 'disposable_email_not_allowed'
      using errcode = 'check_violation';
  end if;

  -- 4b) Salting email: đã có hòm thư thật này đăng ký rồi.
  if exists (
    select 1 from public.profiles where canonical_email = v_canonical
  ) then
    raise exception 'email_already_registered'
      using errcode = 'unique_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_auth_signup on auth.users;
create trigger trg_guard_auth_signup
  before insert on auth.users
  for each row execute function public.guard_auth_signup();

-- =============================================================================
-- 5) RPC cho client pre-check trước khi signUp: CHỈ tiết lộ trạng thái domain
--    dùng-một-lần (không lộ email nào đã đăng ký -> tránh account enumeration).
--    Trả JSON: { allowed, reason }  với reason ∈ 'invalid' | 'disposable' | null
-- =============================================================================
create or replace function public.check_signup_email(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email  text := lower(trim(coalesce(p_email, '')));
  v_domain text := split_part(v_email, '@', 2);
begin
  if position('@' in v_email) = 0 or v_domain = '' or position('.' in v_domain) = 0 then
    return jsonb_build_object('allowed', false, 'reason', 'invalid');
  end if;

  if exists (
    select 1 from public.disposable_email_domains where domain = v_domain
  ) then
    return jsonb_build_object('allowed', false, 'reason', 'disposable');
  end if;

  return jsonb_build_object('allowed', true, 'reason', null);
end;
$$;

grant execute on function public.check_signup_email(text) to anon, authenticated;
