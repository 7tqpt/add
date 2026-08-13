/**
 * verify_all.sql — التحقّق الذي يُعطى للمستخدم.
 *
 * الأرقام المتوقَّعة مكتوبة في الملف بخط اليد، فهي أول ما يتقادم: تُضاف سياسة
 * أو دالة فيصير «راجعه» إنذاراً كاذباً يُدرَّب المستخدم على تجاهله. هذا
 * الاختبار يبني القاعدة من الملفات الخمسة ثم يشترط أن يكون كل سطر «سليم».
 */
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'
import assert from 'node:assert/strict'

const db = new PGlite()
const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema auth;
  create table auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role anon; create role authenticated; create role service_role;
`)

// هيكل مصغّر من مخطط التخزين، لأن PGlite لا يحمل الذي تضيفه Supabase.
await db.exec(`
  create schema storage;
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

for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'storage.sql', 'support.sql', 'roles.sql', 'invitations.sql']) {
  await db.exec(read(f))
  console.log(`✓ ${f}`)
}

const { rows } = await db.query(read('verify_all.sql'))
console.log()
const bad = []
for (const row of rows) {
  const label = row['البند']
  const actual = Number(row['الواقع'])
  const expected = Number(row['المتوقع'])
  console.log(
    `${actual === expected ? '✅' : '❌'} ${label.padEnd(30)} ${String(actual).padStart(3)} / ${expected}`,
  )
  if (actual !== expected) bad.push(`${label}: ${actual} بدل ${expected}`)
}

assert.equal(
  bad.length,
  0,
  `الأرقام المتوقَّعة في verify_all.sql تقادمت:\n  ${bad.join('\n  ')}`,
)
console.log('\nكل أسطر التحقّق سليمة — الأرقام في verify_all.sql مطابقة للواقع.')
await db.close()
