-- Mục tiêu dinh dưỡng theo gram giúp runner đặt macro trực tiếp, thay vì chỉ
-- dùng tỉ lệ % ngầm định. Các cột % cũ vẫn được giữ để tương thích dữ liệu.
alter table public.nutrition_goals
  add column if not exists protein_grams numeric(7,2),
  add column if not exists carbs_grams numeric(7,2),
  add column if not exists fat_grams numeric(7,2),
  add column if not exists source text not null default 'manual';

update public.nutrition_goals
set
  protein_grams = coalesce(protein_grams, daily_calories * protein_percentage / 400),
  carbs_grams = coalesce(carbs_grams, daily_calories * carbs_percentage / 400),
  fat_grams = coalesce(fat_grams, daily_calories * fat_percentage / 900)
where protein_grams is null or carbs_grams is null or fat_grams is null;

alter table public.nutrition_goals
  alter column protein_grams set not null,
  alter column carbs_grams set not null,
  alter column fat_grams set not null;

alter table public.nutrition_goals
  add constraint nutrition_goals_positive_values_check
  check (
    daily_calories > 0
    and protein_grams > 0
    and carbs_grams > 0
    and fat_grams > 0
  ) not valid,
  add constraint nutrition_goals_source_check
  check (source in ('manual', 'weight_based')) not valid;
