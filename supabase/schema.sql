-- ============================================================================
--  لوحة تحكم تطبيق الجوال — مخطط قاعدة البيانات
--  شغّل هذا الملف في: Supabase Dashboard ← SQL Editor ← New query
--  ثم شغّل supabase/seed.sql إن أردت بيانات تجريبية للبدء.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- المسؤولون وأدوارهم — كل سياسات RLS أدناه تعتمد على هذا الجدول
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
returns text
language sql
stable
security definer
set search_path = public
as $$
  select a.role from public.admins a where a.user_id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.admin_role() is not null;
$$;

-- من يملك حق التعديل. viewer يقرأ فقط.
create or replace function public.can_write()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.admin_role() in ('owner', 'admin');
$$;

create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.admin_role() = 'owner';
$$;

-- ----------------------------------------------------------------------------
-- مستخدمو التطبيق
-- ----------------------------------------------------------------------------
create table if not exists public.app_users (
  id             uuid primary key default gen_random_uuid(),
  full_name      text not null,
  email          text not null unique,
  phone          text,
  platform       text not null check (platform in ('ios', 'android')),
  country        text not null default '',
  status         text not null default 'pending'
                 check (status in ('active', 'suspended', 'pending')),
  app_version    text not null default '',
  sessions_count integer not null default 0 check (sessions_count >= 0),
  created_at     timestamptz not null default now(),
  last_seen_at   timestamptz
);

create index if not exists app_users_created_at_idx on public.app_users (created_at desc);
create index if not exists app_users_status_idx     on public.app_users (status);
create index if not exists app_users_platform_idx   on public.app_users (platform);

-- ----------------------------------------------------------------------------
-- جلسات المستخدم — تغذّي شاشة تفاصيل المستخدم
-- ----------------------------------------------------------------------------
create table if not exists public.user_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.app_users (id) on delete cascade,
  started_at       timestamptz not null default now(),
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  platform         text not null check (platform in ('ios', 'android')),
  app_version      text not null default '',
  country          text not null default ''
);

create index if not exists user_sessions_user_idx
  on public.user_sessions (user_id, started_at desc);

-- ----------------------------------------------------------------------------
-- أجهزة المستخدم
-- ----------------------------------------------------------------------------
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
-- المشتريات داخل التطبيق
-- ----------------------------------------------------------------------------
create table if not exists public.purchases (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.app_users (id) on delete cascade,
  product    text not null,
  amount     numeric(12, 2) not null check (amount >= 0),
  status     text not null default 'paid'
             check (status in ('paid', 'refunded', 'failed', 'pending')),
  created_at timestamptz not null default now()
);

create index if not exists purchases_user_idx on public.purchases (user_id, created_at desc);

-- ----------------------------------------------------------------------------
-- المقاييس اليومية (صف واحد لكل يوم × منصة)
-- ----------------------------------------------------------------------------
create table if not exists public.daily_metrics (
  day          date not null,
  platform     text not null check (platform in ('ios', 'android')),
  installs     integer not null default 0 check (installs >= 0),
  sessions     integer not null default 0 check (sessions >= 0),
  active_users integer not null default 0 check (active_users >= 0),
  revenue      numeric(12, 2) not null default 0 check (revenue >= 0),
  primary key (day, platform)
);

create index if not exists daily_metrics_day_idx on public.daily_metrics (day desc);

-- ----------------------------------------------------------------------------
-- الإشعارات
-- ----------------------------------------------------------------------------
create table if not exists public.push_notifications (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  body         text not null,
  audience     text not null default 'all'
               check (audience in ('all', 'ios', 'android', 'active', 'inactive')),
  status       text not null default 'draft'
               check (status in ('sent', 'scheduled', 'draft', 'failed')),
  scheduled_at timestamptz,
  sent_at      timestamptz,
  recipients   integer not null default 0 check (recipients >= 0),
  opened       integer not null default 0 check (opened >= 0),
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  -- إشعار مجدول لا معنى له بدون موعد
  constraint scheduled_needs_time
    check (status <> 'scheduled' or scheduled_at is not null)
);

create index if not exists push_notifications_created_at_idx
  on public.push_notifications (created_at desc);

