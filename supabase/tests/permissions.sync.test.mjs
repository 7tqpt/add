/**
 * مصفوفة الصلاحيات مكتوبة مرتين: في `roles.sql` لأن RLS تحتاجها، وفي
 * `src/lib/permissions.ts` لأن الواجهة تحتاج أن تعرف قبل الطلب ماذا تُخفي.
 *
 * التكرار مقصود، وخطره أن يتباعد الطرفان: تُوسَّع صلاحية في SQL فتبقى الواجهة
 * تُخفي الزرّ، أو — وهو الأسوأ — تُضيَّق في SQL فتبقى الواجهة تعرضه فيضغطه
 * المستخدم ويرتدّ عليه الطلب بخطأ لا يفهمه.
 *
 * هذا الاختبار يبني القاعدة، يقرأ الجدول منها، ويقارنه بالملف خانةً بخانة.
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
  create role anon; create role authenticated;
`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql']) {
  await db.exec(read(f))
}

const { rows } = await db.query(`select role, area, level from public.admin_areas`)
const fromSql = new Map(rows.map((r) => [`${r.role}|${r.area}`, r.level]))

// يُقرأ الملف نصّاً: استيراد TypeScript يحتاج بناءً، والاختبار يجب أن يعمل وحده.
const ts = readFileSync(new URL('../../src/lib/permissions.ts', import.meta.url), 'utf8')
const body = ts.slice(ts.indexOf('ROLE_AREAS'), ts.indexOf('export function levelOf'))

const fromTs = new Map()
for (const block of body.matchAll(/(\w+):\s*\{([^}]*)\}/g)) {
  const role = block[1]
  for (const pair of block[2].matchAll(/(\w+):\s*'(none|read|write)'/g)) {
    fromTs.set(`${role}|${pair[1]}`, pair[2])
  }
}

assert.ok(fromTs.size > 0, 'لم يُقرأ شيء من permissions.ts — تغيّر شكل الملف')
console.log(`قُرئ ${fromSql.size} خانة من SQL و ${fromTs.size} من TypeScript`)

const problems = []
for (const [key, level] of fromSql) {
  const mirror = fromTs.get(key)
  if (mirror === undefined) problems.push(`${key}: مفقودة من permissions.ts`)
  else if (mirror !== level) problems.push(`${key}: SQL=${level} بينما TS=${mirror}`)
}
for (const key of fromTs.keys()) {
  if (!fromSql.has(key)) problems.push(`${key}: في permissions.ts ولا وجود لها في roles.sql`)
}

if (problems.length > 0) {
  console.log(`❌ ${problems.length} اختلاف:`)
  for (const p of problems) console.log('  •', p)
}
assert.equal(problems.length, 0, 'المصفوفتان تباعدتا')

console.log('✅ المصفوفتان متطابقتان خانةً بخانة')
await db.close()
