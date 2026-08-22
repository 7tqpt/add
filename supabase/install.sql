-- ============================================================================
--  التثبيت الكامل — منصة حجوزات وتجهيز الأعراس
--
--  الاستخدام:
--    افتح مشروعك في Supabase ← SQL Editor ← New query، ثم الصق هذا الملف
--    كاملاً واضغط Run. الملف يجمع schema.sql و policies.sql و api.sql بهذا
--    الترتيب تحديداً: الجداول قبل سياساتها، والسياسات قبل الدوال التي تعمل
--    من خلفها.
--
--  التشغيل مرة ثانية آمن: كل عبارة إما `if not exists` أو `create or replace`.
--
--  بعده — وليس قبله — نفّذ supabase/bootstrap_admin.sql لتعيين أول مسؤول،
--  و supabase/seed.sql إن أردت بيانات تجريبية للتصفّح.
-- ============================================================================

-- ############################################################################
-- ##  schema.sql — الجداول والقيود والدوال المساعدة
-- ############################################################################

-- ============================================================================
--  منصة حجوزات وتجهيز الأعراس اليمنية — مخطط قاعدة البيانات
--
--  مبني على «وثيقة تحليل المشروع — النسخة النهائية».
--  شغّل هذا الملف في: Supabase Dashboard ← SQL Editor ← New query
--  ثم شغّل supabase/seed.sql إن أردت بيانات تجريبية للبدء.
--
--  ترتيب الملف يتبع اعتماد الجداول على بعضها، فلا تعِد ترتيب الأقسام.
-- ============================================================================

-- gen_random_uuid() مدمجة في Postgres 13 فما فوق، فلا حاجة إلى pgcrypto.

-- ============================================================================
--  1. المسؤولون والصلاحيات
-- ============================================================================

-- ----------------------------------------------------------------------------
-- مسؤولو لوحة التحكم وأدوارهم — كل سياسات RLS أدناه تعتمد على هذا الجدول
--
--   owner  : كل شيء، بما فيه إدارة المسؤولين أنفسهم
--   admin  : كل شيء عدا إدارة المسؤولين
--   viewer : قراءة فقط
-- ----------------------------------------------------------------------------
create table if not exists public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  email      text not null default '',
  role       text not null default 'viewer' check (role in ('owner', 'admin', 'viewer')),
  created_at timestamptz not null default now()
);

-- security definer: تتجاوز RLS على جدول admins نفسه، وإلا لصار الفحص دائرياً.
create or replace function public.admin_role()
returns text language sql stable security definer set search_path = public as $$
  select a.role from public.admins a where a.user_id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_role() is not null;
$$;

-- من يملك حق التعديل. viewer يقرأ فقط.
--
-- coalesce ضرورية لا تجميلية: admin_role() تُرجع NULL لغير المسؤول، و
-- `NULL in (...)` تُنتج NULL لا false. فتصير `not can_write()` مساويةً لـ NULL،
-- وشرطٌ قيمته NULL لا يتحقّق — فيمرّ من كان يجب منعه.
create or replace function public.can_write()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.admin_role() in ('owner', 'admin'), false);
$$;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.admin_role() = 'owner', false);
$$;

-- ============================================================================
--  2. المرجعيات: المحافظات وأقسام الخدمات
-- ============================================================================

-- ----------------------------------------------------------------------------
-- المحافظات اليمنية — تُدار من اللوحة لأن التغطية تتوسّع تدريجياً
-- ----------------------------------------------------------------------------
create table if not exists public.governorates (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  sort_order integer not null default 0,
  is_active  boolean not null default true
);

-- ----------------------------------------------------------------------------
-- أقسام الخدمات — «إدارة الأقسام والخدمات» في لوحة الإدارة
--
-- `custom_fields` يحمل الحقول الإضافية الخاصة بالقسم (سعة القاعة، عدد الفرقة،
-- نوع السيارة…) كمصفوفة JSON، فتُضاف حقول جديدة دون تعديل المخطط:
--   [{ "key": "capacity", "label": "السعة", "type": "number", "required": true }]
-- ----------------------------------------------------------------------------
create table if not exists public.service_categories (
  id            uuid primary key default gen_random_uuid(),
  name          text not null unique,
  slug          text not null unique,
  description   text not null default '',
  icon          text not null default '',
  sort_order    integer not null default 0,
  is_active     boolean not null default true,
  custom_fields jsonb not null default '[]'::jsonb,
  created_at    timestamptz not null default now()
);

create index if not exists service_categories_order_idx
  on public.service_categories (sort_order) where is_active;

-- ----------------------------------------------------------------------------
-- سياسات الإلغاء والاسترداد
--
-- `rules` سلّم زمني تنازلي: كلما اقترب الموعد قلّت النسبة المستردة.
--   [{ "hours_before": 168, "refund_percent": 100 },
--    { "hours_before": 72,  "refund_percent": 50  },
--    { "hours_before": 0,   "refund_percent": 0   }]
-- الوثيقة تنص على أن هذه السياسات والنسب تحت تحكّم الإدارة الكامل.
-- ----------------------------------------------------------------------------
create table if not exists public.cancellation_policies (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text not null default '',
  rules       jsonb not null default '[]'::jsonb,
  is_default  boolean not null default false,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- سياسة افتراضية واحدة على الأكثر
create unique index if not exists cancellation_policies_one_default_idx
  on public.cancellation_policies ((true)) where is_default;

-- ============================================================================
--  3. المستخدمون ومقدّمو الخدمة
-- ============================================================================

-- ----------------------------------------------------------------------------
-- مستخدمو التطبيق
--
-- كل الحسابات تبدأ «مستخدم عادي» حسب الوثيقة؛ صلاحية تقديم الخدمة تُمنح لاحقاً
-- عبر جدول service_providers، لا بحقل هنا.
-- ----------------------------------------------------------------------------
create table if not exists public.app_users (
  id             uuid primary key default gen_random_uuid(),
  -- ربط الحساب بمصادقة Supabase. يبقى فارغاً للبيانات التجريبية، ويُملأ عند
  -- تسجيل مستخدم حقيقي من التطبيق. كل سياسات العميل تمرّ عبره.
  auth_user_id   uuid unique references auth.users (id) on delete cascade,
  full_name      text not null,
  email          text not null unique,
  phone          text not null default '',
  platform       text not null default 'android' check (platform in ('ios', 'android')),
  governorate_id uuid references public.governorates (id) on delete set null,
  governorate    text not null default '',
  status         text not null default 'pending'
                 check (status in ('active', 'suspended', 'pending')),
  app_version    text not null default '',
  sessions_count integer not null default 0 check (sessions_count >= 0),
  created_at     timestamptz not null default now(),
  last_seen_at   timestamptz
);

create index if not exists app_users_created_at_idx on public.app_users (created_at desc);
create index if not exists app_users_status_idx     on public.app_users (status);

-- ----------------------------------------------------------------------------
-- جلسات المستخدم وأجهزته — تغذّي شاشة تفاصيل المستخدم
-- ----------------------------------------------------------------------------
create table if not exists public.user_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.app_users (id) on delete cascade,
  started_at       timestamptz not null default now(),
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  platform         text not null check (platform in ('ios', 'android')),
  app_version      text not null default '',
  governorate      text not null default ''
);

create index if not exists user_sessions_user_idx
  on public.user_sessions (user_id, started_at desc);

create table if not exists public.user_devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.app_users (id) on delete cascade,
  model        text not null,
  os_version   text not null default '',
  platform     text not null check (platform in ('ios', 'android')),
  push_enabled boolean not null default true,
  last_used_at timestamptz not null default now()
);

create index if not exists user_devices_user_idx on public.user_devices (user_id);

-- ----------------------------------------------------------------------------
-- مقدّمو الخدمة
--
-- حالات الحساب كما نصّت عليها الوثيقة:
--   pending  : قيد المراجعة — رُفعت المستندات وتنتظر الإدارة
--   verified : موثّق — يستقبل الحجوزات ويعرض خدماته
--   rejected : مرفوض — لم تستوفَ الشروط، ويمكن إعادة التقديم بعد التعديل
--   suspended: موقوف — أُوقف مؤقتاً أو دائماً لسبب مخالفي
--
-- «مستخدم عادي» ليس حالة هنا: هو ببساطة مستخدم بلا صف في هذا الجدول.
-- ----------------------------------------------------------------------------
create table if not exists public.service_providers (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid references public.app_users (id) on delete set null,
  full_name          text not null,
  business_name      text not null default '',
  email              text not null unique,
  phone              text not null default '',
  bio                text not null default '',
  -- شعارُ المزوّد أو صورةُ محلّه — مسارٌ داخل سلّة `avatars`.
  -- مسارٌ لا رابطٌ كامل: السلّة عامّة فيُشتقّ الرابط عند العرض، ولو خُزّن
  -- الرابط لتعطّل يوم تتغيّر السلّة أو نطاقُها.
  logo_path          text not null default '',
  governorate_id     uuid references public.governorates (id) on delete set null,
  governorate        text not null default '',
  coverage_areas     text[] not null default '{}',
  status             text not null default 'pending'
                     check (status in ('pending', 'verified', 'rejected', 'suspended')),
  is_featured        boolean not null default false,
  rating             numeric(2, 1) not null default 0 check (rating between 0 and 5),
  reviews_count      integer not null default 0 check (reviews_count >= 0),
  completed_bookings integer not null default 0 check (completed_bookings >= 0),
  total_earnings     numeric(14, 2) not null default 0 check (total_earnings >= 0),
  -- عمولة خاصة تتجاوز نسبة المنصة العامة، أو NULL لاستخدام العامة
  commission_percent numeric(5, 2) check (commission_percent between 0 and 100),
  rejection_reason   text not null default '',
  applied_at         timestamptz not null default now(),
  verified_at        timestamptz,
  created_at         timestamptz not null default now(),
  constraint verified_needs_timestamp
    check (status <> 'verified' or verified_at is not null)
);

