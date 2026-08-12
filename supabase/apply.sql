-- ============================================================================
--  التحديث الثاني — طرق عرض اللوحة + قسم الطبخ
--
--  الاستخدام:
--    Supabase ← SQL Editor ← New query ← الصق الملف كاملاً ← Run.
--    يُنفَّذ بعد install.sql، ويغني عن تشغيل admin_views.sql و
--    add_catering_category.sql منفصلين — هو هما مجموعين في لصقة واحدة.
--
--  ما الذي يصلحه:
--    الجداول مُسوّاة (normalized): الخدمة تحمل category_id لا اسم القسم،
--    والتقييم يحمل provider_id لا اسم مقدّم الخدمة. وهذا هو الصواب للتخزين —
--    الاسم يتغيّر في مكان واحد فيتغيّر في كل مكان. لكن اللوحة تعرض أسماء لا
--    معرّفات، فبدون هذه الطرق تفشل ست شاشات: التقييمات، مقدّمو الخدمة،
--    الكتالوج، التسويات، الحملات، والخطط.
--
--  ⚠️  الترتيب: بعد seed.sql لا قبله. seed.sql يحذف كل الأقسام ثم يعيد إدخال
--      أحد عشر قسماً، فلو نُفِّذ هذا قبله ضاع قسم الطبخ. وإن أعدتَ تشغيل
--      seed.sql يوماً ما، أعد تشغيل هذا الملف بعده.
--
--  التشغيل مرة ثانية آمن، وهذا مقصود: `drop view if exists` قبل كل إنشاء بدل
--  `create or replace`. الفرق ليس تجميلياً — `create or replace` ترفض أي
--  تغيير في قائمة الأعمدة، وطرقٌ تختار `p.*` تكتسب عموداً جديداً في منتصفها
--  كلما أُضيف عمود إلى جدولها الأصلي، فتنكسر إعادة التشغيل بعد أول تعديل على
--  المخطط. الحذف ثم الإنشاء ينجح في الحالتين.
-- ============================================================================

begin;

-- ############################################################################
-- ##  ١ — طرق عرض اللوحة
-- ############################################################################

-- ----------------------------------------------------------------------------
-- مقدّمو الخدمة + أسماء أقسامهم
-- ----------------------------------------------------------------------------
drop view if exists public.v_admin_providers;
create view public.v_admin_providers
with (security_invoker = true) as
select
  p.*,
  coalesce(
    (select array_agg(c.name order by c.sort_order)
       from public.provider_categories pc
       join public.service_categories c on c.id = pc.category_id
      where pc.provider_id = p.id),
    '{}'::text[]
  ) as categories
from public.service_providers p;

-- ----------------------------------------------------------------------------
-- الخدمات + اسم مقدّمها وقسمها وسياسة إلغائها
-- ----------------------------------------------------------------------------
drop view if exists public.v_admin_services;
create view public.v_admin_services
with (security_invoker = true) as
select
  s.*,
  coalesce(p.business_name, p.full_name, '') as provider_name,
  coalesce(c.name, '')                       as category_name,
  coalesce(cp.name, '')                      as cancellation_policy_name
from public.provider_services s
left join public.service_providers    p  on p.id  = s.provider_id
left join public.service_categories   c  on c.id  = s.category_id
left join public.cancellation_policies cp on cp.id = s.cancellation_policy_id;

-- ----------------------------------------------------------------------------
-- التسويات + عدد الحجوزات التي تغطّيها
-- ----------------------------------------------------------------------------
drop view if exists public.v_admin_settlements;
create view public.v_admin_settlements
with (security_invoker = true) as
select
  st.*,
  (select count(*) from public.settlement_items i where i.settlement_id = st.id)::integer
    as bookings_count
from public.settlements st;

-- ----------------------------------------------------------------------------
-- التقييمات + رقم الحجز واسم مقدّم الخدمة
-- ----------------------------------------------------------------------------
drop view if exists public.v_admin_reviews;
create view public.v_admin_reviews
with (security_invoker = true) as
select
  r.*,
  coalesce(b.reference, '')                  as booking_reference,
  coalesce(p.business_name, p.full_name, '') as provider_name
from public.reviews r
left join public.bookings          b on b.id = r.booking_id
left join public.service_providers p on p.id = r.provider_id;

-- ----------------------------------------------------------------------------
-- باقات الاشتراك + عدد المشتركين السارين
-- ----------------------------------------------------------------------------
drop view if exists public.v_admin_subscription_plans;
create view public.v_admin_subscription_plans
with (security_invoker = true) as
select
  sp.*,
  (select count(*) from public.provider_subscriptions s
    where s.plan_id = sp.id and s.status = 'active')::integer as subscribers_count
