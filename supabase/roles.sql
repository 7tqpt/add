-- ============================================================================
--  صلاحيات المسؤولين بالمجال
--
--  الاستخدام: Supabase ← SQL Editor ← New query ← الصق ← Run. آمن للتكرار.
--  يُنفَّذ بعد install.sql و support.sql.
--
--  المشكلة التي يحلّها:
--    الأدوار كانت ثلاثة: مالك، ومسؤول، ومطّلع. و«مسؤول» يعني كل شيء — من يوثّق
--    مقدّمي الخدمة يستطيع أيضاً أن يستردّ المدفوعات ويغيّر إعدادات المنصة. فمن
--    أراد أن يوظّف موظفاً لخدمة العملاء وحدها لم يكن أمامه إلا أن يمنحه المفاتيح
--    كلها أو يمنعه من الدخول.
--
--    فصار لكل دور مستوىً في كل مجال: لا شيء، أو قراءة، أو كتابة.
--
--  المصفوفة في جدول لا في شيفرة الدوال: المالك يراها ويعدّلها، والتغيير يسري
--  على السياسات فوراً لأن الدوال تقرأ منه.
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- الأدوار الجديدة
-- ----------------------------------------------------------------------------
alter table public.admins drop constraint if exists admins_role_check;
alter table public.admins add constraint admins_role_check
  check (role in ('owner', 'manager', 'operations', 'finance',
                  'support', 'moderator', 'viewer', 'admin'));

-- الدور القديم `admin` كان يعني «كل شيء عدا إدارة المسؤولين» — وهذا هو
-- `manager` بالضبط. يُرحَّل بدل أن يُترك اسماً غامضاً بجانب الأسماء الجديدة.
update public.admins set role = 'manager' where role = 'admin';

alter table public.admins drop constraint admins_role_check;
alter table public.admins add constraint admins_role_check
  check (role in ('owner', 'manager', 'operations', 'finance',
                  'support', 'moderator', 'viewer'));

-- ----------------------------------------------------------------------------
-- المجالات ومصفوفة الصلاحيات
-- ----------------------------------------------------------------------------
create table if not exists public.admin_areas (
  role  text not null check (role in ('owner', 'manager', 'operations',
                                      'finance', 'support', 'moderator', 'viewer')),
  area  text not null check (area in ('bookings', 'directory', 'catalog',
                                      'finance', 'trust', 'support',
                                      'ops', 'settings', 'admins')),
  level text not null check (level in ('none', 'read', 'write')),
  primary key (role, area)
);

alter table public.admin_areas enable row level security;

-- يقرؤها كل مسؤول ليعرف حدوده، ولا يعدّلها إلا المالك — ومن يعدّل المصفوفة
-- يمنح نفسه ما شاء، فهي صلاحية المالك وحده بالضرورة.
drop policy if exists admin_areas_read on public.admin_areas;
create policy admin_areas_read on public.admin_areas
  for select to authenticated using (public.is_admin());

drop policy if exists admin_areas_owner_writes on public.admin_areas;
create policy admin_areas_owner_writes on public.admin_areas
  for all to authenticated using (public.is_owner()) with check (public.is_owner());

grant select on public.admin_areas to authenticated;
grant insert, update, delete on public.admin_areas to authenticated;

