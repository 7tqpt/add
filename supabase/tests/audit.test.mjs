import { PGlite } from '@electric-sql/pglite'
import { readFileSync, readdirSync } from 'node:fs'

// نبني القاعدة نفسها في الذاكرة، ثم نسأل الكاتالوج عمّا يطلبه الكود.
const db = new PGlite()
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role authenticated; create role anon; create role service_role;
  -- ما يكفي من مخطط التخزين لتمرّ ملفّات السلال وسياساتها.
  create schema if not exists storage;
  create table if not exists storage.buckets (
    id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table if not exists storage.objects (
    id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  create or replace function storage.foldername(p text) returns text[]
    language sql immutable as $$ select string_to_array(p, '/') $$;`)
// كل ملف يُنفَّذ على القاعدة الحقيقية يجب أن يكون هنا، وإلا صار الاختبار
// يبلّغ عن جداول «مفقودة» هي موجودة فعلاً — أو، وهو الأسوأ، تُضاف شاشة تقرأ
// جدولاً لم يُنشأ ولا ينبّه أحد.
for (const f of [
  'install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
  'invitations.sql', 'profile.sql', 'service_media.sql', 'chat.sql',
  'notifications.sql', 'push_hook.sql', 'provider_logo.sql', 'payments_app.sql',
  'broadcast.sql', 'availability.sql', 'subscriptions.sql', 'settlements.sql', 'promotions.sql',
  'plan_tasks.sql', 'income.sql', 'chat_media.sql', 'profile_extras.sql',
]) {
  await db.exec(readFileSync(`../${f}`, 'utf8'))
}

const rel = await db.query(`
  select table_name from information_schema.tables where table_schema='public'
  union select table_name from information_schema.views where table_schema='public'`)
const relations = new Set(rel.rows.map(r => r.table_name))

const cols = await db.query(`
  select table_name, column_name from information_schema.columns where table_schema='public'`)
const columns = new Map()
for (const c of cols.rows) {
  if (!columns.has(c.table_name)) columns.set(c.table_name, new Set())
  columns.get(c.table_name).add(c.column_name)
}

const fns = await db.query(`
  select routine_name from information_schema.routines where routine_schema='public'`)
const functions = new Set(fns.rows.map(r => r.routine_name))

const problems = []
for (const file of readdirSync('../../src/services')) {
  if (!file.endsWith('.ts')) continue
  const src = readFileSync(`../../src/services/${file}`, 'utf8')

  for (const m of src.matchAll(/\.from\('([^']+)'\)/g)) {
    if (!relations.has(m[1])) problems.push(`${file}: جدول غير موجود → ${m[1]}`)
  }
  for (const m of src.matchAll(/\.rpc\('([^']+)'/g)) {
    if (!functions.has(m[1])) problems.push(`${file}: دالة غير موجودة → ${m[1]}`)
  }
  // .from('x')...select('a, b, c') — نتحقق من الأعمدة المسمّاة صراحةً
  for (const m of src.matchAll(/\.from\('([^']+)'\)\s*[\s\S]{0,120}?\.select\('([^']*)'/g)) {
    const [, table, list] = m
    if (!relations.has(table) || list.trim() === '*' || list.includes('(')) continue
    for (const raw of list.split(',')) {
      const col = raw.trim().split(/\s|:/)[0]
      if (!col || col === '*' || col.startsWith('count')) continue
      if (!columns.get(table)?.has(col)) problems.push(`${file}: ${table} ليس فيه عمود → ${col}`)
    }
  }
  // أعمدة التصفية والترتيب
  for (const m of src.matchAll(/\.(eq|gte|lte|in|order)\('([a-z_]+)'/g)) {
    const near = src.slice(Math.max(0, m.index - 900), m.index)
    const t = [...near.matchAll(/\.from\('([^']+)'\)/g)].pop()?.[1]
    if (!t || !relations.has(t)) continue
    if (!columns.get(t)?.has(m[2])) problems.push(`${file}: ${t} ليس فيه عمود → ${m[2]} (في .${m[1]})`)
  }
}

const unique = [...new Set(problems)]
if (unique.length === 0) console.log('✅ كل جدول وعمود ودالة يطلبها الكود موجودة في القاعدة')
else { console.log(`❌ ${unique.length} مشكلة:`); for (const p of unique) console.log('  •', p) }
await db.close()
// الخروج بصفر مع وجود مشاكل يجعل الاختبار زينةً: مشغّل المجموعة يقرأ رمز
// الخروج لا النصّ، فكان يعلن النجاح وهو يطبع الأخطاء.
process.exit(unique.length === 0 ? 0 : 1)