from public.subscription_plans sp;

-- ----------------------------------------------------------------------------
-- الحملات الترويجية + اسم القسم المستهدف
-- ----------------------------------------------------------------------------
drop view if exists public.v_admin_promotions;
create view public.v_admin_promotions
with (security_invoker = true) as
select
  pr.*,
  coalesce(c.name, '') as category_name
from public.promotions pr
left join public.service_categories c on c.id = pr.category_id;

-- ----------------------------------------------------------------------------
-- خطط الأعراس — تُستبدل بنسخة تحمل ما تعرضه الشاشة
--
--  الأصلية تُسمّي المفتاح plan_id، والواجهة تقرأ id كبقية السجلات. وتنقصها
--  اسم صاحب الخطة وملاحظاتها وتاريخ إنشائها، وكلها معروضة في شاشة التفاصيل.
-- ----------------------------------------------------------------------------
drop view if exists public.v_plan_summary;
create view public.v_plan_summary
with (security_invoker = true) as
select
  pl.id,
  pl.id as plan_id,
  pl.user_id,
  coalesce(u.full_name, '') as user_name,
  pl.title,
  pl.wedding_date,
  pl.governorate,
  pl.guests_count,
  pl.budget,
  pl.status,
  pl.notes,
  pl.created_at,
  count(b.id) filter (where b.status <> 'cancelled')::integer as services_count,
  coalesce(sum(b.total_price) filter (where b.status not in ('cancelled', 'rejected')), 0)
    as total_cost,
  coalesce(sum(b.paid_amount) filter (where b.status not in ('cancelled', 'rejected')), 0)
    as paid_amount,
  coalesce(sum(b.total_price - b.paid_amount)
           filter (where b.status not in ('cancelled', 'rejected')), 0) as remaining_amount
from public.wedding_plans pl
left join public.app_users u on u.id = pl.user_id
left join public.bookings  b on b.plan_id = pl.id
group by pl.id, u.full_name;

grant select on
  public.v_admin_providers,
  public.v_admin_services,
  public.v_admin_settlements,
  public.v_admin_reviews,
  public.v_admin_subscription_plans,
  public.v_admin_promotions,
  public.v_plan_summary
to authenticated;

-- ############################################################################
-- ##  ٢ — قسم «الطبخ والضيافة»
-- ############################################################################

-- الطعام من أكبر بنود العرس اليمني، وكان ساقطاً من قائمة الأقسام.
insert into public.service_categories (name, slug, description, sort_order, custom_fields)
values (
  'الطبخ والضيافة',
  'catering',
  'طباخين، مطابخ مناسبات، بوفيهات، ذبائح، مندي وحنيذ، قهوة وشاي، وطاقم تقديم.',
  2,
  '[{"key":"guests_capacity","label":"عدد الأشخاص","type":"number","required":true},
    {"key":"menu_style","label":"نمط الوجبة","type":"text","required":false},
    {"key":"includes_service","label":"يشمل طاقم التقديم","type":"boolean","required":false}]'::jsonb
)
on conflict (slug) do update set
  name          = excluded.name,
  description   = excluded.description,
  sort_order    = excluded.sort_order,
  custom_fields = excluded.custom_fields;

-- الترتيب يُثبَّت بقيم صريحة لا بزيادة مقدار.
--
-- `sort_order = sort_order + 1` تبدو أبسط، لكنها تزيد مرة أخرى في كل تشغيل
-- فتترك فجوات (1,2,5,6,…) — وقد كشف ذلك اختبارٌ يشغّل الملف مرتين. القيمة
-- الصريحة تُنتج الترتيب نفسه مهما تكرّر التنفيذ.
update public.service_categories c
   set sort_order = v.rank
  from (values
    ('halls', 1), ('catering', 2), ('artists', 3), ('sound', 4),
    ('photography', 5), ('support', 6), ('cars', 7), ('attire', 8),
    ('planners', 9), ('beauty', 10), ('decor', 11), ('printing', 12)
  ) as v(slug, rank)
 where c.slug = v.slug and c.sort_order is distinct from v.rank;

commit;

-- ============================================================================
--  التحقق — المتوقّع: 7 طرق عرض، و 12 قسماً، و«الطبخ والضيافة» في الترتيب ٢
-- ============================================================================
select 'طرق العرض' as البند, count(*)::text as القيمة
  from pg_views
 where schemaname = 'public'
   and (viewname like 'v\_admin\_%' or viewname = 'v_plan_summary')
union all
select 'الأقسام', count(*)::text from public.service_categories
union all
select 'ترتيب الطبخ', coalesce(min(sort_order)::text, 'غير موجود')
  from public.service_categories where slug = 'catering';