-- ----------------------------------------------------------------------------
-- المصفوفة
--
--  owner      المالك — كل شيء، وهو وحده يدير المسؤولين
--  manager    مدير — كل شيء عدا إدارة المسؤولين
--  operations مساعد المدير — المدفوعات والأقسام وتوثيق مقدّمي الخدمة
--  finance    محاسب — المال وحده؛ لا يوثّق أحداً ولا يغيّر الأقسام
--  support    خدمة العملاء — التذاكر كتابةً، وما يلزمها قراءةً. لا يمسّ المال
--  moderator  مشرف محتوى — التقييمات والنزاعات
--  viewer     مطّلع — قراءة فقط، ولا يرى المال
-- ----------------------------------------------------------------------------
insert into public.admin_areas (role, area, level) values
  -- المالك
  ('owner','bookings','write'),  ('owner','directory','write'),
  ('owner','catalog','write'),   ('owner','finance','write'),
  ('owner','trust','write'),     ('owner','support','write'),
  ('owner','ops','write'),       ('owner','settings','write'),
  ('owner','admins','write'),

  -- مدير: كالمالك، إلا أنه لا يضيف مسؤولين ولا يرقّيهم
  ('manager','bookings','write'),('manager','directory','write'),
  ('manager','catalog','write'), ('manager','finance','write'),
  ('manager','trust','write'),   ('manager','support','write'),
  ('manager','ops','write'),     ('manager','settings','write'),
  ('manager','admins','none'),

  -- مساعد المدير: ما طلبه صاحب المنصة — المدفوعات والأقسام والتوثيق
  ('operations','bookings','write'),  ('operations','directory','write'),
  ('operations','catalog','write'),   ('operations','finance','write'),
  ('operations','trust','read'),      ('operations','support','read'),
  ('operations','ops','write'),       ('operations','settings','read'),
  ('operations','admins','none'),

  -- محاسب: المال وحده. يقرأ الحجوزات لأن كل مبلغ معلّق بحجز
  ('finance','bookings','read'),      ('finance','directory','read'),
  ('finance','catalog','none'),       ('finance','finance','write'),
  ('finance','trust','read'),         ('finance','support','none'),
  ('finance','ops','none'),           ('finance','settings','none'),
  ('finance','admins','none'),

  -- خدمة العملاء: التذاكر كتابةً، والحجوزات والعملاء قراءةً ليجيب عن أسئلتهم.
  -- المال ممنوع: من يردّ على «خُصم مبلغي» يحتاج أن يرى الحجز لا أن يستردّ مبلغاً.
  ('support','bookings','read'),      ('support','directory','read'),
  ('support','catalog','read'),       ('support','finance','none'),
  ('support','trust','read'),         ('support','support','write'),
  ('support','ops','none'),           ('support','settings','none'),
  ('support','admins','none'),

  -- مشرف محتوى: التقييمات والنزاعات
  ('moderator','bookings','read'),    ('moderator','directory','read'),
  ('moderator','catalog','read'),     ('moderator','finance','none'),
  ('moderator','trust','write'),      ('moderator','support','read'),
  ('moderator','ops','none'),         ('moderator','settings','none'),
  ('moderator','admins','none'),

  -- مطّلع: يقرأ ولا يكتب، والمال محجوب عنه
  ('viewer','bookings','read'),       ('viewer','directory','read'),
  ('viewer','catalog','read'),        ('viewer','finance','none'),
  ('viewer','trust','read'),          ('viewer','support','read'),
  ('viewer','ops','read'),            ('viewer','settings','read'),
  ('viewer','admins','none')
on conflict (role, area) do update set level = excluded.level;

-- ----------------------------------------------------------------------------
-- الدوال
--
--  security definer لأنها تقرأ admins و admin_areas، وقراءتهما تمرّ بسياسات
--  تستدعي هذه الدوال نفسها — فيصير الفحص دائرياً بلا هذا.
-- ----------------------------------------------------------------------------
create or replace function public.area_level(p_area text)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select x.level from public.admin_areas x
      where x.role = public.admin_role() and x.area = p_area),
    'none')
$$;

create or replace function public.can_read_area(p_area text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.area_level(p_area) in ('read', 'write')
$$;

-- coalesce ليست تجميلاً: مقارنةٌ طرفها NULL تُنتج NULL لا false، وشرطٌ قيمته
-- NULL لا يتحقّق — لكن `not <NULL>` لا يتحقّق أيضاً، فيمرّ من كان يجب منعه في
-- السياسات المكتوبة بالنفي. area_level تُرجع 'none' لا NULL لهذا السبب، وهذه
-- طبقة ثانية.
create or replace function public.can_write_area(p_area text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.area_level(p_area) = 'write', false)
$$;

-- ----------------------------------------------------------------------------
-- استبدال السياسات — الكتابة صارت بالمجال لا بـ can_write() العامة
-- ----------------------------------------------------------------------------

-- الكتالوج: المحافظات والأقسام وسياسات الإلغاء والخدمات
drop policy if exists governorates_admin_write on public.governorates;
create policy governorates_admin_write on public.governorates
  for all to authenticated
  using (public.can_write_area('catalog')) with check (public.can_write_area('catalog'));

drop policy if exists categories_admin_write on public.service_categories;
create policy categories_admin_write on public.service_categories
  for all to authenticated
  using (public.can_write_area('catalog')) with check (public.can_write_area('catalog'));

drop policy if exists policies_admin_write on public.cancellation_policies;
create policy policies_admin_write on public.cancellation_policies
  for all to authenticated
  using (public.can_write_area('catalog')) with check (public.can_write_area('catalog'));

-- الدليل: العملاء ومقدّمو الخدمة ومستنداتهم
drop policy if exists users_admin_write on public.app_users;
create policy users_admin_write on public.app_users
  for all to authenticated
  using (public.can_write_area('directory')) with check (public.can_write_area('directory'));

drop policy if exists providers_admin_write on public.service_providers;
create policy providers_admin_write on public.service_providers
  for all to authenticated
  using (public.can_write_area('directory')) with check (public.can_write_area('directory'));

drop policy if exists documents_admin_write on public.provider_documents;
create policy documents_admin_write on public.provider_documents
  for all to authenticated
  using (public.can_write_area('directory')) with check (public.can_write_area('directory'));

-- الحجوزات
drop policy if exists bookings_admin_write on public.bookings;
create policy bookings_admin_write on public.bookings
  for all to authenticated
  using (public.can_write_area('bookings')) with check (public.can_write_area('bookings'));

-- ----------------------------------------------------------------------------
-- المال: الكتابة والقراءة معاً
--
--  القراءة تُقيَّد هنا خلافاً لبقية المجالات، ولهذا سبب: مبالغ المنصة وعمولاتها
--  ومستحقات الشركاء ليست معلومات تشغيلية يحتاجها من يردّ على تذكرة. المجال
--  الوحيد الذي «لا شيء» فيه تعني الحجب لا منع التعديل.
-- ----------------------------------------------------------------------------
drop policy if exists payments_parties_read on public.payments;
create policy payments_parties_read on public.payments
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.can_read_area('finance')
  );

