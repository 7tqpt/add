-- ============================================================================
--  اللافتاتُ الإعلانيّة في أعلى الرئيسية
-- ============================================================================
--
--  المساحةُ التي كانت لبطاقتَي «خطة العرس» و«حجوزاتي» صارت للإعلان، تُدار من
--  لوحة التحكّم. ولا جدولَ جديدٌ لها: `promotions` فيها `kind = 'banner'`
--  و`image_url` و`starts_at`/`ends_at` منذ أوّل مخطَّط — كانت معرَّفةً ولا
--  تُقرأ.
--
--  ── وعلّةٌ كانت كامنةً تُصلَح هنا ──────────────────────────────────────────
--
--  `api_active_promotions` — التي تملأ شريط «مزوّدون مميّزون» — **لا تسأل عن
--  النوع**. فأوّلُ لافتةٍ تُنشأ كانت ستظهر في ذلك الشريط بطاقةَ مزوّدٍ كذلك،
--  لأنّ كليهما صفٌّ في الجدول نفسِه بحالة `active`. ولم يظهر ذلك قطُّ لأنّه
--  لم تُنشأ لافتةٌ قطّ. فتُقيَّد بـ`kind = 'featured'`.
--
--  التشغيل:  psql "$DATABASE_URL" -f supabase/banners.sql
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
--  سلّةُ صور اللافتات — عامّةٌ للقراءة، ويكتب فيها من يكتب في «النموّ»
-- ----------------------------------------------------------------------------
--
--  ومنفصلةٌ عن `category-images`: حدُّ الحجم هنا أوسع (اللافتةُ صورةٌ عريضة
--  لا أيقونةُ قسم)، وحذفُ صورِ حملةٍ منتهيةٍ لا يجوز أن يقترب من صور الأقسام.
--
--  **وكان المجالُ هنا `growth` فمنع الجميع.** لا وجودَ لمجالٍ بهذا الاسم:
--  المجالاتُ تسعةٌ — bookings، directory، catalog، finance، trust، support،
--  ops، settings، admins — و`area_level` تُرجع `'none'` لِما ليس منها. فكانت
--  السياسةُ الأربعُ تُرجع «لا» لكلّ الأدوار، **المالكُ فيها**، ولا يستطيع
--  أحدٌ رفعَ صورةِ لافتةٍ ألبتّة: `new row violates row-level security policy`.
--
--  والصوابُ `finance` — وهو المجالُ الذي يحرس جدولَ `promotions` نفسَه في
--  `roles.sql`. فالصورةُ وصفُّها شيءٌ واحد، فمفتاحُهما واحد.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ad-banners', 'ad-banners', true, 2097152,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists ad_banners_public_read on storage.objects;
create policy ad_banners_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'ad-banners');

drop policy if exists ad_banners_admin_insert on storage.objects;
create policy ad_banners_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'ad-banners' and public.can_write_area('finance'));

drop policy if exists ad_banners_admin_update on storage.objects;
create policy ad_banners_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'ad-banners' and public.can_write_area('finance'))
  with check (bucket_id = 'ad-banners' and public.can_write_area('finance'));

drop policy if exists ad_banners_admin_delete on storage.objects;
create policy ad_banners_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'ad-banners' and public.can_write_area('finance'));

-- ----------------------------------------------------------------------------
--  صورٌ عدّة للّافتة الواحدة، وكلماتٌ تُكتب فوقها
-- ----------------------------------------------------------------------------
--
--  `image_url` عمودٌ واحد، وصاحبُ المنصّة يريد للحملة الواحدة عدّةَ صور.
--  فيُضاف `image_urls`، **ويبقى القديمُ كما هو**: صفوفٌ كُتبت بعمودٍ واحد
--  لا يجوز أن تختفي لأنّ العمودَ تبدّل. والدالّةُ أدناه تقرأ الاثنين.
--
--  و`headline` كلماتُ الإعلان. وكانت الصورةُ وحدَها تحمل نصَّها — أي أنّ كلَّ
--  تبديلِ كلمةٍ يحتاج مصمّماً يعيد الصورة.
alter table public.promotions
  add column if not exists image_urls text[] not null default '{}';

alter table public.promotions
  add column if not exists headline text not null default '';

-- والقديمُ يُنقل مرّةً واحدة: صفٌّ له صورةٌ ولا مصفوفة.
update public.promotions
   set image_urls = array[image_url]
 where coalesce(image_url, '') <> ''
   and coalesce(array_length(image_urls, 1), 0) = 0;

