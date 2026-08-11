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
create or replace function public.can_write()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_role() in ('owner', 'admin');
$$;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select public.admin_role() = 'owner';
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
  constraint cancelled_needs_timestamp
    check ((status in ('cancelled', 'rejected')) = (cancelled_at is not null))
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
--  9. RLS — كل الجداول مقفلة. القراءة لكل مسؤول، والكتابة لمن دوره owner أو admin.
-- ============================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'governorates', 'service_categories', 'cancellation_policies',
    'app_users', 'user_sessions', 'user_devices',
    'service_providers', 'provider_categories', 'provider_documents',
    'provider_services', 'provider_availability',
    'wedding_plans', 'bookings',
    'payments', 'settlements', 'settlement_items',
    'reviews', 'disputes', 'dispute_messages',
    'conversations', 'conversation_messages',
    'subscription_plans', 'provider_subscriptions', 'promotions',
    'push_notifications', 'daily_metrics', 'app_versions', 'app_settings'
  ] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format(
      'create policy %I_read on public.%I for select using (public.is_admin())', t, t);

    execute format('drop policy if exists %I_write on public.%I', t, t);
    execute format(
      'create policy %I_write on public.%I for all
         using (public.can_write()) with check (public.can_write())', t, t);
  end loop;
end $$;

-- جدول المسؤولين: يقرأه كل مسؤول، ولا يعدّله إلا المالك.
alter table public.admins enable row level security;

drop policy if exists admins_read on public.admins;
create policy admins_read on public.admins
  for select using (public.is_admin());

drop policy if exists admins_owner_writes on public.admins;
create policy admins_owner_writes on public.admins
  for all using (public.is_owner()) with check (public.is_owner());

-- سجل العمليات: للإلحاق فقط — لا سياسة update ولا delete إطلاقاً، حتى لا يمحو
-- مسؤول أثر ما فعله.
alter table public.audit_log enable row level security;

drop policy if exists audit_log_read on public.audit_log;
create policy audit_log_read on public.audit_log
  for select using (public.is_admin());

drop policy if exists audit_log_append on public.audit_log;
create policy audit_log_append on public.audit_log
  for insert with check (public.can_write());

-- ============================================================================
--  10. دوال مساعدة
-- ============================================================================

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
