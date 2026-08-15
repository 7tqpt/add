/**
 * api_delete_admin_account — حذف حساب موظف حذفاً تامّاً.
 *
 * وأهمّ ما يُثبَت هنا رفضٌ لا نجاح: **من له بياناتٌ في التطبيق لا يُحذف**.
 * لأن `auth.users` يتسلسل إلى `app_users` ومنها إلى اثني عشر جدولاً فيها
 * الحجوزات والخطط. فزرٌّ اسمه «حذف موظف» يمحو حجوزات عريسٍ بالخطأ هو أسوأ
 * ما يمكن أن نضعه في لوحة، ولا أحد يربط بين الفعل وأثره حين يقع.
 *
 * ويُثبَت كذلك أن الفشل لا يترك نصف عمل: الأثر يُكتب داخل المعاملة، فإن
 * تراجعت تراجع معها.
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
const STAFF = '22222222-2222-2222-2222-222222222222'
const GROOM = '33333333-3333-3333-3333-333333333333' // موظفٌ هو عريسٌ أيضاً
const OTHER = '44444444-4444-4444-4444-444444444444'
await db.exec(`
  insert into auth.users (id, email) values
    ('${OWNER}', 'owner@aras.ye'), ('${STAFF}', 'staff@aras.ye'),
    ('${GROOM}', 'groom@aras.ye'), ('${OTHER}', 'other@aras.ye');
  insert into public.admins (user_id, email, role) values
    ('${OWNER}', 'owner@aras.ye', 'owner'),
    ('${STAFF}', 'staff@aras.ye', 'support'),
    ('${GROOM}', 'groom@aras.ye', 'finance'),
    ('${OTHER}', 'other@aras.ye', 'viewer');

  -- الموظف الثالث عميلٌ على التطبيق وله خطة عرسٍ وحجز
  insert into public.app_users (auth_user_id, full_name, email)
    values ('${GROOM}', 'العريس', 'groom@aras.ye');
  insert into public.wedding_plans (user_id, title, wedding_date)
    select id, 'خطة العرس', current_date + 60 from public.app_users
     where auth_user_id = '${GROOM}';

  -- وللموظف الأول دعوةٌ مقبولة، يجب أن تُمحى معه
  insert into public.admin_invitations (email, role, token, invited_by, accepted_at, accepted_by)
    values ('staff@aras.ye', 'support', 'ABC1234567', 'owner@aras.ye', now(), '${STAFF}');
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

const one = async (sql) => Number((await db.query(sql)).rows[0].n)
const authUsers = () => one('select count(*)::int as n from auth.users')
const admins = () => one('select count(*)::int as n from public.admins')
// خططه هو وحده: seed.sql يزرع خططاً كثيرة، فالعدد الكلّي لا يقيس شيئاً.
const groomPlans = () =>
  one(`select count(*)::int as n from public.wedding_plans p
        join public.app_users u on u.id = p.user_id
       where u.auth_user_id = '${GROOM}'`)

let fail = 0
const check = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

const del = (uid, mail, target) =>
  call(uid, mail, `select public.api_delete_admin_account('${target}') as mail`)

console.log(`قبل: ${await authUsers()} حسابات، ${await admins()} مسؤولين\n=== المنع ===`)

const byStaff = await del(STAFF, 'staff@aras.ye', OTHER)
check('الموظف لا يحذف زميله', !byStaff.ok, byStaff.msg?.slice(0, 40))

const self = await del(OWNER, 'owner@aras.ye', OWNER)
check('والمالك لا يحذف نفسه', !self.ok, self.msg?.slice(0, 44))

console.log('\n=== الحارس الذي يمنع الكارثة ===')
const groom = await del(OWNER, 'owner@aras.ye', GROOM)
check('من له بياناتٌ في التطبيق لا يُحذف', !groom.ok, groom.msg?.slice(0, 58))
check('وخطة عرسه سليمة', (await groomPlans()) === 1, `${await groomPlans()} خطة له`)
check('وحسابه قائم', (await authUsers()) === 4, `${await authUsers()} حسابات`)

console.log('\n=== الحذف ===')
const done = await del(OWNER, 'owner@aras.ye', STAFF)
check('المالك حذف الموظف', done.ok, done.ok ? done.rows[0].mail : done.msg)
check('زال من المسؤولين', (await admins()) === 3, `${await admins()}`)
check('وزال حسابه من المصادقة', (await authUsers()) === 3, `${await authUsers()}`)
check('ومُحيت دعوته معه',
  (await one(`select count(*)::int as n from public.admin_invitations
               where lower(email) = 'staff@aras.ye'`)) === 0)

console.log('\n=== الأثر ===')
const log = await db.query(
  `select actor_email, entity_label, details from public.audit_log
    where action = 'admin.delete_account'`,
)
check('سُجّل حذفٌ واحدٌ لا أكثر', log.rows.length === 1, `${log.rows.length} صفّ`)
check('وهو للموظف المحذوف وحده', log.rows[0]?.entity_label === 'staff@aras.ye')
check('ولم يُسجَّل حذف العريس المرفوض',
  !log.rows.some((r) => r.entity_label === 'groom@aras.ye'))

if (fail) {
  console.log(`\n❌ ${fail} حالة فشلت.`)
  process.exit(1)
}
console.log('\n🎉 الحذف للمالك وحده، ويقف عند من له بياناتٌ في التطبيق.')
