-- ============================================================================
--  لوحة تحكم تطبيق الجوال — مخطط قاعدة البيانات
--  شغّل هذا الملف في: Supabase Dashboard ← SQL Editor ← New query
-- ============================================================================

-- ----------------------------------------------------------------------------
-- من هو المسؤول؟ كل سياسات RLS أدناه تعتمد على هذا الجدول.
-- ----------------------------------------------------------------------------
create table if not exists public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- security definer: تتجاوز RLS على جدول admins نفسه، وإلا لصار الفحص دائرياً.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

-- ----------------------------------------------------------------------------
-- مستخدمو التطبيق
-- ----------------------------------------------------------------------------
create table if not exists public.app_users (
  id            uuid primary key default gen_random_uuid(),
  full_name     text not null,
  email         text not null unique,
  phone         text,
  platform      text not null check (platform in ('ios', 'android')),
  country       text not null default '',
  status        text not null default 'pending'
                check (status in ('active', 'suspended', 'pending')),
  app_version   text not null default '',
  sessions_count integer not null default 0 check (sessions_count >= 0),
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz
);

create index if not exists app_users_created_at_idx on public.app_users (created_at desc);
create index if not exists app_users_status_idx     on public.app_users (status);
create index if not exists app_users_platform_idx   on public.app_users (platform);

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
--  RLS — كل الجداول مقفلة، والوصول للمسؤولين فقط
-- ============================================================================
alter table public.admins            enable row level security;
alter table public.app_users         enable row level security;
alter table public.daily_metrics     enable row level security;
alter table public.push_notifications enable row level security;
alter table public.app_versions      enable row level security;
alter table public.app_settings      enable row level security;

-- كل مستخدم يرى صفّه في admins فقط (للتحقق من صلاحيته بعد تسجيل الدخول).
drop policy if exists admins_read_self on public.admins;
create policy admins_read_self on public.admins
  for select using (user_id = auth.uid());

-- بقية الجداول: قراءة وكتابة كاملة للمسؤولين، ولا شيء لغيرهم.
do $$
declare
  t text;
begin
  foreach t in array array[
    'app_users', 'daily_metrics', 'push_notifications', 'app_versions', 'app_settings'
  ] loop
    execute format('drop policy if exists %I_admin_all on public.%I', t, t);
    execute format(
      'create policy %I_admin_all on public.%I for all
         using (public.is_admin()) with check (public.is_admin())', t, t);
  end loop;
end $$;

-- ============================================================================
--  بعد التشغيل: أنشئ مستخدماً من Authentication ← Users، ثم امنحه الصلاحية:
--
--    insert into public.admins (user_id)
--    select id from auth.users where email = 'you@example.com';
-- ============================================================================