-- ----------------------------------------------------------------------------
--  ما يقرؤه التطبيق
-- ----------------------------------------------------------------------------
--
--  **وصورةٌ فارغةٌ تُسقَط هنا لا في التطبيق وحده.** لافتةٌ بلا صورة تعني في
--  الشاشة مستطيلاً رماديّاً بعرضها في أعلى الرئيسية — وهو أسوأُ مما لو لم
--  تكن هناك لافتةٌ أصلاً.
--
--  والاسمُ الظاهرُ من المزوّد إن كان لها مزوّد: اللافتةُ قد تكون حملةً من
--  المنصّة نفسِها فلا وجهةَ لها ولا اسم.
--
--  **و`business_name` مبدَؤه فراغٌ لا NULL.** من سجّل مزوّداً باسمه ولم يكتب
--  اسمَ منشأةٍ يُقرأ اسمُه **فارغاً** في كلّ موضعٍ يعرضه — لا NULL يُمسَك
--  بـ`coalesce` بل نصٌّ فارغٌ يمرّ منها. فيُقلَب بـ`nullif` أوّلاً، ويُرجَع
--  إلى `full_name` وهو `not null` بلا مبدأ.
--  **وصورةٌ واحدةٌ في كلّ صفٍّ يُعاد لا مصفوفةٌ في صفّ.** اللافتةُ في الشاشة
--  شريحةٌ تُمرَّر، فحملةٌ بثلاث صورٍ ثلاثُ شرائح — تحمل كلُّها وجهةَ الحملة
--  نفسَها وكلماتِها. ولو أُعيدت المصفوفةُ كما هي لَاحتاج التطبيقُ أن يفرشها
--  بنفسه، وهو عملٌ يقع في مكانٍ واحدٍ ها هنا أو في كلّ شاشةٍ تقرأ لافتة.
--
--  والمعرّفُ يحمل رقمَ الصورة معه (`<uuid>#2`): ثلاثُ شرائحَ بمعرّفٍ واحد
--  تلتبس على أيّ قائمةٍ تُميّز عناصرَها بالمعرّف.
drop function if exists public.api_active_banners();

