-- Kích hoạt bản nháp lịch tập một cách nguyên tử: chỉ archive lịch active cũ
-- sau khi đã xác nhận bản nháp hợp lệ và thuộc đúng người dùng.
create or replace function public.activate_training_schedule(p_schedule_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user uuid;
begin
  select user_id into target_user
  from public.training_schedules
  where id = p_schedule_id and user_id = auth.uid() and status = 'draft'
  for update;

  if target_user is null then
    raise exception 'draft schedule not found' using errcode = 'insufficient_privilege';
  end if;

  update public.training_schedules
  set status = 'archived'
  where user_id = auth.uid() and status = 'active' and id <> p_schedule_id;

  update public.training_schedules
  set status = 'active'
  where id = p_schedule_id and user_id = auth.uid();
end;
$$;

-- Bỏ qua/nghỉ là trạng thái của buổi tập, không phải một hoạt động chạy 0 km.
create or replace function public.skip_scheduled_workout(p_workout_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.scheduled_workouts
  set status = 'skipped', activity_id = null
  where id = p_workout_id
    and user_id = auth.uid()
    and status in ('planned', 'rescheduled');

  if not found then
    raise exception 'workout not found or already finished' using errcode = 'insufficient_privilege';
  end if;
end;
$$;

revoke all on function public.activate_training_schedule(uuid) from public;
revoke all on function public.skip_scheduled_workout(uuid) from public;
grant execute on function public.activate_training_schedule(uuid) to authenticated;
grant execute on function public.skip_scheduled_workout(uuid) to authenticated;

-- Chuyển các bản ghi nghỉ 0 km do phiên bản cũ tạo sang trạng thái skipped và
-- xóa hoạt động giả để activity_count, streak và huy hiệu được trigger tính lại.
update public.scheduled_workouts w
set status = 'skipped', activity_id = null
where w.activity_id in (
  select a.id
  from public.activities a
  where a.distance_km = 0
    and a.duration_min = 0
    and (
      (a.name = 'Nghỉ ngơi' and a.notes = 'Tự động ghi nhận là nghỉ ngơi (0 km)')
      or
      (a.name = 'Rest' and a.notes = 'Automatically record as rest (0 km)')
    )
);

delete from public.activities a
where a.distance_km = 0
  and a.duration_min = 0
  and (
    (a.name = 'Nghỉ ngơi' and a.notes = 'Tự động ghi nhận là nghỉ ngơi (0 km)')
    or
    (a.name = 'Rest' and a.notes = 'Automatically record as rest (0 km)')
  );