create index if not exists service_providers_status_idx
  on public.service_providers (status, applied_at desc);
create index if not exists service_providers_governorate_idx
  on public.service_providers (governorate_id);

-- مقدّم الخدمة قد يقدّم أكثر من نوع خدمة في وقت واحد — علاقة متعدّد لمتعدّد
create table if not exists public.provider_categories (
  provider_id uuid not null references public.service_providers (id) on delete cascade,
  category_id uuid not null references public.service_categories (id) on delete cascade,
  primary key (provider_id, category_id)
);

-- ----------------------------------------------------------------------------
-- مستندات التوثيق
-- ----------------------------------------------------------------------------
create table if not exists public.provider_documents (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.service_providers (id) on delete cascade,
  type        text not null
              check (type in ('id_card', 'commercial_register', 'certificate', 'insurance', 'work_samples')),
  file_name   text not null,
  file_url    text not null default '',
  status      text not null default 'pending'
              check (status in ('pending', 'approved', 'rejected')),
  note        text not null default '',
  uploaded_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index if not exists provider_documents_provider_idx
  on public.provider_documents (provider_id);

-- ----------------------------------------------------------------------------
-- الخدمات المعروضة
--
-- السعر قد يكون ثابتاً أو نطاقاً (`price_to`), و`deposit_percent` هو نسبة
-- العربون التي تحدّد كم يدفع العميل مقدماً — الوثيقة تجعلها «حسب سياسة الخدمة».
-- ----------------------------------------------------------------------------
create table if not exists public.provider_services (
  id                  uuid primary key default gen_random_uuid(),
  provider_id         uuid not null references public.service_providers (id) on delete cascade,
  category_id         uuid not null references public.service_categories (id) on delete restrict,
  title               text not null,
  description         text not null default '',
  price               numeric(12, 2) not null check (price >= 0),
  price_to            numeric(12, 2) check (price_to >= price),
  unit                text not null default 'للحجز',
  deposit_percent     integer not null default 30 check (deposit_percent between 0 and 100),
  duration_minutes    integer not null default 240 check (duration_minutes > 0),
  cancellation_policy_id uuid references public.cancellation_policies (id) on delete set null,
  -- قيم الحقول المخصّصة للقسم: { "capacity": 400, "has_parking": true }
  attributes          jsonb not null default '{}'::jsonb,
  images              text[] not null default '{}',
  is_active           boolean not null default true,
  created_at          timestamptz not null default now()
);

create index if not exists provider_services_provider_idx
  on public.provider_services (provider_id) where is_active;
create index if not exists provider_services_category_idx
  on public.provider_services (category_id) where is_active;

-- ----------------------------------------------------------------------------
-- تقويم مقدّم الخدمة — الأيام المحجوزة أو المغلقة
-- ----------------------------------------------------------------------------
create table if not exists public.provider_availability (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.service_providers (id) on delete cascade,
  day         date not null,
  is_blocked  boolean not null default true,
  note        text not null default '',
  unique (provider_id, day)
);

-- ============================================================================
--  4. خطة العرس والحجوزات
-- ============================================================================

-- ----------------------------------------------------------------------------
-- خطة العرس (Wedding Planner)
--
-- تجمع خدمات عدة تحت خطة واحدة بتاريخ وميزانية، وتعرض إجمالي التكلفة والمدفوع
-- والمتبقي. المجاميع تُحسب من الحجوزات المرتبطة، ولا تُخزَّن هنا حتى لا تتباعد.
-- ----------------------------------------------------------------------------
create table if not exists public.wedding_plans (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.app_users (id) on delete cascade,
  title          text not null default 'خطة العرس',
  wedding_date   date not null,
  governorate_id uuid references public.governorates (id) on delete set null,
  governorate    text not null default '',
  guests_count   integer not null default 0 check (guests_count >= 0),
  budget         numeric(14, 2) not null default 0 check (budget >= 0),
  status         text not null default 'planning'
                 check (status in ('planning', 'confirmed', 'completed', 'cancelled')),
  notes          text not null default '',
  created_at     timestamptz not null default now()
);

create index if not exists wedding_plans_user_idx on public.wedding_plans (user_id, wedding_date);
create index if not exists wedding_plans_date_idx on public.wedding_plans (wedding_date);

-- ----------------------------------------------------------------------------
-- الحجوزات
--
-- المسار حسب الوثيقة: العميل يختار مقدّم الخدمة والخدمة والموعد، يراجع السعر
-- والشروط، يدفع العربون أو المبلغ كاملاً، فيُنشأ الحجز برقم فريد وينتظر قبول
-- مقدّم الخدمة أو رفضه.
--
--   pending_provider : مدفوع وينتظر قبول مقدّم الخدمة
--   confirmed        : قَبِل مقدّم الخدمة والموعد مثبّت
--   completed        : نُفّذت الخدمة في الموعد
--   rejected         : رفضه مقدّم الخدمة — يُسترد المدفوع كاملاً
--   cancelled        : ألغاه العميل — الاسترداد حسب سياسة الإلغاء
--   expired          : انقضى الموعد دون قبول
--
-- سياسة الإلغاء تُنسخ في الحجز وقت إنشائه (`cancellation_rules`) لأن تعديل
-- السياسة لاحقاً يجب ألا يغيّر شروط حجز قائم.
-- ----------------------------------------------------------------------------
create table if not exists public.bookings (
  id                 uuid primary key default gen_random_uuid(),
  reference          text not null unique,
  user_id            uuid references public.app_users (id) on delete set null,
  user_name          text not null default '',
  provider_id        uuid references public.service_providers (id) on delete set null,
  provider_name      text not null default '',
  service_id         uuid references public.provider_services (id) on delete set null,
  service_title      text not null default '',
  category_id        uuid references public.service_categories (id) on delete set null,
  category_name      text not null default '',
  plan_id            uuid references public.wedding_plans (id) on delete set null,

  event_date         date not null,
  event_time         time,
  governorate        text not null default '',
  address            text not null default '',
  guests_count       integer not null default 0 check (guests_count >= 0),
  notes              text not null default '',

  status             text not null default 'pending_provider'
                     check (status in ('pending_provider', 'confirmed', 'completed',
                                       'rejected', 'cancelled', 'expired')),

  total_price        numeric(12, 2) not null check (total_price >= 0),
  deposit_amount     numeric(12, 2) not null default 0 check (deposit_amount >= 0),
  paid_amount        numeric(12, 2) not null default 0 check (paid_amount >= 0),
  refunded_amount    numeric(12, 2) not null default 0 check (refunded_amount >= 0),
  commission_percent numeric(5, 2) not null default 0 check (commission_percent between 0 and 100),
  commission_amount  numeric(12, 2) not null default 0 check (commission_amount >= 0),
  cancellation_rules jsonb not null default '[]'::jsonb,

  rejection_reason   text not null default '',
  cancel_reason      text not null default '',
  created_at         timestamptz not null default now(),
  confirmed_at       timestamptz,
  completed_at       timestamptz,
  cancelled_at       timestamptz,

  constraint deposit_within_total   check (deposit_amount <= total_price),
  constraint paid_within_total      check (paid_amount <= total_price),
  constraint refund_within_paid     check (refunded_amount <= paid_amount),
  constraint commission_within_total check (commission_amount <= total_price),
  constraint confirmed_needs_timestamp
    check (status <> 'confirmed' or confirmed_at is not null),
  -- كل حالة إغلاق تحمل وقتها: الإلغاء والاعتذار وانقضاء المهلة سواء في ذلك،
  -- ولا يحمل الوقت حجزٌ ما زال قائماً.
  constraint closed_needs_timestamp
    check ((status in ('cancelled', 'rejected', 'expired')) = (cancelled_at is not null))
);

create index if not exists bookings_status_idx     on public.bookings (status, created_at desc);
create index if not exists bookings_user_idx       on public.bookings (user_id, created_at desc);
create index if not exists bookings_provider_idx   on public.bookings (provider_id, created_at desc);
create index if not exists bookings_plan_idx       on public.bookings (plan_id);
create index if not exists bookings_event_date_idx on public.bookings (event_date);

-- ============================================================================
--  5. المالية: المدفوعات والتسويات
-- ============================================================================

-- ----------------------------------------------------------------------------
-- سجل المدفوعات — دفتر المال الوحيد في المنصة
--
--   deposit      : عربون حجز
--   balance      : سداد المتبقي من حجز
--   full         : سداد كامل مرة واحدة
--   subscription : اشتراك مقدّم خدمة
--   promotion    : باقة ظهور مميز أو إعلان
--   refund       : استرداد للعميل (المبلغ موجب، والاتجاه يحدّده النوع)
--
-- `platform_share` ما تحتفظ به المنصة، و`net_amount` المستحق لمقدّم الخدمة.
-- ----------------------------------------------------------------------------
create table if not exists public.payments (
  id             uuid primary key default gen_random_uuid(),
  reference      text not null unique,
  user_id        uuid references public.app_users (id) on delete set null,
  user_name      text not null default '',
  provider_id    uuid references public.service_providers (id) on delete set null,
  provider_name  text not null default '',
  booking_id     uuid references public.bookings (id) on delete set null,
  booking_reference text not null default '',
  kind           text not null default 'deposit'
                 check (kind in ('deposit', 'balance', 'full', 'subscription', 'promotion', 'refund')),
  description    text not null default '',
  amount         numeric(12, 2) not null check (amount >= 0),
  platform_share numeric(12, 2) not null default 0 check (platform_share >= 0),
  net_amount     numeric(12, 2) not null default 0 check (net_amount >= 0),
  method         text not null default 'wallet'
                 check (method in ('card', 'wallet', 'jawali', 'cash_wallet', 'bank_transfer', 'kuraimi')),
  status         text not null default 'pending'
                 check (status in ('paid', 'pending', 'failed', 'refunded')),
  gateway_ref    text not null default '',
  created_at     timestamptz not null default now(),
  refunded_at    timestamptz,
  constraint split_within_amount check (platform_share + net_amount <= amount),
  constraint refund_needs_timestamp
    check ((status = 'refunded') = (refunded_at is not null))
);

create index if not exists payments_created_at_idx on public.payments (created_at desc);
create index if not exists payments_booking_idx    on public.payments (booking_id, created_at);
create index if not exists payments_provider_idx   on public.payments (provider_id, created_at desc);
create index if not exists payments_status_idx     on public.payments (status, created_at desc);

-- ----------------------------------------------------------------------------
-- تسوية مستحقات الشركاء
--
-- دفعة واحدة تُصرف لمقدّم الخدمة عن فترة، وبنودها تربطها بالحجوزات التي
-- كوّنتها — فيبقى لكل ريال أثر يعود إلى حجز بعينه.
-- ----------------------------------------------------------------------------
create table if not exists public.settlements (
  id           uuid primary key default gen_random_uuid(),
  reference    text not null unique,
  provider_id  uuid not null references public.service_providers (id) on delete cascade,
  provider_name text not null default '',
  period_start date not null,
  period_end   date not null,
  gross_amount numeric(14, 2) not null default 0 check (gross_amount >= 0),
  commission_amount numeric(14, 2) not null default 0 check (commission_amount >= 0),
  net_amount   numeric(14, 2) not null default 0 check (net_amount >= 0),
  status       text not null default 'pending'
               check (status in ('pending', 'approved', 'paid', 'on_hold')),
  method       text not null default '',
  note         text not null default '',
  created_at   timestamptz not null default now(),
  paid_at      timestamptz,
  constraint period_in_order check (period_end >= period_start),
  constraint settlement_split check (commission_amount + net_amount <= gross_amount),
  constraint paid_needs_timestamp check ((status = 'paid') = (paid_at is not null))
);

create index if not exists settlements_provider_idx on public.settlements (provider_id, period_end desc);
create index if not exists settlements_status_idx   on public.settlements (status, created_at desc);

create table if not exists public.settlement_items (
  settlement_id uuid not null references public.settlements (id) on delete cascade,
  booking_id    uuid not null references public.bookings (id) on delete restrict,
  gross_amount  numeric(12, 2) not null default 0 check (gross_amount >= 0),
  commission_amount numeric(12, 2) not null default 0 check (commission_amount >= 0),
  net_amount    numeric(12, 2) not null default 0 check (net_amount >= 0),
  primary key (settlement_id, booking_id)
);

-- حجز واحد لا يدخل في تسويتين
create unique index if not exists settlement_items_booking_once_idx
  on public.settlement_items (booking_id);

-- ============================================================================
--  6. الثقة: التقييمات والنزاعات والمحادثات
-- ============================================================================

-- ----------------------------------------------------------------------------
-- التقييمات — تُقبل بعد إتمام الحجز فقط، كما نصّت الوثيقة
-- ----------------------------------------------------------------------------
create table if not exists public.reviews (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references public.bookings (id) on delete cascade,
  user_id      uuid references public.app_users (id) on delete set null,
  user_name    text not null default '',
  provider_id  uuid not null references public.service_providers (id) on delete cascade,
  rating       integer not null check (rating between 1 and 5),
  comment      text not null default '',
  status       text not null default 'published'
               check (status in ('published', 'hidden', 'flagged')),
  hidden_reason text not null default '',
  created_at   timestamptz not null default now(),
  -- تقييم واحد لكل حجز
  unique (booking_id)
);

create index if not exists reviews_provider_idx on public.reviews (provider_id, created_at desc);
create index if not exists reviews_status_idx   on public.reviews (status) where status <> 'published';

-- ----------------------------------------------------------------------------
-- النزاعات والشكاوى بين العميل ومقدّم الخدمة
-- ----------------------------------------------------------------------------
create table if not exists public.disputes (
  id            uuid primary key default gen_random_uuid(),
  reference     text not null unique,
  booking_id    uuid references public.bookings (id) on delete set null,
  booking_reference text not null default '',
  opened_by     text not null check (opened_by in ('customer', 'provider')),
  user_id       uuid references public.app_users (id) on delete set null,
  user_name     text not null default '',
  provider_id   uuid references public.service_providers (id) on delete set null,
  provider_name text not null default '',
  subject       text not null,
  description   text not null default '',
  category      text not null default 'other'
                check (category in ('no_show', 'quality', 'payment', 'cancellation', 'behaviour', 'other')),
  status        text not null default 'open'
                check (status in ('open', 'investigating', 'resolved', 'closed')),
  resolution    text not null default '',
  -- المبلغ الذي قرّرت الإدارة إعادته للعميل عند الحسم، إن وُجد
  refund_amount numeric(12, 2) not null default 0 check (refund_amount >= 0),
  resolved_by   text not null default '',
  created_at    timestamptz not null default now(),
  resolved_at   timestamptz,
  constraint resolved_needs_timestamp
    check ((status in ('resolved', 'closed')) = (resolved_at is not null))
);

create index if not exists disputes_status_idx on public.disputes (status, created_at desc);

create table if not exists public.dispute_messages (
  id           uuid primary key default gen_random_uuid(),
  dispute_id   uuid not null references public.disputes (id) on delete cascade,
  author       text not null check (author in ('customer', 'provider', 'admin')),
  author_name  text not null default '',
  body         text not null,
  created_at   timestamptz not null default now()
);

create index if not exists dispute_messages_dispute_idx
  on public.dispute_messages (dispute_id, created_at);

-- ----------------------------------------------------------------------------
-- المحادثات المباشرة بين العميل ومقدّم الخدمة
--
-- تُخزَّن لتظهر للإدارة عند نظر نزاع؛ ليست شاشة تشغيلية يومية.
-- ----------------------------------------------------------------------------
create table if not exists public.conversations (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid references public.bookings (id) on delete set null,
  user_id       uuid references public.app_users (id) on delete set null,
  user_name     text not null default '',
  provider_id   uuid references public.service_providers (id) on delete set null,
  provider_name text not null default '',
  last_message_at timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index if not exists conversations_recent_idx on public.conversations (last_message_at desc);

create table if not exists public.conversation_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender          text not null check (sender in ('customer', 'provider')),
  body            text not null,
  created_at      timestamptz not null default now()
);

create index if not exists conversation_messages_idx
  on public.conversation_messages (conversation_id, created_at);

-- ============================================================================
--  7. الدخل: الاشتراكات والباقات الترويجية
-- ============================================================================

create table if not exists public.subscription_plans (
  id             uuid primary key default gen_random_uuid(),
  name           text not null unique,
  description    text not null default '',
  price          numeric(12, 2) not null check (price >= 0),
  duration_days  integer not null default 30 check (duration_days > 0),
  -- ما تمنحه الباقة: عدد الخدمات، أولوية الظهور، شارة… كقائمة نصية
  perks          text[] not null default '{}',
  is_active      boolean not null default true,
  created_at     timestamptz not null default now()
);

create table if not exists public.provider_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.service_providers (id) on delete cascade,
  plan_id     uuid not null references public.subscription_plans (id) on delete restrict,
  plan_name   text not null default '',
  amount      numeric(12, 2) not null default 0 check (amount >= 0),
  status      text not null default 'active'
              check (status in ('active', 'expired', 'cancelled')),
  starts_at   timestamptz not null default now(),
  ends_at     timestamptz not null,
  created_at  timestamptz not null default now(),
  constraint subscription_period check (ends_at > starts_at)
);