create or replace function public.api_active_banners()
returns table (
  id text, image_url text, headline text,
  provider_id uuid, provider_name text, ends_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select pr.id::text || '#' || img.ord::text,
         img.url,
         pr.headline,
         pr.provider_id,
         coalesce(nullif(p.business_name, ''), p.full_name, ''),
         pr.ends_at
    from public.promotions pr
    left join public.service_providers p
           on p.id = pr.provider_id and p.status = 'verified'
    cross join lateral unnest(
      -- والمصفوفةُ إن كانت، وإلّا فالعمودُ القديم: صفوفٌ كُتبت قبل هذا
      -- التعديل تبقى تُعرض كما كانت.
      case when coalesce(array_length(pr.image_urls, 1), 0) > 0
           then pr.image_urls
           else array[pr.image_url] end
    ) with ordinality as img(url, ord)
   where pr.kind = 'banner'
     and pr.placement = 'home'
     and pr.status = 'active'
     and now() between pr.starts_at and pr.ends_at
     and coalesce(img.url, '') <> ''
   order by pr.starts_at desc, img.ord
   limit 8
$$;

grant execute on function public.api_active_banners() to anon, authenticated;

-- ----------------------------------------------------------------------------
--  وشريطُ «مزوّدون مميّزون» يقتصر على الإبراز
-- ----------------------------------------------------------------------------
--
--  ── وعمودان يُضافان: التوثيقُ والقسم ──────────────────────────────────────
--
--  البطاقةُ كانت اسماً ومحافظةً وحدَهما، والعميلُ يسأل عنهما آخِراً. أوّلُ
--  ما يسأله: **ماذا يقدّم هذا؟** وثانيه: **أموثَّقٌ هو؟** فيُرسَلان معه.
--
--  **والتوثيقُ يُرسَل وإن كان اليومَ محسوماً.** الشرطُ أدناه `p.status =
--  'verified'`، فكلُّ صفٍّ يخرج من هنا موثَّقٌ قطعاً — ولو كُتبت العلامةُ
--  في التطبيق ثابتةً لَصدقت اليوم. لكنّها تصير كذبةً في اليوم الذي يُوسَّع
--  فيه الشرط، ولا شيءَ يُنبّه. فيُقرأ من الصفّ.
--
--  والقسمُ الأوّلُ بترتيبه لا كلُّ أقسامه: البطاقةُ في الشريط ١٦٤ بكسلاً،
--  وثلاثةُ أقسامٍ فيها تُقرأ حشواً. ومن أراد الباقيَ فتح الملفّ.
drop function if exists public.api_active_promotions();

create or replace function public.api_active_promotions()
returns table (
  id uuid, provider_id uuid, provider_name text, logo_path text,
  governorate text, rating numeric, verified boolean, category text,
  ends_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select pr.id, pr.provider_id,
         coalesce(nullif(p.business_name, ''), p.full_name),
         p.logo_path,
         p.governorate, p.rating,
         (p.verified_at is not null),
         coalesce(
           (select c.name
              from public.provider_categories pc
              join public.service_categories c on c.id = pc.category_id
             where pc.provider_id = p.id
             order by c.sort_order
             limit 1),
           ''),
         pr.ends_at
    from public.promotions pr
    join public.service_providers p on p.id = pr.provider_id
   where pr.kind = 'featured'
     and pr.status = 'active'
     and now() between pr.starts_at and pr.ends_at
     and p.status = 'verified'
   order by pr.ends_at asc
   limit 10
$$;

grant execute on function public.api_active_promotions() to anon, authenticated;

-- ----------------------------------------------------------------------------
--  والمجدولةُ تُفعَّل حين يحين وقتها
-- ----------------------------------------------------------------------------
--
--  **وهذه ثغرةٌ كانت في النظام كلِّه لا في اللافتات وحدها.** `expire_promotions`
--  تُنهي ما انقضى، ولا شيءَ يرفع `scheduled` إلى `active` حين يحين موعدُها.
--  فحملةٌ تُنشأ لتبدأ غداً كانت تبقى «مجدولة» إلى الأبد ولا تُعرض يوماً.
--
--  والاسمُ يبقى `expire_promotions` ليبقى ما يناديه — الجدولةُ اليوميّة —
--  عاملاً بلا تعديل.
create or replace function public.expire_promotions()
returns integer language plpgsql security definer set search_path = public as $$
declare
  n integer;
begin
  update public.promotions
     set status = 'active'
   where status = 'scheduled'
     and now() between starts_at and ends_at;

  update public.promotions
     set status = 'ended'
   where status = 'active' and ends_at < now();
  get diagnostics n = row_count;
  return n;
end $$;

revoke execute on function public.expire_promotions() from public, authenticated;

commit;

-- ----------------------------------------------------------------------------
--  تحقّق
-- ----------------------------------------------------------------------------
select 'سلّة اللافتات' as البند,
       coalesce((select id from storage.buckets where id = 'ad-banners'), 'غير موجودة') as القيمة
union all
select 'دالّة اللافتات',
       coalesce((select 'موجودة' from pg_proc where proname = 'api_active_banners'), 'غير موجودة')
union all
select 'شريط المميّزين يرسل التوثيق والقسم',
       case when (select prosrc from pg_proc where proname = 'api_active_promotions')
                 like '%verified_at is not null%'
            then 'نعم' else 'لا' end
union all
select 'شريط المميّزين يقتصر على featured',
       case when (select prosrc from pg_proc where proname = 'api_active_promotions')
                 like '%kind = ''featured''%'
            then 'نعم' else 'لا' end
union all
select 'عمودا الصور والكلمات',
       case when (select count(*) from information_schema.columns
                   where table_schema = 'public' and table_name = 'promotions'
                     and column_name in ('image_urls', 'headline')) = 2
            then 'موجودان' else 'ناقصان' end
-- **وهذا السطرُ هو الذي كان سيكشف العلّة.** سياساتُ السلّة كانت على مجالٍ
-- اسمُه `growth` ولا وجودَ له في `admin_areas`، فمنعت الجميعَ بلا خطأٍ في
-- التنفيذ — ولا يظهر ذلك إلّا حين يحاول إنسانٌ رفعَ صورةٍ فيُردّ.
union all
select 'مجالُ صلاحيةِ اللافتات معرَّفٌ في الأدوار',
       case when exists (select 1 from public.admin_areas where area = 'finance')
            then 'نعم' else 'لا — لن يرفع أحدٌ صورة' end
union all
select 'ومن يملك الكتابةَ فيه',
       (select count(distinct role)::text from public.admin_areas
         where area = 'finance' and level = 'write');
