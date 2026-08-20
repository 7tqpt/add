/**
 * دعوات الموظفين — بهويات حقيقية.
 *
 * الشرطان اللذان تقوم عليهما الدعوة يُفحصان منفصلين: رمزٌ صحيح ببريد آخر
 * يُرفض، وبريدٌ صحيح برمز آخر يُرفض. ولو مرّ أحدهما لصار تسريب الرمز كافياً
 * لدخول اللوحة.
 */
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema auth;
  create table auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid;
  $$;
  create role anon;
  create role authenticated;
`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql', 'invitations.sql']) {
  await db.exec(read(f))
  console.log(`✓ ${f}`)
}

const uid = {
  owner: crypto.randomUUID(),
  manager: crypto.randomUUID(),
  newbie: crypto.randomUUID(),
  stranger: crypto.randomUUID(),
}
const mail = {
  owner: 'owner@test.ye',
  manager: 'manager@test.ye',
  newbie: 'newbie@test.ye',
  stranger: 'stranger@test.ye',
}
for (const key of Object.keys(uid)) {
  await db.query(`insert into auth.users (id, email) values ($1, $2)`, [uid[key], mail[key]])
}
await db.query(`insert into public.admins (user_id, email, role) values ($1, $2, 'owner')`, [uid.owner, mail.owner])
await db.query(`insert into public.admins (user_id, email, role) values ($1, $2, 'manager')`, [uid.manager, mail.manager])

// المعرّف وحده يُضبط — لا بريد.
//
// كان هذا السطر يضبط `request.jwt.claim.email` أيضاً، فكانت الدالة تجده
// وتنجح هنا وتفشل على قاعدةٍ حقيقية: Supabase الحالية لا تضبط ذلك الإعداد،
// فيخرج فارغاً فتُرفض كلُّ دعوة. أي أن الاختبار كان يختبر افتراضي لا الواقع،
// وهو أسوأ من ألّا يكون اختبارٌ أصلاً — لأنه يطمئن.
//
// فيُترك الآن كما تتركه المنصّة، وتقرأ الدالةُ البريدَ من `auth.users`.
const as = async (who, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid[who] ?? ''])
  await db.exec(`set role authenticated`)
  try {
    return await db.query(sql, params)
  } finally {
    await db.exec(`reset role`)
  }
}

let failures = 0
const ok = (label, cond, extra = '') => {
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ` — ${extra}` : ''}`)
  if (!cond) failures++
}
const expectFail = async (label, fn) => {
  try {
    await fn()
    console.log(`❌ ${label} — نجح وكان يجب أن يفشل`)
    failures++
  } catch (e) {
    console.log(`✅ ${label} — مُنع: ${String(e.message).split('\n')[0].slice(0, 46)}`)
  }
}

console.log('\n=== إنشاء الدعوة ===')
await expectFail('مدير يدعو موظفاً', () =>
  as('manager', `select public.api_invite_admin($1, 'support')`, [mail.newbie]))

const { rows: inv } = await as('owner', `select * from public.api_invite_admin($1, 'support', 'موظف خدمة عملاء')`, [mail.newbie])
const invitation = inv[0]
ok('المالك ينشئ الدعوة', invitation.role === 'support', invitation.email)
ok('الرمز عشر خانات', /^[A-Z0-9]{10}$/.test(invitation.token), invitation.token)
ok('تنتهي بعد أسبوع', new Date(invitation.expires_at) > new Date(), '')
ok('مسجَّل من دعا', invitation.invited_by === mail.owner, invitation.invited_by)

await expectFail('دعوة ببريد غير صالح', () =>
  as('owner', `select public.api_invite_admin('لا-بريد', 'support')`))
await expectFail('دعوة بدور غير معروف', () =>
  as('owner', `select public.api_invite_admin($1, 'superuser')`, ['x@y.ye']))
await expectFail('دعوة لمن هو مسؤول أصلاً', () =>
  as('owner', `select public.api_invite_admin($1, 'viewer')`, [mail.manager]))