create index if not exists provider_subscriptions_provider_idx
  on public.provider_subscriptions (provider_id, ends_at desc);

-- ----------------------------------------------------------------------------
-- المساحات الإعلانية والظهور المميز
-- ----------------------------------------------------------------------------
create table if not exists public.promotions (
  id            uuid primary key default gen_random_uuid(),
  provider_id   uuid references public.service_providers (id) on delete cascade,
  provider_name text not null default '',
  kind          text not null default 'featured'
                check (kind in ('featured', 'banner', 'category_top')),
  placement     text not null default 'home',
  category_id   uuid references public.service_categories (id) on delete set null,
  image_url     text not null default '',
  amount        numeric(12, 2) not null default 0 check (amount >= 0),
  status        text not null default 'scheduled'
                check (status in ('scheduled', 'active', 'ended', 'cancelled')),
  impressions   integer not null default 0 check (impressions >= 0),
  clicks        integer not null default 0 check (clicks >= 0),
  starts_at     timestamptz not null,
  ends_at       timestamptz not null,
  created_at    timestamptz not null default now(),
  constraint promotion_period check (ends_at > starts_at),
  constraint clicks_within_impressions check (clicks <= impressions)
);

create index if not exists promotions_active_idx on public.promotions (status, ends_at desc);

-- ============================================================================
--  8. التشغيل: الإشعارات والمقاييس والإصدارات والسجل والإعدادات
-- ============================================================================

create table if not exists public.push_notifications (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  body         text not null,
  audience     text not null default 'all'
               check (audience in ('all', 'customers', 'providers', 'ios', 'android', 'active', 'inactive')),
  status       text not null default 'draft'
               check (status in ('sent', 'scheduled', 'draft', 'failed')),
  scheduled_at timestamptz,
  sent_at      timestamptz,
  recipients   integer not null default 0 check (recipients >= 0),
  opened       integer not null default 0 check (opened >= 0),
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint scheduled_needs_time
    check (status <> 'scheduled' or scheduled_at is not null)
);

create index if not exists push_notifications_created_at_idx
  on public.push_notifications (created_at desc);

create table if not exists public.daily_metrics (
  day            date not null,
  platform       text not null check (platform in ('ios', 'android')),
  installs       integer not null default 0 check (installs >= 0),
  sessions       integer not null default 0 check (sessions >= 0),
  active_users   integer not null default 0 check (active_users >= 0),
  bookings_count integer not null default 0 check (bookings_count >= 0),
  revenue        numeric(14, 2) not null default 0 check (revenue >= 0),
  primary key (day, platform)
);

create index if not exists daily_metrics_day_idx on public.daily_metrics (day desc);

