/**
 * خدمة العملاء — بهويات حقيقية بدور `authenticated`.
 *
 * ما يُثبِته:
 *   • العميل يفتح تذكرة ويردّ عليها ويرى تذكرته وحدها.
 *   • عميل آخر لا يرى تذكرة غيره ولا يردّ عليها.
 *   • الملاحظة الداخلية تختفي عن صاحب التذكرة ويراها المسؤول — وهذا أهمّ ما
 *     في الملف: الإخفاء في السياسة لا في الواجهة، فلا يلتفّ حوله استدعاء مباشر.
 *   • ردّ الإدارة يُنشئ إشعاراً لصاحب التذكرة ويضبط زمن أول استجابة.
 *   • ربط التذكرة بحجز لا يخصّ صاحبها مرفوض.
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

for (const f of ['install.sql', 'seed.sql', 'support.sql']) {
  await db.exec(read(f))
  console.log(`✓ ${f}`)
}

const uid = {
  customer: crypto.randomUUID(),
  other: crypto.randomUUID(),
  provider: crypto.randomUUID(),
  admin: crypto.randomUUID(),
}
await db.exec(`
  insert into auth.users (id, email) values
    ('${uid.customer}', 'customer@test.ye'),
    ('${uid.other}',    'other@test.ye'),
    ('${uid.provider}', 'provider@test.ye'),
    ('${uid.admin}',    'admin@test.ye');
  insert into public.admins (user_id, email, role) values ('${uid.admin}', 'admin@test.ye', 'owner');
`)

const as = async (who, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid[who] ?? ''])
  await db.query(`select set_config('request.jwt.claim.email', $1, false)`, [`${who}@test.ye`])
  await db.exec(`set role authenticated`)
  try {
    return await db.query(sql, params)
  } finally {
    await db.exec(`reset role`)
  }
}

let failures = 0
const ok = (label, cond, extra = '') => {
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
  if (!cond) failures++
}
const expectFail = async (label, fn) => {
  try {
    await fn()
    console.log(`❌ ${label} — نجح وكان يجب أن يفشل`)
    failures++
  } catch (e) {
    console.log(`✅ ${label} — مُنع: ${String(e.message).split('\n')[0].slice(0, 50)}`)
  }
}

console.log('\n=== تسجيل الحسابات ===')
await as('customer', `select public.api_register_profile('عميل الدعم', '+967711111111', 'أمانة العاصمة', 'android')`)
await as('other', `select public.api_register_profile('عميل آخر', '+967733333333', 'تعز', 'android')`)
await as('provider', `select public.api_register_profile('مقدّم الدعم', '+967722222222', 'عدن', 'ios')`)

console.log('\n=== فتح تذكرة ===')
const { rows: t } = await as(
  'customer',
  `select * from public.api_open_ticket('الدفع خُصم ولم يصل', 'خُصم المبلغ من محفظتي ولم يظهر في الحجز.', 'payment')`,
)
const ticket = t[0]
ok('فُتحت التذكرة', ticket.status === 'open', ticket.reference)
ok('الرقم المرجعي بصيغة SUP', /^SUP-\d{4}-[A-Z0-9]{6}$/.test(ticket.reference), ticket.reference)
ok('اسم صاحبها محفوظ', ticket.user_name === 'عميل الدعم', ticket.user_name)

const { rows: firstMsg } = await as('customer', `select * from public.support_messages where ticket_id=$1`, [ticket.id])
ok('نصّ الشكوى صار أول رسالة', firstMsg.length === 1 && firstMsg[0].author === 'customer')

await expectFail('تذكرة بلا نص', () =>
  as('customer', `select public.api_open_ticket('موضوع', '   ')`))

console.log('\n=== العزل بين الحسابات ===')
const { rows: mine } = await as('customer', `select count(*)::int n from public.support_tickets`)
ok('صاحبها يراها', mine[0].n === 1)
const { rows: theirs } = await as('other', `select count(*)::int n from public.support_tickets`)
ok('عميل آخر لا يرى شيئاً', theirs[0].n === 0, `يرى ${theirs[0].n}`)
await expectFail('عميل آخر يردّ على تذكرة غيره', () =>
  as('other', `select public.api_reply_ticket($1, 'أنا أتطفّل')`, [ticket.id]))

console.log('\n=== الملاحظة الداخلية ===')
await as('admin', `select public.admin_reply_ticket($1, 'راجعنا سجل البوابة ولم نجد الخصم — عميل متكرّر', true)`, [ticket.id])
const { rows: ownerSees } = await as('customer', `select count(*)::int n from public.support_messages where ticket_id=$1`, [ticket.id])
ok('صاحب التذكرة لا يرى الملاحظة الداخلية', ownerSees[0].n === 1, `يرى ${ownerSees[0].n} رسالة`)
const { rows: adminSees } = await as('admin', `select count(*)::int n from public.support_messages where ticket_id=$1`, [ticket.id])
ok('المسؤول يراها', adminSees[0].n === 2, `يرى ${adminSees[0].n}`)

const { rows: stillOpen } = await as('admin', `select status, first_response_at from public.support_tickets where id=$1`, [ticket.id])
ok('الملاحظة الداخلية لا تحرّك الحالة', stillOpen[0].status === 'open', stillOpen[0].status)
ok('ولا تُحتسب أول استجابة', stillOpen[0].first_response_at === null)

console.log('\n=== ردّ الإدارة ===')
await as('admin', `select public.admin_reply_ticket($1, 'راجعنا العملية وسيُعاد المبلغ خلال ٤٨ ساعة.')`, [ticket.id])
const { rows: afterReply } = await as('admin', `select * from public.support_tickets where id=$1`, [ticket.id])
ok('الحالة صارت بانتظار العميل', afterReply[0].status === 'waiting_customer', afterReply[0].status)
ok('سُجّل زمن أول استجابة', afterReply[0].first_response_at !== null)

const { rows: seen } = await as('customer', `select body from public.support_messages where ticket_id=$1 order by created_at`, [ticket.id])
ok('صاحب التذكرة يرى ردّ الإدارة وحده', seen.length === 2, `${seen.length} رسالة`)

const { rows: notif } = await as('customer', `select count(*)::int n from public.notifications where data->>'ticket_id' = $1`, [ticket.id])
ok('وصله إشعار بالردّ', notif[0].n === 1)

console.log('\n=== ردّ العميل يعيدها للإدارة ===')
await as('customer', `select public.api_reply_ticket($1, 'شكراً، بانتظار التحويل.')`, [ticket.id])
const { rows: reopened } = await as('admin', `select status from public.support_tickets where id=$1`, [ticket.id])
ok('عادت مفتوحة', reopened[0].status === 'open', reopened[0].status)

console.log('\n=== الحجز المرتبط ===')
const { rows: foreign } = await db.query(`select id from public.bookings limit 1`)
await expectFail('ربط التذكرة بحجز لا يخصّ صاحبها', () =>
  as('customer', `select public.api_open_ticket('سؤال', 'نص', 'booking', $1)`, [foreign[0].id]))

console.log('\n=== تذكرة مقدّم الخدمة ===')
const { rows: cats } = await db.query(`select id from public.service_categories where slug='halls'`)
await as('provider', `select public.api_apply_as_provider('قاعة الدعم','+967722222222','خبرة','عدن', array['${cats[0].id}']::uuid[])`)
const { rows: pt } = await as(
  'provider',
  `select * from public.api_open_ticket('لا أستطيع رفع مستنداتي', 'الرفع يفشل دائماً.', 'technical', null, true)`,
)
ok('مقدّم الخدمة يفتح تذكرة باسم منشأته', pt[0].opened_by === 'provider', pt[0].provider_name)
const { rows: notCustomer } = await as('customer', `select count(*)::int n from public.support_tickets`)
ok('العميل لا يرى تذكرة مقدّم الخدمة', notCustomer[0].n === 1, `يرى ${notCustomer[0].n}`)

console.log('\n=== الإغلاق ===')
await as('customer', `select public.api_close_ticket($1)`, [ticket.id])
const { rows: closed } = await as('admin', `select status, resolved_at from public.support_tickets where id=$1`, [ticket.id])
ok('أُغلقت وسُجّل وقتها', closed[0].status === 'closed' && closed[0].resolved_at !== null)
await expectFail('الردّ على تذكرة مغلقة', () =>
  as('customer', `select public.api_reply_ticket($1, 'رسالة متأخرة')`, [ticket.id]))

console.log('\n=== طريقة عرض اللوحة ===')
const { rows: view } = await as('admin', `select * from public.v_admin_tickets order by created_at`)
ok('تعرض التذاكر كلها للمسؤول', view.length === 2, `${view.length}`)
ok('فيها اسم صاحب التذكرة', view[0].requester_name === 'عميل الدعم', view[0].requester_name)
ok('وعدد الرسائل بلا الداخلية', view[0].messages_count === 3, `${view[0].messages_count}`)
const { rows: viewOther } = await as('other', `select count(*)::int n from public.v_admin_tickets`)
ok('ولا تسرّب شيئاً لغير أصحابها', viewOther[0].n === 0, `يرى ${viewOther[0].n}`)

console.log(failures === 0 ? '\n🎉 كل اختبارات الدعم نجحت.' : `\n❌ ${failures} فشل`)
await db.close()
process.exit(failures === 0 ? 0 : 1)