-- ----------------------------------------------------------------------------
-- إصدارات التطبيق
-- ----------------------------------------------------------------------------
create table if not exists public.app_versions (
  id              uuid primary key default gen_random_uuid(),
  platform        text not null check (platform in ('ios', 'android')),
  version         text not null,
  build           integer not null,
  released_at     timestamptz not null default now(),
  force_update    boolean not null default false,
  rollout_percent integer not null default 100
                  check (rollout_percent between 0 and 100),
  notes           text not null default '',
  unique (platform, build)
);

create index if not exists app_versions_released_at_idx
  on public.app_versions (released_at desc);

-- ----------------------------------------------------------------------------
-- البلاغات والدعم الفني
-- ----------------------------------------------------------------------------
create table if not exists public.support_tickets (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.app_users (id) on delete set null,
  user_name  text not null default '',
  user_email text not null default '',
  subject    text not null,
  category   text not null default 'other'
             check (category in ('bug', 'billing', 'account', 'feature', 'other')),
  status     text not null default 'open'
             check (status in ('open', 'pending', 'resolved', 'closed')),
  priority   text not null default 'normal'
             check (priority in ('low', 'normal', 'high', 'urgent')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists support_tickets_status_idx
  on public.support_tickets (status, created_at desc);

create table if not exists public.ticket_messages (
  id           uuid primary key default gen_random_uuid(),
  ticket_id    uuid not null references public.support_tickets (id) on delete cascade,
  author       text not null check (author in ('user', 'admin')),
  author_email text not null default '',
  body         text not null,
  created_at   timestamptz not null default now()
);

create index if not exists ticket_messages_ticket_idx
  on public.ticket_messages (ticket_id, created_at);

-- ----------------------------------------------------------------------------
-- مقدّمو الخدمة
--
--   pending  : قدّم طلبه وينتظر مراجعة المستندات
--   active   : موثّق ويستقبل الطلبات
--   suspended: كان مفعّلاً ثم أُوقف
--   rejected : رُفض عند المراجعة ولم يُفعّل قط
-- ----------------------------------------------------------------------------
create table if not exists public.service_providers (
  id                uuid primary key default gen_random_uuid(),
  full_name         text not null,
  business_name     text not null default '',
  email             text not null unique,
  phone             text not null default '',
  category          text not null default '',
  city              text not null default '',
  status            text not null default 'pending'
                    check (status in ('pending', 'active', 'suspended', 'rejected')),
  rating            numeric(2, 1) not null default 0 check (rating between 0 and 5),
  reviews_count     integer not null default 0 check (reviews_count >= 0),
  completed_orders  integer not null default 0 check (completed_orders >= 0),
  total_earnings    numeric(12, 2) not null default 0 check (total_earnings >= 0),
  commission_percent integer not null default 15
                    check (commission_percent between 0 and 100),
  joined_at         timestamptz not null default now(),
  verified_at       timestamptz
);

create index if not exists service_providers_status_idx
  on public.service_providers (status, joined_at desc);
create index if not exists service_providers_category_idx
  on public.service_providers (category);
create index if not exists service_providers_city_idx
  on public.service_providers (city);

create table if not exists public.provider_documents (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.service_providers (id) on delete cascade,
  type        text not null
              check (type in ('id_card', 'commercial_register', 'certificate', 'insurance')),
  file_name   text not null,
  status      text not null default 'pending'
              check (status in ('pending', 'approved', 'rejected')),
  note        text not null default '',
  uploaded_at timestamptz not null default now()
);

create index if not exists provider_documents_provider_idx
  on public.provider_documents (provider_id);

create table if not exists public.provider_services (
  id               uuid primary key default gen_random_uuid(),
  provider_id      uuid not null references public.service_providers (id) on delete cascade,
  title            text not null,
  price            numeric(12, 2) not null check (price >= 0),
  duration_minutes integer not null default 60 check (duration_minutes > 0),
  active           boolean not null default true
);

create index if not exists provider_services_provider_idx
  on public.provider_services (provider_id);

create table if not exists public.provider_reviews (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.service_providers (id) on delete cascade,
  user_name   text not null default '',
  rating      integer not null check (rating between 1 and 5),
  comment     text not null default '',
  created_at  timestamptz not null default now()
);

create index if not exists provider_reviews_provider_idx
  on public.provider_reviews (provider_id, created_at desc);

-- ----------------------------------------------------------------------------
-- سجل عمليات المسؤولين — للإلحاق فقط، لا تعديل ولا حذف
-- ----------------------------------------------------------------------------
create table if not exists public.audit_log (
  id          uuid primary key default gen_random_uuid(),
  actor_email text not null default '',
  action      text not null,
  entity      text not null,
  entity_id   text not null default '',
  entity_label text not null default '',
  details     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists audit_log_created_at_idx on public.audit_log (created_at desc);
create index if not exists audit_log_entity_idx     on public.audit_log (entity, created_at desc);

-- ----------------------------------------------------------------------------
-- إعدادات التطبيق — صف واحد فقط (id = 1)
-- ----------------------------------------------------------------------------
create table if not exists public.app_settings (
  id                  smallint primary key default 1 check (id = 1),
  maintenance_mode    boolean not null default false,
  maintenance_message text not null default '',
  allow_signups       boolean not null default true,
  min_ios_version     text not null default '1.0.0',
  min_android_version text not null default '1.0.0',
  support_email       text not null default '',
  default_locale      text not null default 'ar',
  updated_at          timestamptz not null default now()
);

insert into public.app_settings (id) values (1) on conflict (id) do nothing;

-- ============================================================================
--  RLS — كل الجداول مقفلة. القراءة لكل مسؤول، والكتابة لمن دوره owner أو admin.
-- ============================================================================
alter table public.admins             enable row level security;
alter table public.app_users          enable row level security;
alter table public.user_sessions      enable row level security;
alter table public.user_devices       enable row level security;
alter table public.purchases          enable row level security;
alter table public.daily_metrics      enable row level security;
alter table public.push_notifications enable row level security;
alter table public.app_versions       enable row level security;
alter table public.support_tickets    enable row level security;
alter table public.ticket_messages    enable row level security;
alter table public.service_providers  enable row level security;
alter table public.provider_documents enable row level security;
alter table public.provider_services  enable row level security;
alter table public.provider_reviews   enable row level security;
alter table public.audit_log          enable row level security;
alter table public.app_settings       enable row level security;

-- جدول المسؤولين: كل مسؤول يقرأ القائمة، لكن التعديل عليها لصاحب دور owner فقط.
drop policy if exists admins_read on public.admins;
create policy admins_read on public.admins
  for select using (public.is_admin());

drop policy if exists admins_owner_writes on public.admins;
create policy admins_owner_writes on public.admins
  for all using (public.is_owner()) with check (public.is_owner());

-- بقية جداول البيانات: قراءة لكل مسؤول، كتابة لمن يملك الصلاحية.
do $$
declare
  t text;
begin
  foreach t in array array[
    'app_users', 'user_sessions', 'user_devices', 'purchases', 'daily_metrics',
    'push_notifications', 'app_versions', 'support_tickets', 'ticket_messages',
    'service_providers', 'provider_documents', 'provider_services',
    'provider_reviews', 'app_settings'
  ] loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format(
      'create policy %I_read on public.%I for select using (public.is_admin())', t, t);

    execute format('drop policy if exists %I_write on public.%I', t, t);
    execute format(
      'create policy %I_write on public.%I for all
         using (public.can_write()) with check (public.can_write())', t, t);
  end loop;
end $$;

-- سجل العمليات: يقرأه كل مسؤول، ويكتب فيه من يملك صلاحية التعديل.
-- لا توجد سياسة update أو delete إطلاقاً — السجل للإلحاق فقط، حتى لا يستطيع
-- مسؤول محو أثر ما فعله.
drop policy if exists audit_log_read on public.audit_log;
create policy audit_log_read on public.audit_log
  for select using (public.is_admin());

drop policy if exists audit_log_append on public.audit_log;
create policy audit_log_append on public.audit_log
  for insert with check (public.can_write());

-- ============================================================================
--  بعد التشغيل: أنشئ مستخدماً من Authentication ← Users، ثم امنحه الدور:
--
--    insert into public.admins (user_id, email, role)
--    select id, email, 'owner' from auth.users where email = 'you@example.com';
-- ============================================================================
