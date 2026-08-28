// كل حقل في أنواع الواجهة يجب أن يقابله عمود في القاعدة، وإلا وصل undefined
// إلى الشاشة بلا خطأ — وهو أسوأ من الخطأ لأنه يمرّ صامتاً.
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

const db = new PGlite()
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role authenticated; create role anon; create role service_role;
  -- ما يكفي من مخطط التخزين لتمرّ ملفّاتُ السلال.
  create schema if not exists storage;
  create table if not exists storage.buckets (
    id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table if not exists storage.objects (
    id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  create or replace function storage.foldername(p text) returns text[]
    language sql immutable as $$ select string_to_array(p, '/') $$;`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql', 'coupons.sql', 'category_images.sql']) {
  await db.exec(readFileSync(`../${f}`, 'utf8'))
}

const cols = await db.query(
  `select table_name, column_name from information_schema.columns where table_schema='public'`)
const columns = new Map()
for (const c of cols.rows) {
  if (!columns.has(c.table_name)) columns.set(c.table_name, new Set())
  columns.get(c.table_name).add(c.column_name)
}

// النوع في الواجهة ← العلاقة التي تُقرأ منها فعلاً في طبقة الخدمات
const MAP = {
  AppUser: 'app_users', UserSession: 'user_sessions', UserDevice: 'user_devices',
  ServiceProvider: 'v_admin_providers', ProviderDocument: 'provider_documents',
  ProviderService: 'v_admin_services', Booking: 'bookings', Payment: 'payments',
  Settlement: 'v_admin_settlements', Review: 'v_admin_reviews', Dispute: 'disputes',
  DisputeMessage: 'dispute_messages', WeddingPlan: 'v_plan_summary',
  SubscriptionPlan: 'v_admin_subscription_plans', Promotion: 'v_admin_promotions',
  ServiceCategory: 'service_categories', CancellationPolicy: 'cancellation_policies',
  Governorate: 'governorates', AppVersion: 'app_versions', AuditEntry: 'audit_log',
  AdminAccount: 'admins',
  SupportTicket: 'v_admin_tickets', SupportMessage: 'support_messages',
  Coupon: 'v_coupons',
}

const src = readFileSync('../../src/lib/types.ts', 'utf8')
const missing = []
for (const [type, relation] of Object.entries(MAP)) {
  const m = src.match(new RegExp(`export interface ${type} \\{([\\s\\S]*?)\\n\\}`))
  if (!m) { missing.push(`النوع ${type} غير موجود في types.ts`); continue }
  const have = columns.get(relation)
  if (!have) { missing.push(`العلاقة ${relation} غير موجودة في القاعدة (للنوع ${type})`); continue }
  for (const line of m[1].split('\n')) {
    const f = line.match(/^\s{2}([a-z_][a-z0-9_]*)\??:/)
    if (!f) continue
    if (line.includes('?:')) continue          // الحقول المحسوبة اختيارية
    if (!have.has(f[1])) missing.push(`${relation} ← ${type}.${f[1]}`)
  }
}

if (missing.length === 0) console.log('✅ كل حقل في الأنواع له عمود مقابل')
else { console.log(`❌ ${missing.length} حقلاً بلا عمود:`); for (const x of missing) console.log('  •', x) }
await db.close()
process.exit(missing.length === 0 ? 0 : 1)
