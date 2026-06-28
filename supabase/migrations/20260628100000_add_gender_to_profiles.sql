-- Thêm trường giới tính vào hồ sơ người dùng (dùng cho cá nhân hóa lịch tập &
-- tư vấn của HLV AI). Lưu giá trị chuẩn 'male' | 'female' | 'other'.
alter table public.profiles
add column if not exists gender text;
