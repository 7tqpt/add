-- ============================================================================
--  غلافُ الملفّ الشخصيّ — صورةُ خلفيّةٍ يرفعها صاحبُها بنفسه
--
--  شغّله في محرّر SQL بعد `install.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **لماذا:**
--
--  رأسُ الملفّ كان تدرّجاً نبيذيّاً واحداً على كلّ حساب — فملفُّ صاحب قاعةٍ
--  في صنعاء وملفُّ عريسٍ سجّل اليوم لا يفترقان في شيء. وصاحبُ القاعة يعرف
--  واجهتَه: صورةُ الصالة ليلةَ عرسٍ تقول عنه ما لا يقوله سطرُ تعريف. قال
--  صاحبُ المنصّة: «خليه العميل او مقدم الخدمة يقدر يضيفها بنفسه، نفس الفيس
--  بوك».
--
--  **ولا سلّةَ جديدة:** `avatars` قائمةٌ من `profile.sql` وسياساتُها بالضبط
--  ما يلزم — كلٌّ يكتب في مجلّده هو (`<auth_user_id>/…`) والقراءةُ للجميع.
--  فالغلافُ ملفٌّ ثالثٌ في المجلّد نفسِه إلى جانب `avatar.*` و`provider.*`.
--
--  **وعمودان لا واحد:** العميلُ غلافُه في `app_users`، ومقدّمُ الخدمة غلافُه
--  في `service_providers` — لأنّ الثاني هو ما **يراه العميل** في الصفحة
--  العامّة، والأوّل لا يراه إلّا صاحبُه. ولو كان عموداً واحداً لَصارت صورةُ
--  العريس الخاصّةُ واجهةَ متجره يومَ يصير مقدّمَ خدمة.
--
--  **ومن يكتب كلَّ عمود:** `api_update_profile` تكتب عمودَ العميل — وهي
--  الحارسُ الذي يمنع مسَّ `status` و`email` و`auth_user_id`. وعمودُ المزوّد
--  يكتبه صاحبُه بسياسة `providers_self_update` القائمة، والمُشغِّلُ
--  `guard_provider_self_update` يمنعه من مسّ الحالة والتوثيق والعمولة
--  والتقييم — وما بقي ملفُّه يعرضه كيف شاء.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- ١. العمودان
--
--    مسارٌ داخل السلّة لا رابطٌ كامل — للسبب نفسِه في `profile.sql`: الرابطُ
--    الموقّت ينتهي، والمسارُ يُشتقّ منه رابطٌ جديد عند كلّ عرض.
-- ----------------------------------------------------------------------------
alter table public.app_users
  add column if not exists cover_path text not null default '';

comment on column public.app_users.cover_path is
  'مسار غلاف الملفّ داخل سلّة avatars — لا رابطٌ كامل.';

alter table public.service_providers
  add column if not exists cover_path text not null default '';

comment on column public.service_providers.cover_path is
  'مسار غلاف صفحة المزوّد داخل سلّة avatars — هو ما يراه العميل.';

-- **وأعمدةُ ما قبله تُضمن هنا كي يقوم هذا الملفُّ وحدَه.** الطريقةُ العامّة
-- أدناه تُعيد سردَ أعمدتها، فلو نقص عمودٌ منها على قاعدةٍ لم يُشغَّل عليها
-- `provider_logo.sql` أو `location.sql` بعدُ لَسقط الملفُّ كلُّه عند الطريقة
-- — لا عند العمود الذي يعنينا. وكلُّها `if not exists` فلا تمسّ قاعدةً
-- شُغّلت عليها.
alter table public.service_providers
  add column if not exists logo_path text not null default '';

alter table public.service_providers
  add column if not exists latitude  numeric(9, 6);
alter table public.service_providers
  add column if not exists longitude numeric(9, 6);

-- ----------------------------------------------------------------------------
-- ٢. السلّة وسياساتها (هي نفسها سلّة صور المستخدمين)
--
--    تُعاد إنشاءً آمناً عند التكرار — كما في `provider_logo.sql` — كي يقوم
--    هذا الملفُّ وحدَه ولو لم يُشغَّل `profile.sql` بعد.
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
-- ٣. تعديلُ الملفّ يقبل الغلاف
--
--    **و`drop` قبل `create` لا `create or replace` وحدَها.** إضافةُ وسيطٍ
--    خامسٍ — ولو بقيمةٍ افتراضيّة — تُنشئ دالّةً **ثانيةً** باسمٍ واحدٍ
--    وتوقيعٍ مختلف، فتبقى ذاتُ الأربعة إلى جانبها. وPostgREST حينئذٍ يرى
--    حِملين لاسمٍ واحدٍ فيردّ كلَّ نداءٍ بـ«لا يمكن اختيار الدالّة»، ويسقط
--    حفظُ الاسم والجوال لكلّ مستخدمٍ في التطبيق — لا حفظُ الغلاف وحدَه.
--
--    والحقولُ الخمسةُ وحدها تُقبل: لا `status` ولا `auth_user_id` ولا
--    `email`، وهي في الجدول نفسِه ولولا الدالّةُ لطالتها يدُ من عرف اسم
--    العمود.
-- ----------------------------------------------------------------------------
drop function if exists public.api_update_profile(text, text, uuid, text);

create or replace function public.api_update_profile(
  p_full_name      text,
  p_phone          text default null,
  p_governorate_id uuid default null,
  p_avatar_path    text default null,
  p_cover_path     text default null
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

  -- `coalesce` لكل حقلٍ اختياري: من عدّل اسمه وحده لا يُفرَّغ جواله ولا
  -- يسقط غلافُه.
  update public.app_users u
     set full_name      = name_,
         phone          = coalesce(btrim(p_phone), u.phone),
         governorate_id = coalesce(p_governorate_id, u.governorate_id),
         governorate    = coalesce(
                            (select g.name from public.governorates g
                              where g.id = coalesce(p_governorate_id, u.governorate_id)),
                            u.governorate),
         avatar_path    = coalesce(p_avatar_path, u.avatar_path),
         cover_path     = coalesce(p_cover_path, u.cover_path)
   where u.auth_user_id = me
  returning * into row_;

  if not found then
    raise exception 'لا ملفَّ لحسابك بعد — أكمل التسجيل أولاً';
  end if;
  return row_;
end;
$$;

revoke all on function public.api_update_profile(text, text, uuid, text, text) from public;
grant execute on function public.api_update_profile(text, text, uuid, text, text) to authenticated;

-- `api_my_profile` لا تُمسّ: هي `select * from app_users`، فالعمودُ الجديد
-- يصل التطبيقَ من نفسِه.

-- ----------------------------------------------------------------------------
-- ٤. الطريقة العامّة — الغلافُ فيها، وهو ما يراه العميل
--
--    وشكلُها هو شكلُ `nearby.sql` (أحدثُها): الاسمُ التجاريُّ بالبديل،
--    والنقطةُ، والقصرُ على الموثّقين. ولو أُعيدت هنا إلى شكلٍ أقدمَ لَسقطت
--    «الأقرب إليّ» ولَظهر غيرُ الموثّقين — فيُصلَح عمودٌ ويُكسَر بابان.
--
--    **وتُحذف الدالّةُ التابعةُ أوّلاً — وهذا سقط منّي أوّلَ مرّة.**
--    `api_providers_nearby` تُعيد `setof public.v_providers`، فهي تابعةٌ
--    لنوع الطريقة ولا تُحذف الطريقةُ وهي قائمة. فرُدَّ الملفُّ على صاحب
--    المنصّة بـ«cannot drop view v_providers because other objects depend
--    on it» — و`nearby.sql` كان يحتاط لهذا منذ كُتب، ونسيتُه هنا.
--
--    **ولا `cascade`** — وهو الذي يقترحه الخادمُ في سطر `HINT`: يمسح
--    الدالّةَ صامتاً فتسقط «الأقربُ إليّ» ولا يعلم أحد. فتُحذف بالاسم،
--    وتُعاد بعد الطريقة كما كانت.
--
--    **وتُحذف بالاسم لا بالتوقيع:** زيادةُ معاملٍ في Postgres تصنع دالّةً
--    ثانيةً لا تستبدل الأولى، و`drop function` بتوقيعٍ مكتوبٍ بيدٍ يُخطئ
--    التوقيعَ القديم فيتركه. (وقع هذا في هذا المشروع مرّتين.)
-- ----------------------------------------------------------------------------

-- **أكانت قائمةً قبل الحذف؟** من لم يشغّل `nearby.sql` بعدُ لا دالّةَ عنده
-- ولا `distance_km` تحتها — فإعادتُها عليه تسقط بخطأ «لا دالّةَ بهذا الاسم»
-- داخل جسمٍ يُتحقَّق منه عند الإنشاء. فيُحفظ الجوابُ قبل الحذف.
select set_config(
  'farhati.had_nearby',
  case when to_regprocedure(
         'public.api_providers_nearby(numeric,numeric,text,text,integer,text)'
       ) is null then 'no' else 'yes' end,
  false);

do $drop$
declare r record;
begin
  for r in select oid::regprocedure as sig
             from pg_proc
            where pronamespace = 'public'::regnamespace
              and proname = 'api_providers_nearby'
  loop
    execute 'drop function ' || r.sig;
  end loop;
end $drop$;

drop view if exists public.v_providers;

create view public.v_providers
with (security_invoker = true) as
select
  p.id,
  coalesce(nullif(p.business_name, ''), p.full_name) as business_name,
  p.full_name,
  p.bio,
  p.logo_path,
  p.cover_path,
  p.governorate,
  p.coverage_areas,
  p.rating,
  p.reviews_count,
  p.completed_bookings,
  p.is_featured,
  p.verified_at,
  p.latitude,
  p.longitude,
  coalesce(
    (select array_agg(c.name order by c.sort_order)
     from public.provider_categories pc
     join public.service_categories c on c.id = pc.category_id
     where pc.provider_id = p.id),
    '{}'::text[]
  ) as categories
from public.service_providers p
where p.status = 'verified';

grant select on public.v_providers to anon, authenticated;

-- ----------------------------------------------------------------------------
-- ٥. وتُعاد الدالّةُ التابعةُ كما كانت — **إن كانت**
--
--    ونصُّها هو نصُّها في `nearby.sql` حرفاً بحرف. ولا تُكتب هنا نسخةٌ
--    «محسَّنة»: من شغّل الملفّين بأيّ ترتيبٍ يجب أن يخرج بدالّةٍ واحدةٍ
--    لا بدالّتين تختلفان بحسب أيُّهما شُغِّل أخيراً.
-- ----------------------------------------------------------------------------
do $restore$
begin
  if current_setting('farhati.had_nearby', true) <> 'yes' then return; end if;

  execute $f$
    create or replace function public.api_providers_nearby(
      p_latitude     numeric,
      p_longitude    numeric,
      p_category     text default null,
      p_search       text default '',
      p_limit        integer default 40,
      p_governorate  text default null
    )
    returns setof public.v_providers
    language sql stable security invoker as $body$
      select v.*
        from public.v_providers v
       where (p_category is null or p_category = any(v.categories))
         and (p_governorate is null or v.governorate = p_governorate)
         and (
           btrim(coalesce(p_search, '')) = ''
           or v.business_name ilike '%' || btrim(p_search) || '%'
         )
       order by
         public.distance_km(p_latitude, p_longitude, v.latitude, v.longitude) nulls last,
         v.is_featured desc,
         v.rating desc
       limit greatest(coalesce(p_limit, 40), 1)
    $body$
  $f$;

  execute 'revoke all on function public.api_providers_nearby'
       || '(numeric, numeric, text, text, integer, text) from public';
  execute 'grant execute on function public.api_providers_nearby'
       || '(numeric, numeric, text, text, integer, text) to anon, authenticated';
end $restore$;

commit;

-- PostgREST يحتفظ بذاكرةٍ مخبّأة لأسماء الدوال وتواقيعها، فقد لا يرى توقيعاً
-- تبدّل للتوّ — ويردّ بـ«لا دالّةَ بهذا الاسم» على دالّةٍ قائمة.
notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- تحقّق
-- ----------------------------------------------------------------------------
select 'غلاف العميل' as البند,
       count(*)::text as الواقع,
       '1' as المتوقع
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'app_users'
   and column_name = 'cover_path'
union all
select 'غلاف المزوّد',
       count(*)::text, '1'
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'service_providers'
   and column_name = 'cover_path'
union all
select 'في الطريقة العامّة',
       count(*)::text, '1'
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'v_providers'
   and column_name = 'cover_path'
union all
-- **وواحدةٌ لا اثنتان.** حِملان لاسمٍ واحدٍ يُسقطان حفظَ الملفّ كلَّه.
select 'دالّةُ التعديل — حِملٌ واحد',
       count(*)::text, '1'
  from information_schema.routines
 where routine_schema = 'public'
   and routine_name = 'api_update_profile'
union all
-- **و«الأقربُ إليّ» ما زالت قائمة.** هي التابعةُ التي تمنع حذفَ الطريقة،
-- فتُحذف وتُعاد هنا — ولو سقطت في الطريق لَاختفى الترتيبُ بالمسافة من
-- التطبيق كلِّه بلا رسالةٍ واحدة. ويُتوقَّع ١ لمن شغّل `nearby.sql`، و٠ لمن
-- لم يشغّله بعد — وكلاهما صحيح.
select 'الأقرب إليّ (1 إن شُغِّل nearby.sql)',
       count(*)::text, '1'
  from information_schema.routines
 where routine_schema = 'public'
   and routine_name = 'api_providers_nearby'
union all
select 'سلّة الصور',
       count(*)::text, '1'
  from storage.buckets
 where id = 'avatars';