create table if not exists public.app_versions (
  id              uuid primary key default gen_random_uuid(),
  platform        text not null check (platform in ('ios', 'android')),
  version         text not null,
  build           integer not null,
  released_at     timestamptz not null default now(),
  force_update    boolean not null default false,
  rollout_percent integer not null default 100 check (rollout_percent between 0 and 100),
  notes           text not null default '',
  unique (platform, build)
);

-- ----------------------------------------------------------------------------
-- المفضّلة — «إضافة الخدمات المفضلة للقائمة الخاصة» في تطبيق العميل
-- ----------------------------------------------------------------------------
create table if not exists public.favourites (
  user_id    uuid not null references public.app_users (id) on delete cascade,
  service_id uuid not null references public.provider_services (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, service_id)
);

create index if not exists favourites_user_idx on public.favourites (user_id, created_at desc);

-- ----------------------------------------------------------------------------
-- صندوق الإشعارات داخل التطبيق
--
-- يختلف عن push_notifications: ذاك حملات تُرسل من اللوحة، وهذا إشعارات موجّهة
-- لحساب بعينه (قُبل حجزك، وصل الدفع، ردّ عليك مقدّم الخدمة).
-- ----------------------------------------------------------------------------
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.app_users (id) on delete cascade,
  provider_id uuid references public.service_providers (id) on delete cascade,
  kind        text not null default 'general'
              check (kind in ('booking', 'payment', 'message', 'review', 'dispute',
                              'account', 'reminder', 'general')),
  title       text not null,
  body        text not null default '',
  -- معرّفات تكفي التطبيق ليفتح الشاشة الصحيحة: { "booking_id": "…" }
  data        jsonb not null default '{}'::jsonb,
  read_at     timestamptz,
  created_at  timestamptz not null default now(),
  -- الإشعار موجَّه إلى طرف واحد، لا إلى الاثنين ولا إلى لا أحد
  constraint notification_has_one_owner
    check ((user_id is not null) <> (provider_id is not null))
);

create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc) where user_id is not null;
create index if not exists notifications_provider_idx
  on public.notifications (provider_id, created_at desc) where provider_id is not null;

-- ----------------------------------------------------------------------------
-- الفواتير — «متابعة الحجوزات والمدفوعات وإصدار الفواتير» في تطبيق العميل
-- ----------------------------------------------------------------------------
create table if not exists public.invoices (
  id          uuid primary key default gen_random_uuid(),
  number      text not null unique,
  booking_id  uuid not null references public.bookings (id) on delete cascade,
  user_id     uuid references public.app_users (id) on delete set null,
  provider_id uuid references public.service_providers (id) on delete set null,
  subtotal    numeric(12, 2) not null default 0 check (subtotal >= 0),
  commission  numeric(12, 2) not null default 0 check (commission >= 0),
  total       numeric(12, 2) not null default 0 check (total >= 0),
  currency    text not null default 'YER',
  status      text not null default 'issued'
              check (status in ('issued', 'paid', 'void')),
  pdf_url     text not null default '',
  issued_at   timestamptz not null default now()
);

create index if not exists invoices_booking_idx on public.invoices (booking_id);
create index if not exists invoices_user_idx    on public.invoices (user_id, issued_at desc);

-- ----------------------------------------------------------------------------
-- سجل عمليات المسؤولين — للإلحاق فقط
-- ----------------------------------------------------------------------------
create table if not exists public.audit_log (
  id           uuid primary key default gen_random_uuid(),
  actor_email  text not null default '',
  action       text not null,
  entity       text not null,
  entity_id    text not null default '',
  entity_label text not null default '',
  details      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index if not exists audit_log_created_at_idx on public.audit_log (created_at desc);
create index if not exists audit_log_entity_idx     on public.audit_log (entity, created_at desc);

-- ----------------------------------------------------------------------------
-- إعدادات المنصة — صف واحد فقط (id = 1)
-- ----------------------------------------------------------------------------
create table if not exists public.app_settings (
  id                    smallint primary key default 1 check (id = 1),
  maintenance_mode      boolean not null default false,
  maintenance_message   text not null default '',
  allow_signups         boolean not null default true,
  allow_provider_signups boolean not null default true,
  -- نسبة عمولة المنصة العامة؛ يمكن تجاوزها لمقدّم خدمة بعينه
  commission_percent    numeric(5, 2) not null default 10 check (commission_percent between 0 and 100),
  default_deposit_percent integer not null default 30
                        check (default_deposit_percent between 0 and 100),
  currency              text not null default 'YER',
  min_ios_version       text not null default '1.0.0',
  min_android_version   text not null default '1.0.0',
  support_email         text not null default '',
  support_phone         text not null default '',
  default_locale        text not null default 'ar',
  updated_at            timestamptz not null default now()
);

insert into public.app_settings (id) values (1) on conflict (id) do nothing;

-- ============================================================================
--  9. تفعيل RLS على كل الجداول
--
--  التفعيل هنا والسياسات في policies.sql. جدول مفعَّل بلا سياسة = ممنوع على
--  الجميع، وهذا هو الوضع الآمن لو نُسي تشغيل ملف السياسات.
-- ============================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'admins', 'governorates', 'service_categories', 'cancellation_policies',
    'app_users', 'user_sessions', 'user_devices',
    'service_providers', 'provider_categories', 'provider_documents',
    'provider_services', 'provider_availability',
    'wedding_plans', 'bookings', 'favourites',
    'payments', 'invoices', 'settlements', 'settlement_items',
    'reviews', 'disputes', 'dispute_messages',
    'conversations', 'conversation_messages',
    'subscription_plans', 'provider_subscriptions', 'promotions',
    'notifications', 'push_notifications', 'daily_metrics', 'app_versions',
    'audit_log', 'app_settings'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ============================================================================
--  10. دوال مساعدة
-- ============================================================================

-- ----------------------------------------------------------------------------
-- هوية المتصل الحالي
--
-- التطبيقان يتصلان بقاعدة البيانات مباشرة، فكل سياسة تسأل: من هذا؟ هذه الدوال
-- هي الجواب، و security definer يجعلها تقرأ الجداول متجاوزةً RLS حتى لا يصير
-- الفحص دائرياً.
-- ----------------------------------------------------------------------------
create or replace function public.current_app_user()
returns uuid language sql stable security definer set search_path = public as $$
  select u.id from public.app_users u where u.auth_user_id = auth.uid();
$$;

create or replace function public.current_provider()
returns uuid language sql stable security definer set search_path = public as $$
  select p.id from public.service_providers p
  where p.user_id = public.current_app_user();
$$;

create or replace function public.is_verified_provider()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.service_providers p
    where p.user_id = public.current_app_user() and p.status = 'verified'
  );
$$;

-- ----------------------------------------------------------------------------
-- المبلغ المستردّ لحجز لو أُلغي الآن، حسب السلّم المنسوخ في الحجز نفسه.
-- تُستعمل من اللوحة لعرض «كم سيُسترد» قبل تأكيد الإلغاء.
-- ----------------------------------------------------------------------------
create or replace function public.refundable_amount(p_booking_id uuid)
returns numeric
language plpgsql
stable
as $$
declare
  b public.bookings%rowtype;
  hours_left numeric;
  rule jsonb;
  percent numeric := 0;
begin
  select * into b from public.bookings where id = p_booking_id;
  if not found then
    return 0;
  end if;

  hours_left := extract(epoch from (b.event_date::timestamptz - now())) / 3600;

  -- السلّم مرتّب تنازلياً؛ أول عتبة يتجاوزها الوقت المتبقي هي المطبَّقة.
  for rule in select * from jsonb_array_elements(b.cancellation_rules)
  loop
    if hours_left >= (rule ->> 'hours_before')::numeric then
      percent := (rule ->> 'refund_percent')::numeric;
      exit;
    end if;
  end loop;

  return round(b.paid_amount * percent / 100, 2);
end;
$$;

-- ============================================================================
--  بعد التشغيل: أنشئ مستخدماً من Authentication ← Users، ثم امنحه الدور:
--
--    insert into public.admins (user_id, email, role)
--    select id, email, 'owner' from auth.users where email = 'you@example.com';
-- ============================================================================


-- ############################################################################
-- ##  policies.sql — سياسات RLS وصلاحيات الأدوار
-- ############################################################################

-- ============================================================================
--  سياسات الوصول (RLS) — شغّلها بعد schema.sql
--
--  التطبيقان يتصلان بقاعدة البيانات مباشرة عبر Supabase، فهذا الملف هو جدار
--  الحماية الفعلي: هو ما يمنع عميلاً من رؤية حجز عميل آخر، ومقدّم خدمة من
--  تعديل خدمات غيره. لا تعتمد على تصفية في التطبيق — التطبيق يمكن تعديله.
--
--  أربعة أطراف:
--    anon          الزائر قبل تسجيل الدخول — يرى المعروض للعامة فقط
--    العميل        يرى ويعدّل بياناته هو
--    مقدّم الخدمة   يدير خدماته وحجوزاته هو
--    المسؤول       يرى كل شيء؛ والكتابة لمن دوره owner أو admin
--
--  لوحة التحكم للمسؤولين وحدهم — لا يصلها عميل ولا مقدّم خدمة.
-- ============================================================================

-- ============================================================================
--  1. المرجعيات — يقرؤها الجميع حتى قبل تسجيل الدخول
--     (التطبيق يعرض الأقسام والمحافظات في أول شاشة)
-- ============================================================================

drop policy if exists governorates_public_read on public.governorates;
create policy governorates_public_read on public.governorates
  for select to anon, authenticated using (is_active or public.is_admin());

drop policy if exists governorates_admin_write on public.governorates;
create policy governorates_admin_write on public.governorates
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists categories_public_read on public.service_categories;
create policy categories_public_read on public.service_categories
  for select to anon, authenticated using (is_active or public.is_admin());