// ── لماذا رُدّ الواقف أمام الشاشة؟ ─────────────────────────────────────────
// الفرق بين «دعوةٌ تنتظر رمزك» و«لا دعوة لبريدك» هو ما يفصل من نسي الرمز
// عمّن دخل بالحساب الخطأ. وقد كلّف خلطُهما جولتين حقيقيتين.
console.log('\n=== أعندي دعوة؟ ===')
{
  const invited = await as('newbie', `select public.api_my_invitation() as role`)
  ok('المدعوّ يرى دوره المنتظِر', invited.rows[0].role === 'support',
     `${invited.rows[0].role}`)

  const stranger = await as('stranger', `select public.api_my_invitation() as role`)
  ok('ومن لا دعوة له يرى فراغاً لا دوراً', stranger.rows[0].role === null,
     `${stranger.rows[0].role}`)
}

console.log('\n=== الشرطان معاً ===')
// الرمز وحده لا يكفي: من سُرّب إليه لا يستطيع استعماله ببريده هو.
await expectFail('غريب يستعمل الرمز ببريده', () =>
  as('stranger', `select public.api_accept_invitation($1)`, [invitation.token]))
// والبريد وحده لا يكفي: المدعوّ نفسه برمز خاطئ يُرفض.
await expectFail('المدعوّ برمز خاطئ', () =>
  as('newbie', `select public.api_accept_invitation('WRONGTOKEN')`))

const { rows: stillNone } = await db.query(`select count(*)::int n from public.admins`)
ok('لم يُضَف أحد بعد المحاولتين', stillNone[0].n === 2, `${stillNone[0].n}`)

console.log('\n=== القبول ===')
const { rows: got } = await as('newbie', `select public.api_accept_invitation($1) as role`, [invitation.token])
ok('المدعوّ يقبل فيُمنح دوره', got[0].role === 'support', got[0].role)

const { rows: row } = await db.query(`select role, email from public.admins where user_id = $1`, [uid.newbie])
ok('صار له صفّ في admins', row.length === 1 && row[0].role === 'support')

const { rows: perms } = await as('newbie', `select public.can_write_area('support') as s, public.can_read_area('finance') as f`)
ok('يكتب في التذاكر', perms[0].s === true)
ok('ولا يرى المال', perms[0].f === false)

{
  const after = await as('newbie', `select public.api_my_invitation() as role`)
  ok('ومن قَبِل لا تبقى له دعوةٌ منتظِرة', after.rows[0].role === null,
     `${after.rows[0].role}`)
}

console.log('\n=== لا تُستعمل مرتين ===')
await expectFail('إعادة استعمال الرمز نفسه', () =>
  as('newbie', `select public.api_accept_invitation($1)`, [invitation.token]))

const { rows: fresh } = await as('owner', `select * from public.api_invite_admin($1, 'viewer')`, [mail.stranger])
const secondToken = fresh[0].token
await expectFail('من صار مسؤولاً يقبل دعوةً أخرى', () =>
  as('newbie', `select public.api_accept_invitation($1)`, [secondToken]))

console.log('\n=== الدعوة المنتهية ===')
await db.query(`update public.admin_invitations set expires_at = now() - interval '1 day' where token = $1`, [secondToken])
await expectFail('دعوة منتهية', () =>
  as('stranger', `select public.api_accept_invitation($1)`, [secondToken]))

console.log('\n=== من يرى الدعوات ===')
const { rows: ownerSees } = await as('owner', `select count(*)::int n from public.v_admin_invitations`)
ok('المالك يرى الدعوات', ownerSees[0].n === 2, `${ownerSees[0].n}`)
const { rows: managerSees } = await as('manager', `select count(*)::int n from public.v_admin_invitations`)
// الرمز في الصف، فمن قرأ الصف قرأ الرمز — ودعوةٌ بدور «مالك» تصير مفتاحاً.
ok('المدير لا يرى الدعوات ولا رموزها', managerSees[0].n === 0, `يرى ${managerSees[0].n}`)
const { rows: newbieSees } = await as('newbie', `select count(*)::int n from public.v_admin_invitations`)
ok('الموظف الجديد لا يراها', newbieSees[0].n === 0, `يرى ${newbieSees[0].n}`)

console.log(failures === 0 ? '\n🎉 كل اختبارات الدعوات نجحت.' : `\n❌ ${failures} فشل`)
await db.close()
process.exit(failures === 0 ? 0 : 1)
