import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

// Stub what Supabase provides: auth.users, auth.uid(), and the anon/authenticated roles.
await db.exec(`
  create schema auth;
  create table auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid;
  $$;
  do $$ begin
    if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
    if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  end $$;
`)

for (const f of ['schema.sql', 'policies.sql', 'api.sql', 'seed.sql']) {
  try {
    await db.exec(read(f))
    console.log(`✅ ${f}`)
  } catch (e) {
    console.log(`❌ ${f}: ${e.message}`)
    process.exit(1)
  }
}

// ---- identities -------------------------------------------------------------
const uid = { customer: crypto.randomUUID(), provider: crypto.randomUUID(), admin: crypto.randomUUID() }
await db.exec(`
  insert into auth.users (id, email) values
    ('${uid.customer}', 'customer@test.ye'),
    ('${uid.provider}', 'provider@test.ye'),
    ('${uid.admin}',    'admin@test.ye');
  insert into public.admins (user_id, email, role) values ('${uid.admin}', 'admin@test.ye', 'owner');
`)

// is_local=false so the identity survives across statements (each query is its
// own transaction here, exactly like separate requests from an app).
// Requests arrive as the `authenticated` role, not as the table owner —
// Postgres exempts owners from RLS, so testing as owner would prove nothing.
const as = async (who, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid[who] ?? ''])
  await db.exec(`set role authenticated`)
  try {
    return await db.query(sql, params)
  } finally {
    await db.exec(`reset role`)
  }
}
const expectFail = async (label, fn) => {
  try { await fn(); console.log(`❌ ${label} — نجح وكان يجب أن يفشل`); failures++ }
  catch (e) { console.log(`✅ ${label} — مُنع: ${String(e.message).split('\n')[0].slice(0, 55)}`) }
}
let failures = 0
const ok = (label, cond, extra = '') => {
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
  if (!cond) failures++
}

console.log('\n=== تسجيل الحسابات ===')
await as('customer', `select public.api_register_profile('عميل تجريبي', '+967711111111', 'أمانة العاصمة', 'android') as u`)
await as('provider', `select public.api_register_profile('مقدّم تجريبي', '+967722222222', 'عدن', 'ios') as u`)
const { rows: cu } = await as('customer', `select public.current_app_user() as id`)
ok('العميل مرتبط بحسابه', cu[0].id !== null)

console.log('\n=== التقديم كمقدّم خدمة ===')
const { rows: cat } = await db.query(`select id from public.service_categories where slug='halls'`)
await as('provider', `select public.api_apply_as_provider('قاعة الاختبار','+967722222222','خبرة','عدن', array['${cat[0].id}']::uuid[]) as p`)
const { rows: pstat } = await as('provider', `select status from public.service_providers where user_id = public.current_app_user()`)
ok('الحساب يبدأ قيد المراجعة', pstat[0].status === 'pending', pstat[0].status)

await expectFail('مقدّم الخدمة يوثّق نفسه', () =>
  as('provider', `update public.service_providers set status='verified', verified_at=now() where user_id = public.current_app_user()`))

console.log('\n=== الإدارة توثّقه ===')
await as('admin', `update public.service_providers set status='verified', verified_at=now() where user_id = (select id from public.app_users where auth_user_id='${uid.provider}')`)
const { rows: pv } = await as('provider', `select public.is_verified_provider() as v`)
ok('صار موثّقاً', pv[0].v === true)

console.log('\n=== نشر خدمة ثم الحجز ===')
const { rows: pid } = await as('provider', `select public.current_provider() as id`)
const { rows: pol } = await db.query(`select id from public.cancellation_policies where name='مرنة'`)
await as('provider', `insert into public.provider_services (provider_id, category_id, title, price, deposit_percent, cancellation_policy_id)
  values ('${pid[0].id}','${cat[0].id}','قاعة الاختبار — باقة شاملة', 500000, 30, '${pol[0].id}')`)
const { rows: svc } = await as('customer', `select id, price, deposit_percent from public.v_services where provider_id='${pid[0].id}'`)
ok('العميل يرى الخدمة بعد التوثيق', svc.length === 1)

const { rows: bk } = await as('customer',
  `select * from public.api_create_booking('${svc[0].id}', (current_date + 30)::date, '20:00', null, 300, 'حي الاختبار', 'ملاحظة', false)`)
ok('أُنشئ الحجز', bk[0].status === 'pending_provider', bk[0].reference)
ok('العربون 30% من السعر', Number(bk[0].deposit_amount) === 150000, `${bk[0].deposit_amount}`)
ok('المدفوع صفر قبل تأكيد البوابة', Number(bk[0].paid_amount) === 0)
const rules = typeof bk[0].cancellation_rules === 'string'
  ? JSON.parse(bk[0].cancellation_rules)
  : (bk[0].cancellation_rules ?? [])
ok('سياسة الإلغاء نُسخت في الحجز', rules.length === 3, `${rules.length} درجات`)

