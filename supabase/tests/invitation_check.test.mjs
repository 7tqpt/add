/**
 * api_check_invitation — التحقّق من الدعوة قبل إنشاء الحساب.
 *
 * ما يهمّ إثباته ليس أنها تقبل الصحيح، بل أنها **ترفض** كل ما عداه: فدالةٌ
 * تُعيد `true` دائماً تمرّ من اختبار «الرمز الصحيح مقبول» وهي بلا قيمة.
 *
 * وتُختبر بدور `anon` تحديداً — هي الوحيدة في ملف الدعوات الممنوحة له، وهذا
 * هو سطح انكشافها.
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
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql', 'invitations.sql']) {
  await db.exec(read(f))
}

const OWNER = '11111111-1111-1111-1111-111111111111'
await db.exec(`
  insert into auth.users (id, email) values ('${OWNER}', 'owner@aras.ye');
  insert into public.admins (user_id, email, role) values ('${OWNER}', 'owner@aras.ye', 'owner');
`)

const as = async (uid, email, sql) => {
  await db.exec(`set local role authenticated;
    select set_config('request.jwt.claim.sub','${uid}',true),
           set_config('request.jwt.claim.email','${email}',true);`)
  const r = await db.query(sql)
  await db.exec(`reset role;`)
  return r
}

// دعوةٌ حقيقية من المالك.
await db.exec('begin')
const inv = await as(OWNER, 'owner@aras.ye',
  `select * from public.api_invite_admin('mona@aras.ye', 'finance', '')`)
const token = inv.rows[0].token
await db.exec('commit')
console.log(`دعوة: ${token} → mona@aras.ye`)

/** يستدعي الدالة بدور anon — وهو ما تفعله صفحة الدخول قبل وجود جلسة. */
const check = async (t, e) => {
  await db.exec(`begin; set local role anon;`)
  const r = await db.query(`select public.api_check_invitation($1, $2) as ok`, [t, e])
  await db.exec(`commit;`)
  return r.rows[0].ok
}

let failures = 0
const expect = async (label, t, e, want) => {
  const got = await check(t, e)
  const ok = got === want
  if (!ok) failures++
  console.log(`${ok ? '✅' : '❌'} ${label} — ${got}${ok ? '' : ` (المتوقَّع ${want})`}`)
}

console.log('\n=== يقبل الصحيح ===')
await expect('الرمز والبريد صحيحان', token, 'mona@aras.ye', true)
await expect('البريد بأحرف كبيرة — يُقبل', token, 'MONA@ARAS.YE', true)
await expect('الرمز بأحرف صغيرة — يُقبل', token.toLowerCase(), 'mona@aras.ye', true)
await expect('مسافات حول الرمز — تُقلَّم', `  ${token}  `, 'mona@aras.ye', true)

console.log('\n=== يرفض ما عداه ===')
await expect('رمز صحيح ببريد آخر', token, 'someone@else.com', false)
await expect('رمز مخترع', 'DEADBEEF00', 'mona@aras.ye', false)
await expect('رمز فارغ', '', 'mona@aras.ye', false)
await expect('بريد فارغ', token, '', false)
await expect('كلاهما null', null, null, false)

console.log('\n=== لا تلتفّ على الحارس الذي بعدها ===')
await db.exec(`begin`)
const before = await db.query(`select accepted_at from public.admin_invitations where token='${token}'`)
await check(token, 'mona@aras.ye')
const after = await db.query(`select accepted_at from public.admin_invitations where token='${token}'`)
await db.exec(`commit`)
const untouched = before.rows[0].accepted_at === null && after.rows[0].accepted_at === null
if (!untouched) failures++
console.log(`${untouched ? '✅' : '❌'} التحقّق لا يقبل الدعوة ولا يعلّمها مستعملة`)

const admins = await db.query(`select count(*)::int as n from public.admins`)
const noGrant = admins.rows[0].n === 1
if (!noGrant) failures++
console.log(`${noGrant ? '✅' : '❌'} التحقّق لا يمنح دوراً — عدد المسؤولين ما زال ${admins.rows[0].n}`)

console.log('\n=== الدعوة المنتهية والمقبولة ===')
await db.exec(`begin`)
await db.exec(`update public.admin_invitations set expires_at = now() - interval '1 day' where token='${token}'`)
await db.exec(`commit`)
await expect('دعوة منتهية', token, 'mona@aras.ye', false)

await db.exec(`begin`)
await db.exec(`update public.admin_invitations
                  set expires_at = now() + interval '7 days',
                      accepted_at = now(), accepted_by = '${OWNER}'
                where token='${token}'`)
await db.exec(`commit`)
await expect('دعوة مقبولة سابقاً', token, 'mona@aras.ye', false)

if (failures) {
  console.log(`\n❌ ${failures} حالة فشلت.`)
  process.exit(1)
}
console.log('\n🎉 api_check_invitation ترفض كل ما يجب رفضه.')