drop policy if exists categories_admin_write on public.service_categories;
create policy categories_admin_write on public.service_categories
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- سياسة الإلغاء يجب أن يراها العميل قبل الحجز، كما تنص الوثيقة
drop policy if exists policies_public_read on public.cancellation_policies;
create policy policies_public_read on public.cancellation_policies
  for select to anon, authenticated using (is_active or public.is_admin());

drop policy if exists policies_admin_write on public.cancellation_policies;
create policy policies_admin_write on public.cancellation_policies
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists plans_public_read on public.subscription_plans;
create policy plans_public_read on public.subscription_plans
  for select to anon, authenticated using (is_active or public.is_admin());

drop policy if exists plans_admin_write on public.subscription_plans;
create policy plans_admin_write on public.subscription_plans
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- الإعدادات: التطبيق يحتاج وضع الصيانة وأدنى إصدار مدعوم قبل الدخول
drop policy if exists settings_public_read on public.app_settings;
create policy settings_public_read on public.app_settings
  for select to anon, authenticated using (true);

drop policy if exists settings_admin_write on public.app_settings;
create policy settings_admin_write on public.app_settings
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists versions_public_read on public.app_versions;
create policy versions_public_read on public.app_versions
  for select to anon, authenticated using (true);

drop policy if exists versions_admin_write on public.app_versions;
create policy versions_admin_write on public.app_versions
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- ============================================================================
--  2. الحسابات
-- ============================================================================

-- العميل يرى ويعدّل حسابه هو. لا يرى حسابات غيره إطلاقاً.
drop policy if exists users_self_read on public.app_users;
create policy users_self_read on public.app_users
  for select to authenticated
  using (auth_user_id = auth.uid() or public.is_admin());

drop policy if exists users_self_update on public.app_users;
create policy users_self_update on public.app_users
  for update to authenticated
  using (auth_user_id = auth.uid())
  -- الحالة والصلاحيات ليست للمستخدم؛ تُغيَّر من اللوحة أو من دوال الـ API
  with check (auth_user_id = auth.uid());

drop policy if exists users_self_insert on public.app_users;
create policy users_self_insert on public.app_users
  for insert to authenticated with check (auth_user_id = auth.uid());

drop policy if exists users_admin_write on public.app_users;
create policy users_admin_write on public.app_users
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- الجلسات والأجهزة: يكتبها التطبيق لحساب صاحبها، ويقرؤها هو والمسؤول.
drop policy if exists sessions_owner on public.user_sessions;
create policy sessions_owner on public.user_sessions
  for select to authenticated
  using (user_id = public.current_app_user() or public.is_admin());

drop policy if exists sessions_owner_insert on public.user_sessions;
create policy sessions_owner_insert on public.user_sessions
  for insert to authenticated with check (user_id = public.current_app_user());

drop policy if exists devices_owner on public.user_devices;
create policy devices_owner on public.user_devices
  for all to authenticated
  using (user_id = public.current_app_user() or public.is_admin())
  with check (user_id = public.current_app_user() or public.can_write());

-- ============================================================================
--  3. مقدّمو الخدمة
-- ============================================================================

-- الموثّقون فقط ظاهرون للعامة؛ ومقدّم الخدمة يرى ملفه مهما كانت حالته.
drop policy if exists providers_public_read on public.service_providers;
create policy providers_public_read on public.service_providers
  for select to anon, authenticated
  using (
    status = 'verified'
    or user_id = public.current_app_user()
    or public.is_admin()
  );

-- يعدّل ملفه هو. تغيير الحالة إلى «موثّق» ليس بيده — انظر شرط with check.
drop policy if exists providers_self_update on public.service_providers;
create policy providers_self_update on public.service_providers
  for update to authenticated
  using (user_id = public.current_app_user())
  with check (user_id = public.current_app_user());

drop policy if exists providers_admin_write on public.service_providers;
create policy providers_admin_write on public.service_providers
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- منع مقدّم الخدمة من ترقية نفسه: أي تغيير على الحالة أو التوثيق أو العمولة
-- يجب أن يأتي من الإدارة. مشغّل لأن RLS لا يقارن الصف قبل التعديل وبعده.
create or replace function public.guard_provider_self_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- المسؤول، أو دالة API داخلية رفعت العلم أدناه (تحديث العدّادات والتقييم بعد
  -- إتمام حجز). العلم محلّي المعاملة، فلا يتسرّب إلى طلب آخر.
  if public.is_admin()
     or coalesce(current_setting('app.internal', true), '') = 'on' then
    return new;
  end if;

  if new.status is distinct from old.status
     or new.verified_at is distinct from old.verified_at
     or new.is_featured is distinct from old.is_featured
     or new.commission_percent is distinct from old.commission_percent
     or new.rating is distinct from old.rating
     or new.reviews_count is distinct from old.reviews_count
     or new.total_earnings is distinct from old.total_earnings then
    raise exception 'هذه الحقول تُعدَّل من إدارة المنصة فقط';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_provider_self_update on public.service_providers;
create trigger guard_provider_self_update
  before update on public.service_providers
  for each row execute function public.guard_provider_self_update();

-- أقسام مقدّم الخدمة: ظاهرة للعامة، يديرها صاحبها.
drop policy if exists provider_categories_read on public.provider_categories;
create policy provider_categories_read on public.provider_categories
  for select to anon, authenticated using (true);

drop policy if exists provider_categories_owner on public.provider_categories;
create policy provider_categories_owner on public.provider_categories
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write())
  with check (provider_id = public.current_provider() or public.can_write());

-- المستندات: خاصة تماماً — صاحبها والإدارة فقط. لا تُعرض للعامة أبداً.
drop policy if exists documents_owner_read on public.provider_documents;
create policy documents_owner_read on public.provider_documents
  for select to authenticated
  using (provider_id = public.current_provider() or public.is_admin());

drop policy if exists documents_owner_upload on public.provider_documents;
create policy documents_owner_upload on public.provider_documents
  for insert to authenticated with check (provider_id = public.current_provider());

-- المراجعة (قبول/رفض) للإدارة وحدها
drop policy if exists documents_admin_write on public.provider_documents;
create policy documents_admin_write on public.provider_documents
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- الخدمات: يراها الجميع إن كانت مفعّلة ومقدّمها موثّق.
drop policy if exists services_public_read on public.provider_services;
create policy services_public_read on public.provider_services
  for select to anon, authenticated
  using (
    (is_active and exists (
      select 1 from public.service_providers p
      where p.id = provider_id and p.status = 'verified'
    ))
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists services_owner_write on public.provider_services;
create policy services_owner_write on public.provider_services
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write())
  with check (provider_id = public.current_provider() or public.can_write());

-- التقويم: يقرؤه الجميع (العميل يحتاج معرفة الأيام المشغولة)، ويديره صاحبه.
drop policy if exists availability_public_read on public.provider_availability;
create policy availability_public_read on public.provider_availability
  for select to anon, authenticated using (true);

drop policy if exists availability_owner_write on public.provider_availability;
create policy availability_owner_write on public.provider_availability
  for all to authenticated
  using (provider_id = public.current_provider() or public.can_write())
  with check (provider_id = public.current_provider() or public.can_write());

-- ============================================================================
--  4. خطط الأعراس والحجوزات
-- ============================================================================

-- خطة العرس خاصة بصاحبها وحده. مقدّم الخدمة لا يراها.
drop policy if exists plans_owner on public.wedding_plans;
create policy plans_owner on public.wedding_plans
  for all to authenticated
  using (user_id = public.current_app_user() or public.is_admin())
  with check (user_id = public.current_app_user() or public.can_write());

-- الحجز يراه طرفاه فقط: العميل صاحبه، ومقدّم الخدمة المعني.
drop policy if exists bookings_parties_read on public.bookings;
create policy bookings_parties_read on public.bookings
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

-- الإنشاء والانتقالات تمرّ عبر دوال الـ API (api.sql) لا بكتابة مباشرة، لأن
-- السعر والعمولة والعربون تُحسب في الخادم — لا يملي العميل ما سيدفعه.
drop policy if exists bookings_admin_write on public.bookings;
create policy bookings_admin_write on public.bookings
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists favourites_owner on public.favourites;
create policy favourites_owner on public.favourites
  for all to authenticated
  using (user_id = public.current_app_user() or public.is_admin())
  with check (user_id = public.current_app_user());

-- ============================================================================
--  5. المالية
-- ============================================================================

-- المدفوعات: يقرؤها طرفاها. لا يكتبها أحد من التطبيق — تُنشأ من دوال الـ API
-- ومن خطّاف بوابة الدفع بمفتاح الخدمة.
drop policy if exists payments_parties_read on public.payments;
create policy payments_parties_read on public.payments
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists payments_admin_write on public.payments;
create policy payments_admin_write on public.payments
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists invoices_parties_read on public.invoices;
create policy invoices_parties_read on public.invoices
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists invoices_admin_write on public.invoices;
create policy invoices_admin_write on public.invoices
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- التسويات: مقدّم الخدمة يرى مستحقاته، ولا يعدّلها.
drop policy if exists settlements_owner_read on public.settlements;
create policy settlements_owner_read on public.settlements
  for select to authenticated
  using (provider_id = public.current_provider() or public.is_admin());

drop policy if exists settlements_admin_write on public.settlements;
create policy settlements_admin_write on public.settlements
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists settlement_items_owner_read on public.settlement_items;
create policy settlement_items_owner_read on public.settlement_items
  for select to authenticated
  using (
    exists (
      select 1 from public.settlements s
      where s.id = settlement_id
        and (s.provider_id = public.current_provider() or public.is_admin())
    )
  );

drop policy if exists settlement_items_admin_write on public.settlement_items;
create policy settlement_items_admin_write on public.settlement_items
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- ============================================================================
--  6. الثقة: التقييمات والنزاعات والمحادثات
-- ============================================================================

