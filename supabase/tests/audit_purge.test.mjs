/**
 * api_clear_audit_log — تفريغ السجل للمالك وحده.
 *
 * وما يهمّ إثباته ثلاثة، وأوّلها أهمّها:
 *   ١. غير المالك يُمنع — ولو كان مسؤولاً بصلاحيات واسعة.
 *   ٢. الجدول يبقى بلا سياسة حذف، فلا يُمحى صفٌّ بعينه من خارج الدالة.
 *   ٣. التفريغ يُخلّف أثره: صفٌّ يقول من فرّغ وكم أزال.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon; create role authenticated;
`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql']) {
  await db.exec(read(f))
}

const OWNER = '11111111-1111-1111-1111-111111111111'
const MANAGER = '22222222-2222-2222-2222-222222222222'
await db.exec(`
  insert into auth.users (id, email) values
    ('${OWNER}', 'owner@aras.ye'), ('${MANAGER}', 'manager@aras.ye');
  insert into public.admins (user_id, email, role) values
    ('${OWNER}', 'owner@aras.ye', 'owner'),
    ('${MANAGER}', 'manager@aras.ye', 'manager');
  insert into public.audit_log (actor_email, action, entity, entity_label) values
    ('manager@aras.ye', 'provider.approve', 'service_providers', 'مطابخ اللؤلؤة'),
    ('manager@aras.ye', 'payment.refund', 'payments', 'TRX-2026-000114'),
    ('owner@aras.ye',   'settings.update', 'app_settings', 'إعدادات التطبيق');
`)

const call = async (uid, mail, sql) => {
  await db.exec(`begin; set local role authenticated;
    select set_config('request.jwt.claim.sub','${uid}',true),
           set_config('request.jwt.claim.email','${mail}',true);`)
  try {
    const r = await db.query(sql)
    await db.exec('commit;')
    return { ok: true, rows: r.rows }
  } catch (e) {
    await db.exec('rollback;')
    return { ok: false, msg: e.message }
  }
}

const count = async () =>
  Number((await db.query('select count(*)::int as n from public.audit_log')).rows[0].n)

let fail = 0
const check = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

console.log(`السجل قبل: ${await count()} صفوف\n=== المنع ===`)

const asManager = await call(MANAGER, 'manager@aras.ye', 'select public.api_clear_audit_log()')
check('المدير — مُنع', !asManager.ok, asManager.msg?.slice(0, 46))
check('ولم يُحذف شيء', (await count()) === 3, `${await count()} صفوف`)

// الحذف المباشر يجب أن يُمنع كذلك: لا سياسة delete على الجدول أصلاً.
const direct = await call(OWNER, 'owner@aras.ye', `delete from public.audit_log`)
const afterDirect = await count()
check('حتى المالك لا يحذف صفّاً مباشرةً', afterDirect === 3, `${afterDirect} صفوف`)

console.log('\n=== التفريغ ===')
const purge = await call(OWNER, 'owner@aras.ye', 'select public.api_clear_audit_log() as n')
check('المالك — نجح', purge.ok, purge.ok ? `أزال ${purge.rows[0].n}` : purge.msg)
check('أعاد العدد الصحيح', purge.ok && purge.rows[0].n === 3)

console.log('\n=== الأثر يبقى ===')
const left = await db.query(`select actor_email, action, details from public.audit_log`)
check('السجل ليس فارغاً بعد التفريغ', left.rows.length === 1, `${left.rows.length} صفّ`)
check('الصفّ الباقي هو التفريغ نفسه', left.rows[0]?.action === 'audit.purge')
check('ويحمل من فرّغ', left.rows[0]?.actor_email === 'owner@aras.ye')
check('وكم أزال', left.rows[0]?.details?.removed === 3, JSON.stringify(left.rows[0]?.details))

if (fail) {
  console.log(`\n❌ ${fail} حالة فشلت.`)
  process.exit(1)
}
console.log('\n🎉 التفريغ محصورٌ بالمالك، ويُخلّف أثره.')
