-- ============================================================================
--  طرق عرض لوحة التحكم
--
--  الجداول مُسوّاة (normalized): الخدمة تحمل category_id لا اسم القسم، والتقييم
--  يحمل provider_id لا اسم مقدّم الخدمة. وهذا هو الصواب للتخزين — الاسم يتغيّر
--  في مكان واحد فيتغيّر في كل مكان.
--
--  لكن اللوحة تعرض أسماء لا معرّفات. الخيار بين أمرين: أن يجمع كل استعلام في
--  الواجهة جداوله بنفسه، أو أن يُكتب الجمع مرة واحدة هنا. الثاني أفضل: شكل
--  الاستجابة يبقى مسطّحاً كما تتوقعه الأنواع في src/lib/types.ts، وتعديل
--  الأعمدة لاحقاً يقع في ملف واحد لا في اثنتي عشرة شاشة.
--
--  security_invoker = true في كلٍّ منها: تُنفَّذ بصلاحيات المستدعي، فتبقى RLS
--  على الجداول الأصلية سارية. طريقة عرض بلا هذا الخيار تعمل بصلاحيات مالكها
--  وتصير ثغرةً تلتفّ حول السياسات كلها.
--
--  تُنفَّذ بعد install.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- مقدّمو الخدمة + أسماء أقسامهم
-- ----------------------------------------------------------------------------
create or replace view public.v_admin_providers
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
create or replace view public.v_admin_services
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
create or replace view public.v_admin_settlements
with (security_invoker = true) as
select
  st.*,
  (select count(*) from public.settlement_items i where i.settlement_id = st.id)::integer
    as bookings_count
from public.settlements st;

-- ----------------------------------------------------------------------------
-- التقييمات + رقم الحجز واسم مقدّم الخدمة
-- ----------------------------------------------------------------------------
create or replace view public.v_admin_reviews
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
create or replace view public.v_admin_subscription_plans
with (security_invoker = true) as
select
  sp.*,
  (select count(*) from public.provider_subscriptions s
    where s.plan_id = sp.id and s.status = 'active')::integer as subscribers_count
from public.subscription_plans sp;

-- ----------------------------------------------------------------------------
-- الحملات الترويجية + اسم القسم المستهدف
-- ----------------------------------------------------------------------------
create or replace view public.v_admin_promotions
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
