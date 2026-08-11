// يتحقق أن install.sql يُنفَّذ على Postgres حقيقي من أول مرة ومن ثانية.
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

const sql = readFileSync('../install.sql', 'utf8')
const db = new PGlite()

// PGlite ليس فيه schema اسمه auth، والملف يشير إليه في مفاتيح أجنبية.
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role authenticated;
  create role anon;
  create role service_role;
`)

await db.exec(sql)
console.log('✅ install.sql نُفِّذ كاملاً')

await db.exec(sql)
console.log('✅ إعادة التنفيذ لا تكسر شيئاً')

const t = await db.query(`select count(*)::int as n from information_schema.tables
                          where table_schema = 'public' and table_type = 'BASE TABLE'`)
const f = await db.query(`select count(*)::int as n from information_schema.routines
                          where routine_schema = 'public' and routine_name like 'api\\_%'`)
console.log(`✅ ${t.rows[0].n} جدولاً و ${f.rows[0].n} دالة api_*`)
await db.close()