drop policy if exists payments_admin_write on public.payments;
create policy payments_admin_write on public.payments
  for all to authenticated
  using (public.can_write_area('finance')) with check (public.can_write_area('finance'));

drop policy if exists invoices_parties_read on public.invoices;
create policy invoices_parties_read on public.invoices
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.can_read_area('finance')
  );

drop policy if exists invoices_admin_write on public.invoices;
create policy invoices_admin_write on public.invoices
  for all to authenticated
  using (public.can_write_area('finance')) with check (public.can_write_area('finance'));

drop policy if exists settlements_owner_read on public.settlements;
create policy settlements_owner_read on public.settlements
  for select to authenticated
  using (provider_id = public.current_provider() or public.can_read_area('finance'));

drop policy if exists settlements_admin_write on public.settlements;
create policy settlements_admin_write on public.settlements
  for all to authenticated
  using (public.can_write_area('finance')) with check (public.can_write_area('finance'));

drop policy if exists settlement_items_admin_write on public.settlement_items;
create policy settlement_items_admin_write on public.settlement_items
  for all to authenticated
  using (public.can_write_area('finance')) with check (public.can_write_area('finance'));

drop policy if exists subscriptions_admin_write on public.provider_subscriptions;
create policy subscriptions_admin_write on public.provider_subscriptions
  for all to authenticated
  using (public.can_write_area('finance')) with check (public.can_write_area('finance'));

drop policy if exists plans_admin_write on public.subscription_plans;
create policy plans_admin_write on public.subscription_plans
  for all to authenticated
  using (public.can_write_area('finance')) with check (public.can_write_area('finance'));

drop policy if exists promotions_admin_write on public.promotions;
create policy promotions_admin_write on public.promotions
  for all to authenticated
  using (public.can_write_area('finance')) with check (public.can_write_area('finance'));

-- الثقة: التقييمات والنزاعات
drop policy if exists reviews_admin_write on public.reviews;
create policy reviews_admin_write on public.reviews
  for all to authenticated
  using (public.can_write_area('trust')) with check (public.can_write_area('trust'));

drop policy if exists disputes_admin_write on public.disputes;
create policy disputes_admin_write on public.disputes
  for all to authenticated
  using (public.can_write_area('trust')) with check (public.can_write_area('trust'));

-- خدمة العملاء
drop policy if exists "admin updates tickets" on public.support_tickets;
create policy "admin updates tickets" on public.support_tickets
  for update to authenticated
  using (public.can_write_area('support')) with check (public.can_write_area('support'));

drop policy if exists "admin writes ticket messages" on public.support_messages;
create policy "admin writes ticket messages" on public.support_messages
  for insert to authenticated
  with check (public.can_write_area('support') and author = 'admin');

-- التشغيل: الإشعارات والإصدارات والمقاييس
drop policy if exists versions_admin_write on public.app_versions;
create policy versions_admin_write on public.app_versions
  for all to authenticated
  using (public.can_write_area('ops')) with check (public.can_write_area('ops'));

