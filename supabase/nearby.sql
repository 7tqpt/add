-- ============================================================================
--  الأقربُ إليك: موقعُ مقدّم الخدمة، والترتيبُ بالمسافة
--
--  شغّله بعد `service_media.sql` و`location.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** البحثُ يُرشِّح بالمحافظة وحدها. ومن في عدن لا يريد قاعةً
--  في صنعاء، لكنّ «أمانة العاصمة» محافظةٌ واحدةٌ فيها مئةُ حيّ — ومن في
--  السنينة لا يريد كوشةً في سعوان يعبر إليها المدينة كلَّها ليلةَ العرس.
--
--  ── أربعةُ قراراتٍ تستحقّ أن تُقرأ ──────────────────────────────────────────
--
--  **١) ولا يُطلب موقعُ الجهاز.** «الأقربُ إليك» تُحسب من **عنوانك الافتراضيّ**
--  في دفترك — وهو موقعُ العرس نفسه، وهو أصدقُ ممّا يقوله GPS وأنت في مكتبك.
--  فلا إذنَ موقعٍ يُطلب، ولا سطرَ يُضاف إلى سياسة الخصوصية.
--
--  **٢) وحسابُ المسافة بالدالّة لا بامتداد.** `earthdistance` و PostGIS
--  يحتاجان تفعيلَ امتدادٍ على المشروع، وهو قرارٌ أكبرُ ممّا يُشترى به هنا.
--  والقانونُ الهافرسينيُّ سطرٌ من الرياضيّات يعمل في أيّ Postgres.
--
--  **٣) ولا فهرسَ مكانيّ — وهذا مقولٌ لا مسكوتٌ عنه.** الترتيبُ بالمسافة يمرّ
--  على كلّ مزوّدٍ ظاهر. وذلك رخيصٌ عند مئاتٍ وآلاف، ويصير ثقيلاً عند عشرات
--  الآلاف. فإن بلغت المنصّةُ ذلك فالطريقُ معروف: `cube` و`earthdistance`
--  وفهرسُ GiST — ويومَها يُبدَّل جوفُ دالّتين في هذا الملفّ وحده.
--
--  **٤) ومن لا موقعَ له يظهر آخراً لا يختفي.** مزوّدٌ لم يضع نقطته على
--  الخريطة موجودٌ وموثَّقٌ ويعمل — وإخفاؤه عقوبةٌ للعميل قبل المزوّد. وإذا
--  لم تكن للباحث نقطةٌ أصلاً عاد الترتيبُ إلى المعتاد: المميَّزُ ثمّ الأعلى
--  تقييماً، ولا يُعاقَب أحدٌ على خريطةٍ لا تُستعمل في ذلك النداء.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- نقطةُ مقدّم الخدمة
-- ----------------------------------------------------------------------------
alter table public.service_providers
  add column if not exists latitude  numeric(9, 6),
  add column if not exists longitude numeric(9, 6);

do $$ begin
  alter table public.service_providers add constraint provider_point_sane check (
    (latitude is null) = (longitude is null)
    and (latitude  is null or latitude  between  -90 and  90)
    and (longitude is null or longitude between -180 and 180));
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- المسافة بالكيلومترات — القانون الهافرسينيّ
--
-- `immutable`: مخرجُها يتبع مدخلاتِها وحدها، فيستطيع المخطِّطُ أن يحسبها مرّةً
-- ويُعيد استعمالها في `order by`.
--
-- ونصفُ قطر الأرض ٦٣٧١ كم — متوسّطٌ، وخطؤه دون نصف بالمئة على مسافاتٍ داخل
-- بلد. ومن يقيس «أيُّهما أقرب» لا يحتاج أكثر.
-- ----------------------------------------------------------------------------
create or replace function public.distance_km(
  lat1 numeric, lng1 numeric, lat2 numeric, lng2 numeric
)
returns numeric
language sql immutable parallel safe as $$
  select case
    when lat1 is null or lng1 is null or lat2 is null or lng2 is null then null
    else round((
      2 * 6371 * asin(sqrt(
        power(sin(radians(lat2 - lat1) / 2), 2)
        + cos(radians(lat1)) * cos(radians(lat2))
        * power(sin(radians(lng2 - lng1) / 2), 2)
      ))
    )::numeric, 2)
  end
$$;

-- ----------------------------------------------------------------------------
-- الطريقتان: تحملان نقطةَ المزوّد
--
-- **`drop` ثمّ `create`:** الطريقةُ لا تقبل زيادةَ عمودٍ في وسطها بـ
-- `create or replace`. وهذا الملفُّ يبني `v_services` كاملةً — بأعمدة الوسائط
-- التي أضافها `service_media.sql` — فلا يُفقدها من شغّله بعده.
--
-- **وتُحذف الدالّتان أوّلاً:** `returns setof public.v_services` تجعل الدالّة
-- تابعةً لنوع الطريقة، فلا تُحذف الطريقةُ وهما قائمتان. ومن شغّل هذا الملفَّ
-- مرّتين — وهو يفعل حين يشكّ — كان يُردّ بخطأ تبعيّة في السطر الأوّل.
--
-- **وتُحذفان بالاسم لا بالتوقيع.** فزيادةُ معاملٍ في Postgres تصنع دالّةً
-- ثانيةً لا تستبدل الأولى، و`drop function` بتوقيعٍ مكتوبٍ بيدٍ يُخطئ التوقيعَ
-- القديم فيتركه. وقد وقع هذا في هذا المشروع مرّتين — في `api_create_booking`
-- و`api_save_address` — فيُكتب هنا حذفٌ يمسح كلَّ توقيعٍ بهذين الاسمين.
-- ----------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in select oid::regprocedure as sig
             from pg_proc
            where pronamespace = 'public'::regnamespace
              and proname in ('api_services_nearby', 'api_providers_nearby')
  loop
    execute 'drop function ' || r.sig;
  end loop;
end $$;

drop view if exists public.v_services;

create view public.v_services
with (security_invoker = true) as
select
  s.id,
  s.title,
  s.description,
  s.price,
  s.price_to,
  s.unit,
  s.deposit_percent,
  s.duration_minutes,
  s.attributes,
  s.images,
  s.category_id,
  c.name  as category_name,
  c.slug  as category_slug,
  s.provider_id,
  p.business_name as provider_name,
  p.governorate   as provider_governorate,
  p.rating        as provider_rating,
  p.reviews_count as provider_reviews_count,
  p.is_featured   as provider_is_featured,
  p.latitude      as provider_latitude,
  p.longitude     as provider_longitude,
  pol.name  as cancellation_policy_name,
  pol.rules as cancellation_rules,
  (select m.path
     from public.service_media m
    where m.service_id = s.id and m.kind = 'image'
    order by m.sort_order, m.created_at
    limit 1)                                        as cover_path,
  (select count(*) from public.service_media m where m.service_id = s.id and m.kind = 'image')
                                                    as images_count,
  exists (select 1 from public.service_media m where m.service_id = s.id and m.kind = 'video')
                                                    as has_video,
  exists (select 1 from public.service_media m where m.service_id = s.id and m.kind = 'audio')
                                                    as has_audio,
  (p.verified_at is not null)                       as provider_verified
from public.provider_services s
join public.service_providers p on p.id = s.provider_id
join public.service_categories c on c.id = s.category_id
left join public.cancellation_policies pol on pol.id = s.cancellation_policy_id;

grant select on public.v_services to anon, authenticated;

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
-- api_services_nearby — الخدماتُ مرتّبةً بالقرب من نقطةٍ
--
-- **`returns setof public.v_services`** — لا جدولٌ يُعاد سرد أعمدته. فالصفُّ
-- هو الصفُّ نفسه الذي تقرؤه الشاشة من الطريقة، ولا يفترق الشكلان بمرور
-- الوقت. والمسافةُ تُحسب في التطبيق من العمودين اللذين في الصفّ أصلاً —
-- ضربٌ واحدٌ لكلّ بطاقةٍ معروضة، لا حاجةَ إلى إعادته من الخادم.
--
-- و`setof` لا يقع فيها فخُّ المركَّب الفارغ: قائمةٌ فارغةٌ تعني «لا نتائج»
-- لا صفّاً من NULLات.
-- ----------------------------------------------------------------------------
create or replace function public.api_services_nearby(
  p_latitude     numeric,
  p_longitude    numeric,
  p_category_id  uuid default null,
  p_search       text default '',
  p_limit        integer default 40,
  p_governorate  text default null
)
returns setof public.v_services
language sql stable security invoker as $$
  select v.*
    from public.v_services v
   where (p_category_id is null or v.category_id = p_category_id)
     -- **والمحافظةُ باقيةٌ مرشِّحاً.** الشاشةُ فيها شريطُ محافظاتٍ ومفتاحُ
     -- «الأقرب إليّ» معاً، فلو أسقطت هذه الطريقةُ المحافظةَ لَكذبت الشاشةُ
     -- على صاحبها: يختار «عدن» فتأتيه صنعاء.
     and (p_governorate is null or v.provider_governorate = p_governorate)
     and (
       btrim(coalesce(p_search, '')) = ''
       or v.title ilike '%' || btrim(p_search) || '%'
       or v.provider_name ilike '%' || btrim(p_search) || '%'
     )
   order by
     -- **من لا نقطةَ له آخراً لا خارجاً** — و`nulls last` وحدها تكفي لذلك.
     --
     -- وكان هنا علمٌ زائدٌ `(provider_latitude is null)` قبلها، فحُذف: هو لا
     -- يضيف شيئاً حين للباحث نقطة، ويُفسد حين لا نقطةَ له — إذ تصير المسافةُ
     -- NULL للجميع، فيهبط بالمزوّد المميَّز تحت غير المميَّز لأنّه لم يضع
     -- نقطةً على خريطةٍ لا تُستعمل أصلاً في هذا النداء.
     --
     -- وبحذفه: من لا نقطةَ للباحث عنده يرى الترتيبَ المعتاد — المميَّزُ ثمّ
     -- الأعلى تقييماً — وهو الصواب.
     public.distance_km(p_latitude, p_longitude, v.provider_latitude, v.provider_longitude)
       nulls last,
     v.provider_is_featured desc,
     v.provider_rating desc
   limit greatest(coalesce(p_limit, 40), 1)
$$;

revoke all on function public.api_services_nearby(numeric, numeric, uuid, text, integer, text)
  from public;
grant execute on function public.api_services_nearby(numeric, numeric, uuid, text, integer, text)
  to anon, authenticated;

-- ----------------------------------------------------------------------------
-- api_providers_nearby — الدليلُ مرتّباً بالقرب
-- ----------------------------------------------------------------------------
-- **والقسمُ هنا اسمٌ لا معرّف** — بخلاف `api_services_nearby` فوقها.
--
-- وليس هذا تناقضاً بل مطابقة: طريقةُ الدليل تحمل **أسماءَ** الأقسام في عمود
-- `categories`، والشاشةُ ترشِّح بها اليوم بـ`contains`. فلو أخذت هذه الطريقةُ
-- معرّفاً لَافترق مسلكا الشاشة الواحدة: الترتيبُ بالقرب يرشِّح بشيءٍ والترتيبُ
-- المعتادُ بشيءٍ آخر — ويومَ يختلفان لا يُدرى أيُّهما الصادق.
create or replace function public.api_providers_nearby(
  p_latitude     numeric,
  p_longitude    numeric,
  p_category     text default null,
  p_search       text default '',
  p_limit        integer default 40,
  p_governorate  text default null
)
returns setof public.v_providers
language sql stable security invoker as $$
  select v.*
    from public.v_providers v
   where (p_category is null or p_category = any(v.categories))
     and (p_governorate is null or v.governorate = p_governorate)
     and (
       btrim(coalesce(p_search, '')) = ''
       or v.business_name ilike '%' || btrim(p_search) || '%'
     )
   order by
     -- كما في `api_services_nearby` أعلاه: `nulls last` تكفي، ولا علمَ زائد.
     public.distance_km(p_latitude, p_longitude, v.latitude, v.longitude) nulls last,
     v.is_featured desc,
     v.rating desc
   limit greatest(coalesce(p_limit, 40), 1)
$$;

revoke all on function public.api_providers_nearby(numeric, numeric, text, text, integer, text)
  from public;
grant execute on function public.api_providers_nearby(numeric, numeric, text, text, integer, text)
  to anon, authenticated;

commit;
