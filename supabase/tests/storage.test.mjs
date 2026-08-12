/**
 * storage.sql — الحاوية وسياساتها.
 *
 * PGlite لا يحمل مخطط `storage` الذي تضيفه Supabase، فيُبنى هنا هيكلٌ مصغّر
 * منه: جدول الحاويات، وجدول الكائنات، ودالة foldername. هذا لا يحاكي سلوك
 * Supabase، لكنه يُشغّل الملف على Postgres حقيقي — وهو ما يكشف ما لا تكشفه
 * القراءة: خطأ نحوي، أو اسم دالة غير موجود.
 *
 * والثانية ليست فرضية: أول صياغة للسياسات قارنت
 * `service_providers.user_id` بـ `auth.uid()`، وهما لا يقعان في نفس الفضاء —
 * العمود يشير إلى `app_users` لا إلى `auth.users`. الشرط كان سيبقى صامتاً
 * ويمنع كل رفع.
 */
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'
import assert from 'node:assert/strict'

const db = new PGlite()

await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon;
  create role authenticated;
`)
await db.exec(readFileSync('../install.sql', 'utf8'))

// هيكل مصغّر من مخطط التخزين
await db.exec(`
  create schema if not exists storage;
  create table storage.buckets (
    id text primary key, name text not null, public boolean not null default false,
    file_size_limit bigint, allowed_mime_types text[]
  );
  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id), name text not null, owner uuid
  );
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;
`)

const sql = readFileSync('../storage.sql', 'utf8')
await db.exec(sql)
console.log('✓ storage.sql يعمل على Postgres')

// إعادة التشغيل لا تكسر شيئاً ولا تكرّر سياسة
await db.exec(sql)
console.log('✓ التشغيل مرتين آمن')

const bucket = (await db.query(`select public, file_size_limit from storage.buckets where id = 'provider-docs'`)).rows
assert.equal(bucket.length, 1, 'الحاوية لم تُنشأ')
assert.equal(bucket[0].public, false, '⚠️ الحاوية عامة — صور الهويات تُفتح بلا تسجيل دخول')
console.log('✓ الحاوية موجودة وخاصة')

const policies = (await db.query(
  `select policyname, cmd from pg_policies
    where schemaname = 'storage' and tablename = 'objects' order by policyname`)).rows
assert.equal(policies.length, 4, `عدد السياسات ${policies.length} لا 4`)
const cmds = policies.map((p) => `${p.policyname}:${p.cmd}`)
assert.ok(cmds.some((c) => c.startsWith('provider uploads') && c.endsWith('INSERT')), cmds.join(' | '))
assert.ok(cmds.some((c) => c.startsWith('admin reads') && c.endsWith('SELECT')), cmds.join(' | '))
console.log(`✓ ${policies.length} سياسات: ${policies.map((p) => p.policyname).join('، ')}`)

// الدوال التي تستند إليها السياسات موجودة فعلاً بهذه الأسماء
for (const fn of ['current_provider', 'is_admin']) {
  const { rows } = await db.query(
    `select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = $1`, [fn])
  assert.equal(rows.length, 1, `public.${fn}() غير موجودة — السياسات تشير إلى اسم خاطئ`)
}
console.log('✓ الدوال المستعملة في السياسات موجودة')

await db.close()
console.log('\nكل اختبارات storage.sql نجحت.')
