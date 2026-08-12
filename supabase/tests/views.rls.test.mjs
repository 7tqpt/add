// طريقة عرض بلا security_invoker تعمل بصلاحيات مالكها فتلتفّ حول RLS.
// هذا الفحص يثبت أن العميل لا يرى عبر v_admin_* ما تمنعه السياسات.
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

const db = new PGlite()
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role authenticated; create role anon; create role service_role;`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql']) {
  await db.exec(readFileSync(`../${f}`, 'utf8'))
}

const views = ['v_admin_providers','v_admin_services','v_admin_settlements',
               'v_admin_reviews','v_admin_subscription_plans','v_admin_promotions','v_plan_summary']

const bad = await db.query(`
  select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname='public' and c.relkind='v' and c.relname = any($1)
     and coalesce((select option_value from pg_options_to_table(c.reloptions)
                    where option_name='security_invoker'), 'false') <> 'true'`, [views])
console.log(bad.rows.length === 0
  ? '✅ كل طرق العرض تعمل بصلاحيات المستدعي'
  : `❌ بلا security_invoker: ${bad.rows.map(r => r.relname).join(', ')}`)

await db.exec(`set role anon`)
const leaked = await db.query('select count(*)::int as n from public.v_admin_settlements')
await db.exec('reset role')
console.log(leaked.rows[0].n === 0
  ? '✅ المجهول لا يرى مستحقات الشركاء عبر طريقة العرض'
  : `❌ تسرّب: المجهول رأى ${leaked.rows[0].n} تسوية`)
await db.close()