drop policy if exists push_admin_only on public.push_notifications;
create policy push_admin_only on public.push_notifications
  for all to authenticated
  using (public.can_read_area('ops')) with check (public.can_write_area('ops'));

drop policy if exists metrics_admin_only on public.daily_metrics;
create policy metrics_admin_only on public.daily_metrics
  for all to authenticated
  using (public.is_admin()) with check (public.can_write_area('ops'));

drop policy if exists notifications_admin_write on public.notifications;
create policy notifications_admin_write on public.notifications
  for all to authenticated
  using (public.can_write_area('ops')) with check (public.can_write_area('ops'));

-- الإعدادات
drop policy if exists settings_admin_write on public.app_settings;
create policy settings_admin_write on public.app_settings
  for all to authenticated
  using (public.can_write_area('settings')) with check (public.can_write_area('settings'));

-- ----------------------------------------------------------------------------
-- إدارة المسؤولين
--
--  المالك وحده يضيف ويحذف ويرقّي. وهذا ليس تفضيلاً: من يعدّل صفّاً في `admins`
--  يستطيع أن يرفع نفسه إلى المالك، فأي دور آخر يُمنح هذا الحق يصير مالكاً فعلياً.
-- ----------------------------------------------------------------------------
drop policy if exists admins_owner_writes on public.admins;
create policy admins_owner_writes on public.admins
  for all to authenticated
  using (public.can_write_area('admins')) with check (public.can_write_area('admins'));

-- سجل العمليات: يُلحق به كل من يملك كتابةً في أي مجال، فالسجل أثرُ فعلٍ وقع.
drop policy if exists audit_log_append on public.audit_log;
create policy audit_log_append on public.audit_log
  for insert to authenticated with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- تفريغ سجل العمليات — للمالك وحده
--
--  السجل مُلحَقٌ فقط بتصميمه: لا سياسة `update` ولا `delete` عليه إطلاقاً، حتى
--  لا يمحو مسؤولٌ أثر ما فعله. وهذا يبقى كما هو — لم تُضَف سياسة حذف، لأن
--  إضافتها تفتح الحذف الانتقائي لأي جلسةٍ تحمل الدور، فيُمحى صفٌّ بعينه ولا
--  يُدرى.
--
--  والتفريغ هنا دالةٌ `security definer` تتجاوز السياسات بنفسها بعد أن تتحقّق
--  من المالك — فالقدرة محصورةٌ في هذا الباب وحده، لا مبثوثةٌ في الجدول.
--
--  **والتفريغ يُسجَّل.** يُحذف كل شيء ثم يُكتب صفٌّ يقول: من فرّغ، ومتى، وكم
--  صفّاً أزال. فلا يخرج السجل من التفريغ فارغاً بل شاهداً على أنه فُرِّغ —
--  وإلا صار أداةً لإخفاء ما جرى بدل إثباته، وهو نقيض غرضه.
-- ----------------------------------------------------------------------------
create or replace function public.api_clear_audit_log()
returns integer
language plpgsql security definer set search_path = public as $$
declare
  removed integer;
  mail text := lower(coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), ''));
begin
  if not public.is_owner() then
    raise exception 'تفريغ سجل العمليات للمالك وحده';
  end if;

  delete from public.audit_log;
  get diagnostics removed = row_count;

  insert into public.audit_log (actor_email, action, entity, entity_label, details)
  values (mail, 'audit.purge', 'audit_log', 'سجل العمليات',
          jsonb_build_object('removed', removed));

  return removed;
end;
$$;

revoke all on function public.api_clear_audit_log() from public;
grant execute on function public.api_clear_audit_log() to authenticated;

-- can_write() القديمة تبقى لأن السياسات التي لم تُستبدل تستعملها، لكنها صارت
-- تعني «يكتب في أي مجال» — أوسع من أن يُبنى عليها قرار، فلا تُستعمل في جديد.
create or replace function public.can_write()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    exists (select 1 from public.admin_areas x
             where x.role = public.admin_role() and x.level = 'write'),
    false)
$$;

commit;

-- ============================================================================
--  التحقق — المتوقّع: ٧ أدوار × ٩ مجالات = ٦٣ صفاً
-- ============================================================================
select 'الأدوار' as البند, count(distinct role)::text as القيمة from public.admin_areas
union all
select 'المجالات', count(distinct area)::text from public.admin_areas
union all
select 'صفوف المصفوفة', count(*)::text from public.admin_areas
union all
select 'المسؤولون الحاليون', count(*)::text from public.admins;
