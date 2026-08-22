-- ============================================================================
--  شعارُ مقدّم الخدمة
--
--  شغّله في محرّر SQL بعد `install.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **لماذا:**
--
--  ملفُّ المزوّد كان يبدأ بحرفٍ في قرص — بديلٌ عن صورةٍ لا وجود لها في
--  القاعدة. وصاحبُ القاعة له شعارٌ ولافتة، والعميلُ يعرف «قاعة التاج» بصورتها
--  قبل أن يقرأ اسمها. فحرفٌ في دائرةٍ يقول: هذا مكانٌ لم يُكمِل صاحبُه ملفَّه.
--
--  **ولا سلّةَ جديدة:** `avatars` قائمةٌ من `profile.sql` وسياساتُها بالضبط ما
--  يلزم — كلٌّ يكتب في مجلّده هو (‏`<auth_user_id>/…`‏) والقراءةُ للجميع.
--  ومقدّمُ الخدمة مستخدمٌ مسجَّل كغيره، فيرفع شعارَه في مجلّده كما يرفع صورته.
--  وتُعاد هنا إنشاءً آمناً عند التكرار كي يقوم هذا الملف وحده ولو لم يُشغَّل
--  `profile.sql` بعد.
--
--  **ومن يكتب العمود:** المزوّد نفسه، بسياسة `providers_self_update` القائمة.
--  ولا يحتاج دالّةً: المُشغِّل `guard_provider_self_update` يمنعه أصلاً من
--  مسّ الحالة والتوثيق والعمولة والتقييم، وما بقي ملفُّه يعرضه كيف شاء.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. العمود
-- ----------------------------------------------------------------------------
alter table public.service_providers
  add column if not exists logo_path text not null default '';

comment on column public.service_providers.logo_path is
  'مسار الشعار داخل سلّة avatars — لا رابطٌ كامل.';

-- ----------------------------------------------------------------------------
-- ٢. السلّة وسياساتها (هي نفسها سلّة صور المستخدمين)
--
--    الحدّ ٢ ميجابايت: شعارٌ لا يحتاج أكثر، والحدُّ يمنع رفع فيديو بامتدادٍ
--    مغشوش — وهو مفروضٌ من التخزين لا من تطبيقٍ يُعدَّل.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public             = true,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

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
-- ٣. الطريقة العامة
--
--    `drop` ثم `create` لا `create or replace`: الثانية لا تقبل عموداً جديداً
--    في وسط القائمة، وهذا العمود يقع بعد `bio` ليطابق ما في `api.sql` — فمن
--    أعاد تشغيل `install.sql` غداً وجد الشكل نفسه ولم يصطدم بشيء.
--
--    ولا `cascade`: لو تعلّق بها شيءٌ لم أعلم به فليقل ذلك الآن، لا أن يسقط
--    صامتاً.
-- ----------------------------------------------------------------------------
drop view if exists public.v_providers;

create view public.v_providers
with (security_invoker = true) as
select
  p.id,
  p.business_name,
  p.full_name,
  p.bio,
  p.logo_path,
  p.governorate,
  p.coverage_areas,
  p.rating,
  p.reviews_count,
  p.completed_bookings,
  p.is_featured,
  p.verified_at,
  coalesce(
    (select array_agg(c.name order by c.sort_order)
     from public.provider_categories pc
     join public.service_categories c on c.id = pc.category_id
     where pc.provider_id = p.id),
    '{}'
  ) as categories
from public.service_providers p;

grant select on public.v_providers to anon, authenticated;

commit;

-- ----------------------------------------------------------------------------
-- تحقّق
-- ----------------------------------------------------------------------------
select 'العمود' as البند,
       count(*)::text as الواقع,
       '1' as المتوقع
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'service_providers'
   and column_name = 'logo_path'
union all
select 'في الطريقة العامة',
       count(*)::text, '1'
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'v_providers'
   and column_name = 'logo_path'
union all
select 'سلّة الصور',
       count(*)::text, '1'
  from storage.buckets
 where id = 'avatars';