-- التقييمات المنشورة يراها الجميع — هي أساس ثقة العميل بمقدّم الخدمة.
-- المخفية والمُبلَّغ عنها يراها صاحبها والإدارة فقط.
drop policy if exists reviews_public_read on public.reviews;
create policy reviews_public_read on public.reviews
  for select to anon, authenticated
  using (
    status = 'published'
    or user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

-- الكتابة عبر api_submit_review فقط: هي التي تتحقّق أن الحجز نُفّذ فعلاً.
drop policy if exists reviews_admin_write on public.reviews;
create policy reviews_admin_write on public.reviews
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists disputes_parties_read on public.disputes;
create policy disputes_parties_read on public.disputes
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists disputes_admin_write on public.disputes;
create policy disputes_admin_write on public.disputes
  for all to authenticated using (public.can_write()) with check (public.can_write());

drop policy if exists dispute_messages_parties on public.dispute_messages;
create policy dispute_messages_parties on public.dispute_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.disputes d
      where d.id = dispute_id
        and (d.user_id = public.current_app_user()
             or d.provider_id = public.current_provider()
             or public.is_admin())
    )
  );

drop policy if exists dispute_messages_write on public.dispute_messages;
create policy dispute_messages_write on public.dispute_messages
  for insert to authenticated
  with check (
    public.can_write()
    or exists (
      select 1 from public.disputes d
      where d.id = dispute_id
        and ((d.user_id = public.current_app_user() and author = 'customer')
             or (d.provider_id = public.current_provider() and author = 'provider'))
    )
  );

-- المحادثات: طرفاها فقط. الإدارة تقرأ عند النظر في نزاع، ولا تكتب فيها.
drop policy if exists conversations_parties on public.conversations;
create policy conversations_parties on public.conversations
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists conversations_parties_write on public.conversations;
create policy conversations_parties_write on public.conversations
  for insert to authenticated
  with check (user_id = public.current_app_user() or provider_id = public.current_provider());

drop policy if exists conversation_messages_parties on public.conversation_messages;
create policy conversation_messages_parties on public.conversation_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.user_id = public.current_app_user()
             or c.provider_id = public.current_provider()
             or public.is_admin())
    )
  );

drop policy if exists conversation_messages_send on public.conversation_messages;
create policy conversation_messages_send on public.conversation_messages
  for insert to authenticated
  with check (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and ((c.user_id = public.current_app_user() and sender = 'customer')
             or (c.provider_id = public.current_provider() and sender = 'provider'))
    )
  );

-- ============================================================================
--  7. الاشتراكات والإعلانات والإشعارات
-- ============================================================================

drop policy if exists subscriptions_owner_read on public.provider_subscriptions;
create policy subscriptions_owner_read on public.provider_subscriptions
  for select to authenticated
  using (provider_id = public.current_provider() or public.is_admin());

