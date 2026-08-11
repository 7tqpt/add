-- ============================================================================
--  تعيين أول مسؤول للوحة التحكم
--
--  لا تُنفَّذ إلا بعد install.sql، ولا تعمل قبل إنشاء المستخدم نفسه:
--
--    1) Supabase ← Authentication ← Users ← Add user
--       أدخل البريد وكلمة المرور، وفعّل Auto Confirm User.
--    2) بدّل البريد في السطر أدناه إلى البريد الذي أنشأته.
--    3) نفّذ هذا الملف في SQL Editor.
--
--  لماذا خطوة منفصلة: جدول admins يشير إلى auth.users، والصلاحية تُمنح
--  لحسابٍ قائم لا لبريدٍ مكتوب. من ليس له صف هنا لا يدخل اللوحة أصلاً —
--  وهذا هو ما يمنع العميل ومقدّم الخدمة من الوصول إليها.
-- ============================================================================

do $$
declare
  target_email text := 'CHANGE-ME@example.com';  -- ← بدّل هذا
  target_id    uuid;
begin
  select id into target_id from auth.users where lower(email) = lower(target_email);

  if target_id is null then
    raise exception
      'لا يوجد مستخدم بالبريد %. أنشئه أولاً من Authentication ← Users ← Add user.',
      target_email;
  end if;

  -- التشغيل مرة ثانية يرفع الدور بدل أن يفشل، فلا ضرر من إعادة التنفيذ.
  insert into public.admins (user_id, email, role)
  values (target_id, target_email, 'owner')
  on conflict (user_id) do update set role = 'owner', email = excluded.email;

  raise notice 'تم تعيين % مالكاً للوحة.', target_email;
end $$;

-- للتحقق:
--   select email, role, created_at from public.admins order by created_at;
