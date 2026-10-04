// Pure SQL bundle builders. Print with `node tool/security_sql.mjs install|hardening`.
// The checked-in SQL is compared with these builders by security_hardening.test.mjs.
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const read = (name) => readFileSync(new URL(`../supabase/${name}`, import.meta.url), 'utf8').replace(/\r\n/g, '\n')
const escape = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

function fn(file, name) {
  const match = read(file).match(new RegExp(`create (?:or replace )?function public\\.${escape(name)}\\([\\s\\S]*?\\$\\$;`, 'i'))
  if (!match) throw new Error(`Missing function ${name} in ${file}`)
  return `-- Source: ${file}\n` + match[0].replace(/^create function/i, 'create or replace function')
}

function policy(file, name) {
  const match = read(file).match(new RegExp(`drop policy if exists ${escape(name)} on [^;]+;\\s*create policy ${escape(name)}[\\s\\S]*?;`, 'i'))
  if (!match) throw new Error(`Missing policy ${name} in ${file}`)
  return `-- Source: ${file}\n` + match[0]
}

export function buildInstall() {
  return '-- التثبيت الأساسي: schema.sql ثم policies.sql ثم api.sql.\n' +
    '-- بعد ملفات الميزات، شغّل security_hardening.sql أخيراً.\n' +
    '-- لا تشغّل seed.sql على بيانات حقيقية.\n\n' +
    ['schema.sql', 'policies.sql', 'api.sql'].map(f => `-- Source: ${f}\n${read(f).trimEnd()}`).join('\n\n') + '\n'
}

export function buildHardening() {
  const prelude = `-- إصلاحات المراجعة الأمنية للقواعد القائمة — معاملة واحدة، بلا حذف بيانات.
-- المصدر مركّب من الملفات الأصلية بواسطة tool/security_sql.mjs.
-- شغّل هذا الملف أخيراً بعد ملفات الميزات المذكورة في SECURITY_DEPLOYMENT.md.
begin;

do $$
begin
  if to_regclass('public.admin_areas') is null
     or to_regclass('public.support_tickets') is null
     or to_regclass('public.coupons') is null
     or to_regclass('public.plan_tasks') is null
     or to_regclass('public.service_media') is null
     or to_regclass('public.phone_otp_sends') is null
     or (to_regprocedure('public.api_update_profile(text,text,uuid,text)') is null
         and to_regprocedure('public.api_update_profile(text,text,uuid,text,text)') is null) then
    raise exception 'تحتاج ملفات roles/support/profile/coupons/plan_tasks/service_media/phone_verify قبل هذا الترحيل';
  end if;
  if exists (select 1 from public.bookings where status = 'confirmed' and provider_id is not null
              group by provider_id, event_date having count(*) > 1) then
    raise exception 'توجد حجوزات مؤكدة متعارضة؛ راجع فحص المواعيد في SECURITY_DEPLOYMENT.md قبل الترحيل';
  end if;
end;
$$;

alter table public.app_users add column if not exists phone_verified_at timestamptz;
alter table public.app_settings add column if not exists require_phone_verification boolean not null default false;
drop policy if exists users_self_update on public.app_users;
drop policy if exists users_self_insert on public.app_users;
drop policy if exists availability_owner_write on public.provider_availability;
create unique index if not exists bookings_confirmed_provider_day_key
  on public.bookings (provider_id, event_date)
  where status = 'confirmed' and provider_id is not null;
`
  const functions = [
    ['schema.sql', 'current_app_user'],
    ['policies.sql', 'guard_provider_self_update'],
    ['api.sql', 'api_cancel_booking'],
    ['coupons.sql', 'api_respond_to_booking'],
    ['payments_app.sql', 'api_admin_confirm_payment'],
    ['payments_app.sql', 'api_admin_reject_payment'],
    ['payments_app.sql', 'api_admin_refund_payment'],
    ['payments_app.sql', 'api_refund_outlook'],
    ['support.sql', 'admin_reply_ticket'],
    ['availability.sql', 'api_set_availability'],
    ['phone_verify.sql', 'otp_claim_send'],
  ].map(([file, name]) => fn(file, name))
  const policies = [
    ...['devices_owner', 'devices_admin_read', 'provider_categories_owner', 'services_owner_write',
      'plans_owner', 'plans_admin_read', 'favourites_owner', 'dispute_messages_write'].map(n => ['policies.sql', n]),
    ...['push_admin_only', 'push_admin_read', 'metrics_admin_only', 'metrics_admin_read'].map(n => ['roles.sql', n]),
    ...['plan_tasks_owner', 'plan_tasks_admin_read'].map(n => ['plan_tasks.sql', n]),
    ['service_media.sql', 'media_owner_write'],
    ['service_media.sql', '"provider or admin deletes media"'],
    ['chat_media.sql', '"chat media admin deletes"'],
  ].map(([file, name]) => policy(file, name))
  const audit = read('audit_security.sql').replace(/^begin;\s*$/m, '').replace(/^commit;\s*$/m, '')
  return [prelude, ...functions, ...policies, audit,
    'revoke all on function public.seed_plan_tasks(uuid) from public, anon, authenticated;',
    "notify pgrst, 'reload schema';\ncommit;\n"].join('\n\n')
}

function block(file, pattern) {
  const match = read(file).match(pattern)
  if (!match) throw new Error(`Missing block ${pattern} in ${file}`)
  return `-- Source: ${file}\n` + match[0]
}

/** Second security review: one paste for a live database, built from the canonical files. */
export function buildFixes() {
  const prelude = `-- إصلاحات الفحص الأمني الثاني — لصقةٌ واحدة للقاعدة الحيّة، بلا حذف بيانات.
-- المصدر مركّب من الملفات الأصلية بواسطة tool/security_sql.mjs (buildFixes).
-- شغّله بعد security_hardening.sql وphone_verify_attempts.sql. آمنٌ عند التكرار.
begin;

do $$
begin
  if to_regprocedure('public.otp_claim_verify(uuid,text)') is null then
    raise exception 'الصق phone_verify_attempts.sql أوّلاً — دالّةُ الرسائل صارت تردّ التحقّقَ بدون حدّ المحاولات';
  end if;
  if to_regprocedure('public.can_write_area(text)') is null
     or to_regclass('public.coupons') is null
     or to_regprocedure('public.api_create_booking(uuid,date,time,uuid,integer,text,text,boolean,text,numeric,numeric)') is null then
    raise exception 'تحتاج roles.sql وcoupons.sql وlocation.sql قبل هذا الملف';
  end if;
end;
$$;

-- Source: policies.sql
drop policy if exists conversations_parties_write on public.conversations;
`
  return [
    prelude,
    fn('chat.sql', 'api_open_conversation'),
    block('coupons.sql', /create table if not exists public\.coupon_checks[\s\S]*?revoke all on public\.coupon_checks from public, anon, authenticated;/),
    fn('coupons.sql', 'api_check_coupon'),
    fn('location.sql', 'api_create_booking'),
    block('policies.sql', /do \$\$\ndeclare\n {2}cols text;[\s\S]*?end \$\$;/),
    '-- Source: document_guard.sql\n' +
      read('document_guard.sql').split('\nbegin;\n')[1].replace(/\ncommit;\s*$/, '').trim(),
    "notify pgrst, 'reload schema';\ncommit;\n",
  ].join('\n\n')
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const which = process.argv[2]
  process.stdout.write(which === 'install' ? buildInstall() : which === 'fixes' ? buildFixes() : buildHardening())
}
