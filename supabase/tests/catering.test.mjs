// يتحقق أن الإضافة تعمل على قاعدة مزروعة، وأن إعادة تشغيلها لا تكرّر ولا تخلّ بالترتيب.
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

const db = new PGlite()
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role authenticated; create role anon; create role service_role;`)
await db.exec(readFileSync('../install.sql', 'utf8'))

// نزرع النسخة القديمة (بلا الطبخ) لنحاكي قاعدة المستخدم القائمة
const seed = readFileSync('../seed.sql', 'utf8')
const without = seed.replace(/\n  \('الطبخ والضيافة'[\s\S]*?::jsonb\),\n/, '\n')
await db.exec(without)

const before = await db.query(`select count(*)::int as n from public.service_categories`)
console.log(`قبل: ${before.rows[0].n} قسماً`)

const patch = readFileSync('../apply.sql', 'utf8')
await db.exec(patch)
await db.exec(patch)   // مرة ثانية عمداً

const rows = await db.query(`select sort_order, name, slug from public.service_categories order by sort_order`)
console.log(`بعد: ${rows.rows.length} قسماً`)
for (const r of rows.rows) console.log(`  ${String(r.sort_order).padStart(2)} · ${r.name}`)

const orders = rows.rows.map(r => r.sort_order)
const unique = new Set(orders).size === orders.length
const sequential = orders.every((o, i) => o === i + 1)
console.log(unique ? '✅ لا ترتيب مكرّر' : '❌ ترتيب مكرّر')
console.log(sequential ? '✅ الترتيب متسلسل 1..n' : `❌ الترتيب غير متسلسل: ${orders.join(',')}`)
await db.close()