drop policy if exists subscriptions_admin_write on public.provider_subscriptions;
create policy subscriptions_admin_write on public.provider_subscriptions
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- الإعلانات النشطة يراها التطبيق ليعرضها؛ وصاحبها يرى إحصاءاته.
drop policy if exists promotions_public_read on public.promotions;
create policy promotions_public_read on public.promotions
  for select to anon, authenticated
  using (
    (status = 'active' and now() between starts_at and ends_at)
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists promotions_admin_write on public.promotions;
create policy promotions_admin_write on public.promotions
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- صندوق الإشعارات: صاحبه فقط، وله أن يعلّمها مقروءة.
drop policy if exists notifications_owner_read on public.notifications;
create policy notifications_owner_read on public.notifications
  for select to authenticated
  using (
    user_id = public.current_app_user()
    or provider_id = public.current_provider()
    or public.is_admin()
  );

drop policy if exists notifications_owner_update on public.notifications;
create policy notifications_owner_update on public.notifications
  for update to authenticated
  using (user_id = public.current_app_user() or provider_id = public.current_provider())
  with check (user_id = public.current_app_user() or provider_id = public.current_provider());

drop policy if exists notifications_admin_write on public.notifications;
create policy notifications_admin_write on public.notifications
  for all to authenticated using (public.can_write()) with check (public.can_write());

-- ============================================================================
--  8. ما لا يخرج من اللوحة إطلاقاً
-- ============================================================================

-- حملات الإشعارات، المقاييس، وسجل المسؤولين: لا يراها مستخدم ولا مقدّم خدمة.
drop policy if exists push_admin_only on public.push_notifications;
create policy push_admin_only on public.push_notifications
  for all to authenticated using (public.is_admin()) with check (public.can_write());

drop policy if exists metrics_admin_only on public.daily_metrics;
create policy metrics_admin_only on public.daily_metrics
  for all to authenticated using (public.is_admin()) with check (public.can_write());

-- جدول المسؤولين: يقرأه كل مسؤول، ولا يعدّله إلا المالك.
drop policy if exists admins_read on public.admins;
create policy admins_read on public.admins
  for select to authenticated using (public.is_admin());

drop policy if exists admins_owner_writes on public.admins;
create policy admins_owner_writes on public.admins
  for all to authenticated using (public.is_owner()) with check (public.is_owner());

-- سجل العمليات: للإلحاق فقط — لا سياسة update ولا delete إطلاقاً، حتى لا يمحو
-- مسؤول أثر ما فعله.
drop policy if exists audit_log_read on public.audit_log;
create policy audit_log_read on public.audit_log
  for select to authenticated using (public.is_admin());

drop policy if exists audit_log_append on public.audit_log;
create policy audit_log_append on public.audit_log
  for insert to authenticated with check (public.can_write());

-- ============================================================================
--  9. صلاحيات الجداول
--
--  RLS تقرّر أي صفوف يراها المتصل، لكن GRANT هي التي تسمح له بلمس الجدول أصلاً.
--  Supabase يمنح هذه تلقائياً عادةً، لكن تركها ضمنية يجعل المشروع يعمل عندك
--  ويفشل عند غيرك — فتُكتب صراحةً.
-- ============================================================================

grant usage on schema public to anon, authenticated;

grant select on all tables in schema public to anon, authenticated;
grant insert, update, delete on all tables in schema public to authenticated;

-- الجداول الجديدة لاحقاً ترث نفس المنح
alter default privileges in schema public
  grant select on tables to anon, authenticated;
alter default privileges in schema public
  grant insert, update, delete on tables to authenticated;


-- ############################################################################
-- ##  api.sql — طرق العرض ودوال RPC التي يستدعيها التطبيقان
-- ############################################################################

-- ============================================================================
--  الـ API — شغّلها بعد schema.sql و policies.sql
--
--  كل ما لا يجوز أن يمليه التطبيق يعيش هنا: السعر، العربون، العمولة، وشروط
--  الانتقال بين الحالات. التطبيق يطلب «احجز هذه الخدمة»، والخادم هو من يقرر
--  كم تُكلّف ومتى يجوز الحجز.
--
--  تُستدعى من التطبيقين هكذا:
--    const { data, error } = await supabase.rpc('api_create_booking', { … })
--
--  كل الدوال security definer لأنها تكتب في جداول تمنع RLS الكتابة المباشرة
--  فيها؛ ولذلك تبدأ كل واحدة بالتحقق من هوية المتصل بنفسها.
-- ============================================================================

-- ============================================================================
--  طرق العرض العامة — ما يقرؤه التطبيق للبحث والاستكشاف
-- ============================================================================

-- ----------------------------------------------------------------------------
-- الخدمات المعروضة، مضمومة إلى مقدّمها وقسمها.
-- security_invoker: تُطبَّق سياسات RLS على المتصل لا على منشئ الطريقة، فلا
-- تتسرّب خدمة غير مفعّلة أو مقدّم غير موثّق.
-- ----------------------------------------------------------------------------
create or replace view public.v_services
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
  pol.name  as cancellation_policy_name,
  pol.rules as cancellation_rules
from public.provider_services s
join public.service_providers p on p.id = s.provider_id
join public.service_categories c on c.id = s.category_id
left join public.cancellation_policies pol on pol.id = s.cancellation_policy_id;

-- ----------------------------------------------------------------------------
-- مقدّمو الخدمة الظاهرون، مع أقسامهم مجمّعة.
-- ----------------------------------------------------------------------------
create or replace view public.v_providers
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

-- ----------------------------------------------------------------------------
-- ملخّص خطة العرس: الإجمالي والمدفوع والمتبقي، محسوبة من الحجوزات لا مخزّنة.
-- الوثيقة تطلب هذه اللوحة بالضبط في خاصية «خطة العرس».
-- ----------------------------------------------------------------------------
create or replace view public.v_plan_summary
with (security_invoker = true) as
select
  pl.id as plan_id,
  pl.user_id,
  pl.title,
  pl.wedding_date,
  pl.governorate,
  pl.guests_count,
  pl.budget,
  pl.status,
  count(b.id) filter (where b.status <> 'cancelled')          as services_count,
  coalesce(sum(b.total_price)    filter (where b.status not in ('cancelled','rejected')), 0) as total_cost,
  coalesce(sum(b.paid_amount)    filter (where b.status not in ('cancelled','rejected')), 0) as paid_amount,
  coalesce(sum(b.total_price - b.paid_amount)
           filter (where b.status not in ('cancelled','rejected')), 0) as remaining_amount
from public.wedding_plans pl
left join public.bookings b on b.plan_id = pl.id
group by pl.id;

-- ============================================================================
--  دوال العميل
-- ============================================================================

-- ----------------------------------------------------------------------------
-- api_register_profile — يربط حساب المصادقة بملف مستخدم في المنصة.
-- يُستدعى مرة واحدة بعد أول تسجيل دخول.
-- ----------------------------------------------------------------------------
create or replace function public.api_register_profile(
  p_full_name   text,
  p_phone       text default '',
  p_governorate text default '',
  p_platform    text default 'android'
)
returns public.app_users
language plpgsql security definer set search_path = public as $$
declare
  existing public.app_users;
  gov_id uuid;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select * into existing from public.app_users where auth_user_id = auth.uid();
  if found then
    return existing;
  end if;

  select id into gov_id from public.governorates where name = p_governorate;

  insert into public.app_users
    (auth_user_id, full_name, email, phone, platform, governorate_id, governorate, status)
  values
    (auth.uid(), p_full_name,
     coalesce((select email from auth.users where id = auth.uid()), ''),
     p_phone, p_platform, gov_id, p_governorate, 'active')
  returning * into existing;

  return existing;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_create_booking — قلب المنصة.
--
-- العميل يمرّر الخدمة والموعد فقط. الخادم يجلب السعر ونسبة العربون والعمولة
-- وسياسة الإلغاء، ويتحقّق أن مقدّم الخدمة موثّق وأن يومه غير مغلق، ثم ينشئ
-- الحجز ودفعة العربون المعلّقة.
--
-- `p_pay_full` يختار بين دفع العربون أو المبلغ كاملاً، كما تنص الوثيقة.
-- ----------------------------------------------------------------------------
create or replace function public.api_create_booking(
  p_service_id   uuid,
  p_event_date   date,
  p_event_time   time default null,
  p_plan_id      uuid default null,
  p_guests_count integer default 0,
  p_address      text default '',
  p_notes        text default '',
  p_pay_full     boolean default false
)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  me         uuid := public.current_app_user();
  me_row     public.app_users;
  svc        record;
  settings   public.app_settings;
  booking    public.bookings;
  due        numeric(12,2);
  commission numeric(5,2);
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if p_event_date < current_date then
    raise exception 'لا يمكن الحجز في تاريخ مضى';
  end if;

  select u.* into me_row from public.app_users u where u.id = me;
  if me_row.status <> 'active' then
    raise exception 'حسابك غير مفعّل حالياً';
  end if;

  select s.id, s.title, s.price, s.deposit_percent, s.category_id, s.provider_id,
         s.is_active, c.name as category_name, p.business_name, p.status as provider_status,
         p.commission_percent as provider_commission,
         coalesce(pol.rules, '[]'::jsonb) as rules
  into svc
  from public.provider_services s
  join public.service_providers p on p.id = s.provider_id
  join public.service_categories c on c.id = s.category_id
  left join public.cancellation_policies pol on pol.id = s.cancellation_policy_id
  where s.id = p_service_id;

  if not found then
    raise exception 'الخدمة غير موجودة';
  end if;
  if not svc.is_active or svc.provider_status <> 'verified' then
    raise exception 'هذه الخدمة غير متاحة للحجز حالياً';
  end if;

  -- التقويم: يوم أغلقه مقدّم الخدمة لا يُحجز
  if exists (
    select 1 from public.provider_availability a
    where a.provider_id = svc.provider_id and a.day = p_event_date and a.is_blocked
  ) then
    raise exception 'مقدّم الخدمة غير متاح في هذا التاريخ';
  end if;

  -- خطة العرس إن مُرّرت يجب أن تكون خطة العميل نفسه
  if p_plan_id is not null and not exists (
    select 1 from public.wedding_plans w where w.id = p_plan_id and w.user_id = me
  ) then
    raise exception 'خطة العرس غير موجودة';
  end if;

  select * into settings from public.app_settings where id = 1;
  commission := coalesce(svc.provider_commission, settings.commission_percent);

  due := case
    when p_pay_full then svc.price
    else round(svc.price * svc.deposit_percent / 100.0, 2)
  end;

  insert into public.bookings (
    reference, user_id, user_name, provider_id, provider_name,
    service_id, service_title, category_id, category_name, plan_id,
    event_date, event_time, governorate, address, guests_count, notes,
    status, total_price, deposit_amount, paid_amount,
    commission_percent, commission_amount, cancellation_rules
  ) values (
    'BK-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    me, me_row.full_name, svc.provider_id, svc.business_name,
    svc.id, svc.title, svc.category_id, svc.category_name, p_plan_id,
    p_event_date, p_event_time, me_row.governorate, p_address, p_guests_count, p_notes,
    'pending_provider', svc.price, round(svc.price * svc.deposit_percent / 100.0, 2), 0,
    commission, 0, svc.rules
  ) returning * into booking;

  -- الدفعة تبدأ معلّقة؛ خطّاف بوابة الدفع هو من يحوّلها إلى «مدفوعة».
  insert into public.payments (
    reference, user_id, user_name, provider_id, provider_name,
    booking_id, booking_reference, kind, description,
    amount, platform_share, net_amount, status
  ) values (
    'TRX-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    me, me_row.full_name, svc.provider_id, svc.business_name,
    booking.id, booking.reference,
    case when p_pay_full then 'full' else 'deposit' end,
    case when p_pay_full then 'سداد كامل — ' else 'عربون حجز — ' end || svc.category_name,
    due, round(due * commission / 100.0, 2), due - round(due * commission / 100.0, 2),
    'pending'
  );

  perform public.notify_provider(
    svc.provider_id, 'booking', 'طلب حجز جديد',
    'وصلك طلب حجز جديد بانتظار ردّك.',
    jsonb_build_object('booking_id', booking.id)
  );

  return booking;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_cancel_booking — إلغاء العميل، والاسترداد بحسب السلّم المنسوخ في الحجز.
-- ----------------------------------------------------------------------------
create or replace function public.api_cancel_booking(
  p_booking_id uuid,
  p_reason     text default ''
)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  booking public.bookings;
  refund  numeric(12,2);
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  if booking.user_id is distinct from me and not public.can_write() then
    raise exception 'لا تملك صلاحية إلغاء هذا الحجز';
  end if;
  if booking.status in ('completed', 'cancelled', 'rejected') then
    raise exception 'لا يمكن إلغاء حجز في حالته الحالية';
  end if;

  refund := public.refundable_amount(booking.id);

  update public.bookings set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = coalesce(nullif(p_reason, ''), 'ألغى العميل الحجز.'),
    refunded_amount = refund
  where id = booking.id
  returning * into booking;

  -- الاسترداد يُقيَّد كعملية مستقلة ليبقى أثره في الدفتر.
  if refund > 0 then
    insert into public.payments (
      reference, user_id, user_name, provider_id, provider_name,
      booking_id, booking_reference, kind, description,
      amount, platform_share, net_amount, status, refunded_at
    ) values (
      'RFD-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      booking.user_id, booking.user_name, booking.provider_id, booking.provider_name,
      booking.id, booking.reference, 'refund',
      'استرداد إلغاء — ' || booking.category_name,
      refund, 0, 0, 'refunded', now()
    );
  end if;

  perform public.notify_provider(
    booking.provider_id, 'booking', 'أُلغي حجز',
    'ألغى العميل الحجز ' || booking.reference || '.',
    jsonb_build_object('booking_id', booking.id)
  );

  return booking;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_submit_review — تقييم بعد التنفيذ فقط، ثم تُحدَّث سمعة مقدّم الخدمة.
-- ----------------------------------------------------------------------------
create or replace function public.api_submit_review(
  p_booking_id uuid,
  p_rating     integer,
  p_comment    text default ''
)
returns public.reviews
language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  booking public.bookings;
  review  public.reviews;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  if booking.user_id is distinct from me then
    raise exception 'لا يمكنك تقييم حجز ليس لك';
  end if;
  -- شرط الوثيقة: التقييم عقب إتمام وتأكيد تنفيذ الحجز فقط
  if booking.status <> 'completed' then
    raise exception 'التقييم متاح بعد تنفيذ الخدمة فقط';
  end if;
  if p_rating < 1 or p_rating > 5 then
    raise exception 'التقييم يجب أن يكون بين 1 و 5';
  end if;

  insert into public.reviews (booking_id, user_id, user_name, provider_id, rating, comment)
  values (booking.id, me, booking.user_name, booking.provider_id, p_rating, p_comment)
  on conflict (booking_id) do update
    set rating = excluded.rating, comment = excluded.comment, created_at = now()
  returning * into review;

  perform public.recalc_provider_rating(booking.provider_id);

  perform public.notify_provider(
    booking.provider_id, 'review', 'تقييم جديد',
    'قيّم العميل خدمتك بـ ' || p_rating || ' نجوم.',
    jsonb_build_object('booking_id', booking.id)
  );

  return review;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_open_dispute — يفتحه أي من الطرفين على حجز يخصّه.
-- ----------------------------------------------------------------------------
create or replace function public.api_open_dispute(
  p_booking_id  uuid,
  p_subject     text,
  p_description text default '',
  p_category    text default 'other'
)
returns public.disputes
language plpgsql security definer set search_path = public as $$
declare
  me       uuid := public.current_app_user();
  as_prov  uuid := public.current_provider();
  booking  public.bookings;
  opener   text;
  dispute  public.disputes;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;

  if booking.user_id = me then
    opener := 'customer';
  elsif booking.provider_id = as_prov and as_prov is not null then
    opener := 'provider';
  else
    raise exception 'لا تملك صلاحية فتح نزاع على هذا الحجز';
  end if;

  insert into public.disputes (
    reference, booking_id, booking_reference, opened_by,
    user_id, user_name, provider_id, provider_name,
    subject, description, category
  ) values (
    'DSP-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    booking.id, booking.reference, opener,
    booking.user_id, booking.user_name, booking.provider_id, booking.provider_name,
    p_subject, p_description, p_category
  ) returning * into dispute;

  insert into public.dispute_messages (dispute_id, author, author_name, body)
  values (dispute.id, opener,
          case when opener = 'customer' then booking.user_name else booking.provider_name end,
          coalesce(nullif(p_description, ''), p_subject));

  return dispute;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_toggle_favourite — إضافة/إزالة خدمة من المفضّلة، وتعيد الحالة الجديدة.
-- ----------------------------------------------------------------------------
create or replace function public.api_toggle_favourite(p_service_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  me uuid := public.current_app_user();
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  if exists (select 1 from public.favourites where user_id = me and service_id = p_service_id) then
    delete from public.favourites where user_id = me and service_id = p_service_id;
    return false;
  end if;

  insert into public.favourites (user_id, service_id) values (me, p_service_id);
  return true;
end;
$$;

-- ============================================================================
--  دوال مقدّم الخدمة
-- ============================================================================

-- ----------------------------------------------------------------------------
-- api_apply_as_provider — «أريد تقديم خدمة»: ينشئ ملفاً قيد المراجعة.
-- الحساب يبقى مستخدماً عادياً حتى توافق الإدارة، كما تنص الوثيقة.
-- ----------------------------------------------------------------------------
create or replace function public.api_apply_as_provider(
  p_business_name text,
  p_phone         text default '',
  p_bio           text default '',
  p_governorate   text default '',
  p_category_ids  uuid[] default '{}'
)
returns public.service_providers
language plpgsql security definer set search_path = public as $$
declare
  me       uuid := public.current_app_user();
  me_row   public.app_users;
  gov_id   uuid;
  provider public.service_providers;
  cat      uuid;
begin
  if me is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;
  if exists (select 1 from public.service_providers where user_id = me) then
    raise exception 'لديك طلب أو حساب مقدّم خدمة بالفعل';
  end if;

  select * into me_row from public.app_users where id = me;
  select id into gov_id from public.governorates where name = p_governorate;

  insert into public.service_providers (
    user_id, full_name, business_name, email, phone, bio,
    governorate_id, governorate, coverage_areas, status
  ) values (
    me, me_row.full_name, p_business_name, me_row.email, coalesce(nullif(p_phone,''), me_row.phone),
    p_bio, gov_id, coalesce(nullif(p_governorate,''), me_row.governorate),
    case when p_governorate = '' then '{}' else array[p_governorate] end,
    'pending'
  ) returning * into provider;

  foreach cat in array p_category_ids loop
    insert into public.provider_categories (provider_id, category_id)
    values (provider.id, cat) on conflict do nothing;
  end loop;

  return provider;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_respond_to_booking — قبول الحجز أو رفضه.
--
-- الرفض يستردّ للعميل كل ما دفعه: الخطأ ليس منه.
-- ----------------------------------------------------------------------------
create or replace function public.api_respond_to_booking(
  p_booking_id uuid,
  p_accept     boolean,
  p_reason     text default ''
)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  as_prov uuid := public.current_provider();
  booking public.bookings;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  -- is distinct from, لأن as_prov تكون NULL لمن ليس مقدّم خدمة، و`<>` مع NULL
  -- تعطي NULL فيمرّ الفحص ويقبل العميل حجزه بنفسه.
  if booking.provider_id is distinct from as_prov and not public.can_write() then
    raise exception 'لا تملك صلاحية الرد على هذا الحجز';
  end if;
  if booking.status <> 'pending_provider' then
    raise exception 'تم الرد على هذا الحجز مسبقاً';
  end if;

  if p_accept then
    update public.bookings set
      status = 'confirmed',
      confirmed_at = now(),
      commission_amount = round(total_price * commission_percent / 100.0, 2)
    where id = booking.id
    returning * into booking;

    -- الموعد يُغلق في تقويم مقدّم الخدمة فور التأكيد
    insert into public.provider_availability (provider_id, day, is_blocked, note)
    values (booking.provider_id, booking.event_date, true, 'محجوز — ' || booking.reference)
    on conflict (provider_id, day) do nothing;

    insert into public.invoices (number, booking_id, user_id, provider_id, subtotal, commission, total)
    values (
      'INV-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      booking.id, booking.user_id, booking.provider_id,
      booking.total_price, booking.commission_amount, booking.total_price
    );

    perform public.notify_user(
      booking.user_id, 'booking', 'تم تأكيد حجزك',
      'قبل مقدّم الخدمة حجزك ' || booking.reference || '.',
      jsonb_build_object('booking_id', booking.id)
    );
  else
    update public.bookings set
      status = 'rejected',
      cancelled_at = now(),
      rejection_reason = coalesce(nullif(p_reason, ''), 'اعتذر مقدّم الخدمة.'),
      refunded_amount = paid_amount
    where id = booking.id
    returning * into booking;

    if booking.paid_amount > 0 then
      insert into public.payments (
        reference, user_id, user_name, provider_id, provider_name,
        booking_id, booking_reference, kind, description,
        amount, platform_share, net_amount, status, refunded_at
      ) values (
        'RFD-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
        booking.user_id, booking.user_name, booking.provider_id, booking.provider_name,
        booking.id, booking.reference, 'refund',
        'استرداد رفض — ' || booking.category_name,
        booking.paid_amount, 0, 0, 'refunded', now()
      );
    end if;

    perform public.notify_user(
      booking.user_id, 'booking', 'اعتذر مقدّم الخدمة',
      'رُفض الحجز ' || booking.reference || ' وسيُعاد المبلغ المدفوع.',
      jsonb_build_object('booking_id', booking.id)
    );
  end if;

  return booking;
end;
$$;

-- ----------------------------------------------------------------------------
-- api_complete_booking — تأكيد تنفيذ الخدمة، وبه يُفتح باب التقييم.
-- ----------------------------------------------------------------------------
create or replace function public.api_complete_booking(p_booking_id uuid)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  as_prov uuid := public.current_provider();
  booking public.bookings;
begin
  select * into booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'الحجز غير موجود';
  end if;
  if booking.provider_id is distinct from as_prov and not public.can_write() then
    raise exception 'لا تملك صلاحية إنهاء هذا الحجز';
  end if;
  if booking.status <> 'confirmed' then
    raise exception 'لا يمكن إنهاء حجز غير مؤكد';
  end if;

  update public.bookings set status = 'completed', completed_at = now()
  where id = booking.id returning * into booking;

  -- عدّادات المنصة، لا تعديل من مقدّم الخدمة: يُرفع العلم الداخلي ليمرّ الحارس.
  perform set_config('app.internal', 'on', true);
  update public.service_providers
  set completed_bookings = completed_bookings + 1,
      total_earnings = total_earnings + (booking.total_price - booking.commission_amount)
  where id = booking.provider_id;
  perform set_config('app.internal', 'off', true);

  perform public.notify_user(
    booking.user_id, 'review', 'كيف كانت الخدمة؟',
    'شاركنا رأيك في الخدمة التي نُفّذت.',
    jsonb_build_object('booking_id', booking.id)
  );

  return booking;
end;
$$;

-- ============================================================================
--  دوال داخلية — لا تُستدعى من التطبيق
-- ============================================================================

create or replace function public.notify_user(
  p_user_id uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}'::jsonb
) returns void language sql security definer set search_path = public as $$
  insert into public.notifications (user_id, kind, title, body, data)
  select p_user_id, p_kind, p_title, p_body, p_data where p_user_id is not null;
$$;

create or replace function public.notify_provider(
  p_provider_id uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}'::jsonb
) returns void language sql security definer set search_path = public as $$
  insert into public.notifications (provider_id, kind, title, body, data)
  select p_provider_id, p_kind, p_title, p_body, p_data where p_provider_id is not null;
