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
const r = await db.query(readFileSync('verify.sql', 'utf8'))
for (const row of r.rows) console.log(`${row['البند'].padEnd(34)} ${row['العدد'].padStart(4)}   (المتوقع ${row['المتوقع']})`)
await db.close()
