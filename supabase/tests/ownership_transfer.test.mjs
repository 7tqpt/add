/**
 * api_transfer_ownership — نقل الملكية.
 *
 * وأهمّ ما يُثبَت هنا ليس أن النقل ينجح، بل أنه **لا رجعة فيه من جهة الناقل**:
 * من نقل الملكية فقد سلطته في اللحظة نفسها، ولا يستطيع أن يستردّها بنداءٍ
 * ثانٍ. فإن أثبتنا النجاح وحده فقد أثبتنا نصف الميزة، وأخطرُ نصفيها هو الآخر.
 *
 * وكذلك: لا تمرّ حالةٌ تكون فيها اللوحة بمالكَين ولا بلا مالك — عدد المُلّاك
 * واحدٌ قبل النقل وبعده وبعد كل محاولةٍ فاشلة.
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
const VIEWER = '33333333-3333-3333-3333-333333333333'
const OUTSIDER = '44444444-4444-4444-4444-444444444444' // حساب مصادقة بلا صفٍّ في admins
await db.exec(`
  insert into auth.users (id, email) values
    ('${OWNER}',    'owner@aras.ye'),
    ('${MANAGER}',  'manager@aras.ye'),
    ('${VIEWER}',   'viewer@aras.ye'),
    ('${OUTSIDER}', 'outsider@aras.ye');
  insert into public.admins (user_id, email, role) values
    ('${OWNER}',   'owner@aras.ye',   'owner'),
    ('${MANAGER}', 'manager@aras.ye', 'manager'),
    ('${VIEWER}',  'viewer@aras.ye',  'viewer');
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

const roleOf = async (uid) =>
  (await db.query(`select role from public.admins where user_id = '${uid}'`)).rows[0]?.role ?? null
const owners = async () =>
  Number((await db.query(`select count(*)::int as n from public.admins where role = 'owner'`)).rows[0].n)

let fail = 0
const check = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

const transfer = (uid, mail, target) =>
  call(uid, mail, `select public.api_transfer_ownership('${target}') as mail`)

console.log('=== المنع ===')

const byManager = await transfer(MANAGER, 'manager@aras.ye', VIEWER)
check('المدير لا ينقل الملكية', !byManager.ok, byManager.msg?.slice(0, 40))
check('ولم يترقَّ المطّلع', (await roleOf(VIEWER)) === 'viewer')

const toSelf = await transfer(OWNER, 'owner@aras.ye', OWNER)
check('المالك لا ينقلها إلى نفسه', !toSelf.ok, toSelf.msg?.slice(0, 40))

const toOutsider = await transfer(OWNER, 'owner@aras.ye', OUTSIDER)
check('ولا إلى حسابٍ ليس مسؤولاً', !toOutsider.ok, toOutsider.msg?.slice(0, 46))

check('والمُلّاك بعد كل محاولةٍ فاشلة: واحد', (await owners()) === 1, `${await owners()}`)
check('والمالك ما زال مالكاً', (await roleOf(OWNER)) === 'owner')

console.log('\n=== النقل ===')
const done = await transfer(OWNER, 'owner@aras.ye', MANAGER)
check('المالك نقلها إلى المدير', done.ok, done.ok ? done.rows[0].mail : done.msg)
check('المدير صار مالكاً', (await roleOf(MANAGER)) === 'owner')
check('والمالك السابق صار مديراً لا مطروداً', (await roleOf(OWNER)) === 'manager')
check('والمُلّاك واحدٌ لا اثنان', (await owners()) === 1, `${await owners()}`)

console.log('\n=== لا رجعة ===')
// أهمّ سطرٍ في الملف: لو نجح هذا لكان «النقل» إعارةً لا نقلاً.
const undo = await transfer(OWNER, 'owner@aras.ye', OWNER)
check('الناقل لا يستردّ الملكية بنفسه', !undo.ok, undo.msg?.slice(0, 40))
check('ولا يزال مديراً', (await roleOf(OWNER)) === 'manager')

// والمالك الجديد يستطيع أن يعيدها — فالباب مفتوحٌ باستئذانه هو، لا بلا إذن.
const back = await transfer(MANAGER, 'manager@aras.ye', OWNER)
check('والمالك الجديد وحده يعيدها', back.ok, back.ok ? '' : back.msg)
check('فعاد الأول مالكاً', (await roleOf(OWNER)) === 'owner')

console.log('\n=== الأثر ===')
const log = await db.query(
  `select actor_email, entity_label, details from public.audit_log
    where action = 'admin.ownership' order by created_at`,
)
check('سُجّل النقلان', log.rows.length === 2, `${log.rows.length} صفّ`)
check('الأول يحمل من ومَن إلى',
  log.rows[0]?.details?.from === 'owner@aras.ye' && log.rows[0]?.details?.to === 'manager@aras.ye',
  JSON.stringify(log.rows[0]?.details))
check('ونُسب إلى الناقل لا إلى المنقول إليه', log.rows[0]?.actor_email === 'owner@aras.ye')

if (fail) {
  console.log(`\n❌ ${fail} حالة فشلت.`)
  process.exit(1)
}
console.log('\n🎉 النقل محصورٌ بالمالك، ذرّيٌّ، ولا رجعة فيه من جهة الناقل.')