$$;

-- متوسط التقييم يُعاد حسابه من التقييمات المنشورة وحدها
create or replace function public.recalc_provider_rating(p_provider_id uuid)
returns void language sql security definer set search_path = public as $$
  select set_config('app.internal', 'on', true);
  update public.service_providers p set
    rating = coalesce((
      select round(avg(r.rating)::numeric, 1) from public.reviews r
      where r.provider_id = p_provider_id and r.status = 'published'
    ), 0),
    reviews_count = (
      select count(*) from public.reviews r
      where r.provider_id = p_provider_id and r.status = 'published'
    )
  where p.id = p_provider_id;
  select set_config('app.internal', 'off', true);
$$;

-- ----------------------------------------------------------------------------
-- api_confirm_payment — يستدعيها خطّاف بوابة الدفع بمفتاح الخدمة، لا التطبيق.
-- تحويل دفعة إلى «مدفوعة» يزيد المدفوع في الحجز بنفس المقدار.
-- ----------------------------------------------------------------------------
create or replace function public.api_confirm_payment(
  p_payment_id  uuid,
  p_gateway_ref text default '',
  p_method      text default 'jawali'
)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  pay public.payments;
begin
  select * into pay from public.payments where id = p_payment_id;
  if not found then
    raise exception 'العملية غير موجودة';
  end if;
  if pay.status = 'paid' then
    return pay;  -- إعادة استدعاء الخطّاف مرتين لا تُضاعف المبلغ
  end if;
  if pay.status <> 'pending' then
    raise exception 'لا يمكن تأكيد عملية في حالتها الحالية';
  end if;

  update public.payments
  set status = 'paid', gateway_ref = p_gateway_ref, method = p_method
  where id = pay.id returning * into pay;

  if pay.booking_id is not null then
    update public.bookings
    set paid_amount = paid_amount + pay.amount
    where id = pay.booking_id;
  end if;

  perform public.notify_user(
    pay.user_id, 'payment', 'تم استلام الدفعة',
    'تم تأكيد دفعتك بنجاح.',
    jsonb_build_object('payment_id', pay.id, 'booking_id', pay.booking_id)
  );

  return pay;
end;
$$;

-- ============================================================================
--  الصلاحيات: الدوال الموجّهة للتطبيقين فقط تُمنح للمستخدمين المسجَّلين.
--  api_confirm_payment ليست منها — تبقى لمفتاح الخدمة وحده.
-- ============================================================================

revoke all on function public.api_confirm_payment(uuid, text, text) from public, anon, authenticated;

grant execute on function
  public.api_register_profile(text, text, text, text),
  public.api_create_booking(uuid, date, time, uuid, integer, text, text, boolean),
  public.api_cancel_booking(uuid, text),
  public.api_submit_review(uuid, integer, text),
  public.api_open_dispute(uuid, text, text, text),
  public.api_toggle_favourite(uuid),
  public.api_apply_as_provider(text, text, text, text, uuid[]),
  public.api_respond_to_booking(uuid, boolean, text),
  public.api_complete_booking(uuid)
to authenticated;

grant select on public.v_services, public.v_providers to anon, authenticated;
grant select on public.v_plan_summary to authenticated;


