-- ============================================================================
--  الملف الشخصي: صورةٌ وتعديلُ بيانات
--
--  الاستخدام: Supabase ← SQL Editor ← New query ← الصق ← Run.
--  آمنٌ للتكرار: كل جملةٍ فيه `if not exists` أو `create or replace`.
--
--  ────────────────────────────────────────────────────────────────────────────
--  لماذا هذا الملف
--
--  شاشة «تعديل بياناتي» في التطبيق تعرض الاسم والجوال والمحافظة والصورة.
--  والثلاثة الأولى لها أعمدةٌ في `app_users` منذ البداية — أمّا الصورة فلا
--  عمودَ لها ولا سلّةَ تخزين. وحقلٌ يُعرض ولا يُحفظ أسوأ من حقلٍ غائب:
--  المستخدم يكتب ويضغط «حفظ» ويظنّ أنه حُفظ.
--
--  ────────────────────────────────────────────────────────────────────────────
--  وما لا يُعدَّل من هنا: **البريد**
--
--  هو في `app_users` نسخةٌ للعرض، وأصلُه في `auth.users` — به يدخل المستخدم.
--  فتغييرُه هنا وحده يُنتج حساباً يُعرض ببريدٍ ويدخل بآخر، والمستخدم لا يفهم
--  لماذا لا تعمل كلمته. وتغييرُه الصحيح يمرّ بـ`auth.updateUser` ورسالةِ
--  تأكيدٍ إلى العنوان الجديد — تدفّقٌ مستقلّ لا حقلٌ في بطاقة.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. عمود الصورة
--
--    مسارٌ داخل السلّة لا رابطٌ كامل: الرابط الموقّت ينتهي بعد ساعة، فتخزينه
--    يعني صورةً تختفي. والمسار ثابتٌ يُشتقّ منه رابطٌ جديد عند كل عرض.
-- ----------------------------------------------------------------------------
alter table public.app_users
  add column if not exists avatar_path text not null default '';

-- ----------------------------------------------------------------------------
-- ٢. سلّة الصور
--
--    عامّةٌ — بخلاف `provider-docs` الخاصة. ومستندُ التوثيق يحمل رقم هويةٍ
--    وسجلّاً تجارياً فيُحرَس، أمّا صورة الملف فيراها كل من تصفّح المزوّد في
--    التطبيق. وجعلُها خاصةً يعني رابطاً موقّتاً لكل صورةٍ في كل قائمة.
--
--    والحدّ ٢ ميجابايت: صورةُ ملفٍّ لا تحتاج أكثر، والحدُّ يمنع رفع فيديو
--    بامتدادٍ مغشوش.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public             = true,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- كلٌّ في مجلّده هو: `<auth_user_id>/avatar.jpg`. و`foldername(name)[1]` هو
-- الجزء الأوّل من المسار — فلا يكتب أحدٌ فوق صورة غيره.
drop policy if exists "anyone reads avatars" on storage.objects;
create policy "anyone reads avatars"
on storage.objects for select to anon, authenticated
using (bucket_id = 'avatars');

drop policy if exists "user uploads own avatar" on storage.objects;
create policy "user uploads own avatar"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "user replaces own avatar" on storage.objects;
create policy "user replaces own avatar"
on storage.objects for update to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "user deletes own avatar" on storage.objects;
create policy "user deletes own avatar"
on storage.objects for delete to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- ----------------------------------------------------------------------------
-- ٣. تعديل الملف
--
--    دالةٌ لا `update` مباشر من التطبيق: هي التي تحرس ما يُعدَّل. والحقول
--    الأربعة وحدها تُقبل — لا `status` ولا `auth_user_id` ولا `email`، وهي
--    في الجدول نفسه ولولا الدالة لطالتها يدُ من عرف اسم العمود.
-- ----------------------------------------------------------------------------
create or replace function public.api_update_profile(
  p_full_name      text,
  p_phone          text default null,
  p_governorate_id uuid default null,
  p_avatar_path    text default null
)
returns public.app_users
language plpgsql security definer set search_path = public as $$
declare
  me   uuid := auth.uid();
  row_ public.app_users;
  name_ text := btrim(coalesce(p_full_name, ''));
begin
  if me is null then
    raise exception 'سجّل الدخول أولاً';
  end if;
  if length(name_) < 2 then
    raise exception 'الاسم قصير جداً';
  end if;

  -- `coalesce` لكل حقلٍ اختياري: من عدّل اسمه وحده لا يُفرَّغ جواله.
  update public.app_users u
     set full_name      = name_,
         phone          = coalesce(btrim(p_phone), u.phone),
         governorate_id = coalesce(p_governorate_id, u.governorate_id),
         governorate    = coalesce(
                            (select g.name from public.governorates g
                              where g.id = coalesce(p_governorate_id, u.governorate_id)),
                            u.governorate),
         avatar_path    = coalesce(p_avatar_path, u.avatar_path)
   where u.auth_user_id = me
  returning * into row_;

  if not found then
    raise exception 'لا ملفَّ لحسابك بعد — أكمل التسجيل أولاً';
  end if;
  return row_;
end;
$$;

revoke all on function public.api_update_profile(text, text, uuid, text) from public;
grant execute on function public.api_update_profile(text, text, uuid, text) to authenticated;

-- ----------------------------------------------------------------------------
-- ٤. قراءة ملفي
-- ----------------------------------------------------------------------------
create or replace function public.api_my_profile()
returns public.app_users
language sql stable security definer set search_path = public as $$
  select * from public.app_users where auth_user_id = auth.uid()
$$;

revoke all on function public.api_my_profile() from public;
grant execute on function public.api_my_profile() to authenticated;

commit;

-- PostgREST يحتفظ بذاكرةٍ مخبَّأة لأسماء الدوال، فقد لا يرى دالةً أُنشئت للتوّ.
notify pgrst, 'reload schema';

-- ============================================================================
--  التحقق
-- ============================================================================
select 'عمود الصورة' as البند,
       count(*)::text as القيمة
  from information_schema.columns
 where table_schema = 'public' and table_name = 'app_users' and column_name = 'avatar_path'
union all
select 'سلّة الصور', count(*)::text from storage.buckets where id = 'avatars'
union all
select 'سياسات السلّة', count(*)::text from pg_policies
 where schemaname = 'storage' and policyname like '%avatar%'
union all
select 'دالتا الملف', count(*)::text from information_schema.routines
 where routine_schema = 'public'
   and routine_name in ('api_update_profile', 'api_my_profile');