console.log('\n=== العزل بين الحسابات ===')
const { rows: other } = await as('customer', `select count(*)::int n from public.bookings`)
ok('العميل يرى حجزه فقط', other[0].n === 1, `يرى ${other[0].n}`)
const { rows: seen } = await as('provider', `select count(*)::int n from public.bookings`)
ok('مقدّم الخدمة يرى حجزه فقط', seen[0].n === 1, `يرى ${seen[0].n}`)
const { rows: adminSees } = await as('admin', `select count(*)::int n from public.bookings`)
ok('المسؤول يرى كل الحجوزات', adminSees[0].n > 50, `يرى ${adminSees[0].n}`)
const { rows: docs } = await as('customer', `select count(*)::int n from public.provider_documents`)
ok('العميل لا يرى مستندات أحد', docs[0].n === 0)
const { rows: audit } = await as('customer', `select count(*)::int n from public.audit_log`)
ok('العميل لا يرى سجل العمليات', audit[0].n === 0)

console.log('\n=== الدفع ثم الرد على الحجز ===')
const { rows: pay } = await db.query(`select id from public.payments where booking_id='${bk[0].id}'`)
await db.query(`select public.api_confirm_payment('${pay[0].id}', 'gw_test', 'jawali')`)
const { rows: paid } = await as('customer', `select paid_amount from public.bookings where id='${bk[0].id}'`)
ok('المدفوع صار العربون بعد تأكيد البوابة', Number(paid[0].paid_amount) === 150000, `${paid[0].paid_amount}`)

await expectFail('العميل يقبل حجزه بنفسه', () =>
  as('customer', `select public.api_respond_to_booking('${bk[0].id}', true)`))

await as('provider', `select public.api_respond_to_booking('${bk[0].id}', true)`)
const { rows: conf } = await as('provider', `select status, commission_amount from public.bookings where id='${bk[0].id}'`)
ok('الحجز تأكد', conf[0].status === 'confirmed')
ok('العمولة احتُسبت 10%', Number(conf[0].commission_amount) === 50000, `${conf[0].commission_amount}`)
const { rows: inv } = await as('customer', `select count(*)::int n from public.invoices where booking_id='${bk[0].id}'`)
ok('صدرت فاتورة', inv[0].n === 1)
const { rows: blocked } = await db.query(`select count(*)::int n from public.provider_availability where provider_id='${pid[0].id}'`)
ok('أُغلق اليوم في التقويم', blocked[0].n === 1)

console.log('\n=== التقييم ===')
await expectFail('تقييم قبل التنفيذ', () =>
  as('customer', `select public.api_submit_review('${bk[0].id}', 5, 'ممتاز')`))
await as('provider', `select public.api_complete_booking('${bk[0].id}')`)
await as('customer', `select public.api_submit_review('${bk[0].id}', 5, 'خدمة ممتازة')`)
const { rows: rating } = await as('customer', `select rating, reviews_count from public.service_providers where id='${pid[0].id}'`)
ok('تحدّث تقييم مقدّم الخدمة', Number(rating[0].rating) === 5 && rating[0].reviews_count === 1)

console.log('\n=== الإلغاء والاسترداد ===')
const { rows: bk2 } = await as('customer',
  `select * from public.api_create_booking('${svc[0].id}', (current_date + 60)::date, '18:00', null, 200, 'حي آخر', '', true)`)
ok('الدفع الكامل يطلب كامل السعر', Number(bk2[0].total_price) === 500000)
const { rows: pay2 } = await db.query(`select id, amount from public.payments where booking_id='${bk2[0].id}' and status='pending'`)
ok('دفعة الكامل بقيمة السعر', Number(pay2[0].amount) === 500000, `${pay2[0].amount}`)
await db.query(`select public.api_confirm_payment('${pay2[0].id}', 'gw2', 'kuraimi')`)
const { rows: cancelled } = await as('customer', `select * from public.api_cancel_booking('${bk2[0].id}', 'تغيّر الموعد')`)
ok('استرداد كامل قبل 60 يوماً (سياسة مرنة)', Number(cancelled[0].refunded_amount) === 500000, `${cancelled[0].refunded_amount}`)
const { rows: rfd } = await as('customer', `select count(*)::int n from public.payments where booking_id='${bk2[0].id}' and kind='refund'`)
ok('قُيّد الاسترداد في الدفتر', rfd[0].n === 1)

console.log('\n=== الحماية من التلاعب ===')
// RLS لا يرفع خطأً على التعديل الممنوع — يخفي الصفوف فلا يطالها شيء.
// المقياس الصحيح هو عدد الصفوف المتأثرة، لا وقوع استثناء.
const t1 = await as('customer', `update public.bookings set total_price = 1 where id='${bk[0].id}'`)
ok('العميل لا يستطيع تعديل مبلغ حجزه', (t1.affectedRows ?? 0) === 0, `تأثّر ${t1.affectedRows ?? 0} صف`)
const t2 = await as('provider', `update public.provider_services set price = 1 where provider_id <> '${pid[0].id}'`)
ok('مقدّم الخدمة لا يعدّل خدمات غيره', (t2.affectedRows ?? 0) === 0, `تأثّر ${t2.affectedRows ?? 0} صف`)

const { rows: tamper } = await as('customer', `select count(*)::int n from public.bookings where total_price = 1`)
ok('لم يتغيّر أي مبلغ', tamper[0].n === 0)

const { rows: notifs } = await as('provider', `select count(*)::int n from public.notifications`)
ok('وصلت إشعارات مقدّم الخدمة', notifs[0].n >= 2, `${notifs[0].n}`)

console.log(`\n${failures === 0 ? '🎉 كل الفحوص نجحت' : `❌ ${failures} فحص فشل`}`)
await db.close()
process.exit(failures ? 1 : 0)
