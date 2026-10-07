// **«رصيد فرحتي» — يُلعب بأدوار القاعدة الحقيقيّة، ويُقاس ما في الدفتر.**
//
// تُبنى القاعدةُ كلُّها بترتيب النشر، ثمّ `security_fixes.sql`، ثمّ
// `wallet.sql` (مرّتين: إعادةُ اللصق آمنة). وكلُّ خطوةٍ تُنفَّذ بدور
// `authenticated` بهويّة صاحبها — فصاحبُ القاعدة يتجاوز RLS ولا يقيس شيئاً.
//
// وما اختاره صاحبُ المنصّة هو المقيس:
//   • الاسترجاعُ المحسوبُ عند الإلغاء **ينتظر اعتمادَ الإدارة** قبل الرصيد،
//     و«ردّ المبلغ» من اللوحة قرارٌ فيدخل فوراً.
//   • **ولا سحبَ إلّا إلى حسابٍ دُفع منه** — لغسل الأموال.
//   • ويُدفع من الرصيد فيتأكّد الدفعُ فوراً.
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8').replace(/\r\n/g, '\n')

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

const SUPABASE = `
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon; create role authenticated; create role service_role;
  grant usage on schema auth to anon, authenticated;
  grant execute on all functions in schema auth to anon, authenticated;
  create schema if not exists storage;
  create table storage.buckets (id text primary key, name text not null, public boolean not null default false,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id), name text not null, owner uuid);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;`

const ORDER = `install seed apply storage support roles invitations profile service_media chat
  notifications push_hook provider_logo payments_app availability subscriptions settlements
  promotions broadcast plan_tasks income chat_media profile_extras coupons location nearby
  category_images app_download share_link service_delete completion_review review_avatars
  phone_verify provider_columns profile_cover plan_cover plan_spend booking_cover booking_delete
  conversation_avatars customer_card phone_verify_attempts presence security_notification_rpcs
  audit_security security_hardening security_fixes`.split(/\s+/)

const db = new PGlite()
await db.exec(SUPABASE)
for (const f of ORDER) await db.exec(read(`${f}.sql`))

// **ما سبق الملفَّ في القاعدة الحيّة:** استرجاعٌ قديمٌ ودفعةٌ رقمُ صاحبها في
// `gateway_ref` — كلاهما يجب أن يُفهم بعد اللصق كما كان.
const legacyBooking = (await db.query(`select id, reference, user_id from public.bookings
  where user_id is not null limit 1`)).rows[0]
await db.query(`insert into public.payments (reference, user_id, booking_id, booking_reference, kind,
  amount, status, refunded_at) values ('RFD-OLD-1', $1, $2, $3, 'refund', 5000, 'refunded', now())`,
  [legacyBooking.user_id, legacyBooking.id, legacyBooking.reference])

await db.exec(read('wallet.sql'))
await db.exec(read('wallet.sql')) // إعادةُ اللصق آمنة

const q = async (sql, params = []) => (await db.query(sql, params)).rows
const one = async (sql, params = []) => (await q(sql, params))[0]
const as = async (auth, sql, params = []) => {
  await db.exec('begin')
  try {
    await db.exec(`set local role ${auth ? 'authenticated' : 'anon'}`)
    await db.query(`select set_config('request.jwt.claim.sub', $1, true)`, [auth ?? ''])
    const rows = (await db.query(sql, params)).rows
    await db.exec('commit')
    return rows
  } catch (e) {
    await db.exec('rollback')
    return { error: e.message }
  }
}
const refused = (r) => !Array.isArray(r)
const num = (v) => Number(v)

ok('**الاسترجاعُ القديمُ «legacy» — لا يُعرض للاعتماد ولا يدخل رصيداً**',
  (await one(`select wallet_state from public.payments where reference = 'RFD-OLD-1'`)).wallet_state === 'legacy')

// ── تجهيز: عميلٌ، وغريبٌ، ومسؤولُ مال ──────────────────────────────────────
const C = '11111111-1111-4111-8111-111111111111'
const X = '22222222-2222-4222-8222-222222222222'
const ADMIN = '33333333-3333-4333-8333-333333333333'
await db.exec(`insert into auth.users (id, email) values
  ('${C}', 'c@x.com'), ('${X}', 'x@x.com'), ('${ADMIN}', 'boss@x.com');
  insert into public.admins (user_id, email, role) values ('${ADMIN}', 'boss@x.com', 'owner');`)
await as(C, `select public.api_register_profile('عميلة', '+967771111111', 'صنعاء', 'android')`)
await as(X, `select public.api_register_profile('غريب', '+967772222222', 'صنعاء', 'android')`)
const me = (await one(`select id from public.app_users where auth_user_id = $1`, [C])).id

/** حجزٌ مؤكَّدٌ للعميلة، عربونُه ١٠٠ ألف من ٣٠٠، وسلّمُه ١٠٠٪ قبل أسبوع. */
const seats = await q(`select id from public.bookings where status not in ('cancelled','rejected')
  order by created_at limit 4`)
const booking = async (i) => {
  const id = seats[i].id
  await db.query(`update public.bookings set user_id = $1, user_name = 'عميلة', status = 'confirmed',
      confirmed_at = now(), completed_at = null, cancelled_at = null, commission_amount = 0,
      paid_amount = 0, refunded_amount = 0, deposit_amount = 100000, total_price = 300000,
      event_date = current_date + 30,
      cancellation_rules = '[{"hours_before":168,"refund_percent":100},{"hours_before":0,"refund_percent":0}]'
    where id = $2`, [me, id])
  await db.query(`delete from public.payments where booking_id = $1`, [id])
  return (await one(`select id, reference from public.bookings where id = $1`, [id]))
}
const balance = async () => num((await as(C, `select public.api_my_wallet() w`))[0].w.balance)

// ── ١. إبلاغُ الحوالة بلا رقم المحوِّل لا يُقبل ─────────────────────────────
const b1 = await booking(0)
const bare = await as(C, `select * from public.api_submit_payment($1, 'jawali', 'deposit', '')`, [b1.id])
ok('**إبلاغُ حوالةٍ بلا رقم الحساب المحوَّل منه يُردّ**', refused(bare) && /رقم الحساب الذي حوّلت منه/.test(bare.error),
  JSON.stringify(bare))
const sent = await as(C, `select id, payer_account from public.api_submit_payment($1, 'jawali', 'deposit', '+967 777 123 456')`, [b1.id])
ok('وبرقمه يُقبل ويُحفظ في payer_account', !refused(sent) && sent[0].payer_account === '+967 777 123 456',
  JSON.stringify(sent))
await as(ADMIN, `select public.api_admin_confirm_payment($1, 'TX-998877')`, [sent[0].id])
ok('**وتأكيدُ المسؤول برقم العملية لا يمحو رقمَ العميل**',
  (await one(`select payer_account, gateway_ref, status from public.payments where id = $1`, [sent[0].id]))
    .payer_account === '+967 777 123 456')

// ── ٢. الإلغاءُ يحسب الاسترجاعَ ولا يُدخله الرصيدَ قبل الاعتماد ────────────
await as(C, `select public.api_cancel_booking($1, 'تغيّر الموعد')`, [b1.id])
const rfd = await one(`select id, amount, wallet_state from public.payments where booking_id = $1 and kind = 'refund'`, [b1.id])
ok('**الإلغاءُ يُنشئ استرجاعاً «بانتظار الاعتماد»**', rfd?.wallet_state === 'pending' && num(rfd.amount) === 100000,
  JSON.stringify(rfd))
ok('**ولا يدخل الرصيدَ قبل اعتماده**', (await balance()) === 0)
const mine = await as(C, `select (public.api_my_wallet()->>'pending_refunds')::numeric p`)
ok('والعميلةُ ترى أنّ استرجاعاً ينتظر', num(mine[0].p) === 100000, JSON.stringify(mine))

ok('**ولا تعتمده هي**', refused(await as(C, `select public.api_admin_decide_refund($1, true)`, [rfd.id])))
ok('ولا ترى قائمةَ الاعتماد', refused(await as(C, `select public.api_admin_pending_refunds()`)))
const list = await as(ADMIN, `select public.api_admin_pending_refunds() r`)
ok('والمسؤولُ يراه في قائمة الاعتماد', list[0].r.some((r) => r.id === rfd.id), JSON.stringify(list).slice(0, 160))
ok('وليس فيها القديم', !list[0].r.some((r) => r.reference === 'RFD-OLD-1'))

ok('**ولا يُعتمد بأكثر ممّا حُسب**',
  refused(await as(ADMIN, `select public.api_admin_decide_refund($1, true, 150000)`, [rfd.id])))
const approved = await as(ADMIN, `select public.api_admin_decide_refund($1, true) r`, [rfd.id])
ok('والاعتمادُ يُدخله الرصيد', !refused(approved) && num(approved[0].r.credited) === 100000 && (await balance()) === 100000,
  JSON.stringify(approved))
ok('**ولا يُعتمد مرّتين**', refused(await as(ADMIN, `select public.api_admin_decide_refund($1, true)`, [rfd.id])))

// ── ٣. السحبُ إلى حسابٍ دُفع منه — وإلّا فلا ───────────────────────────────
const elsewhere = await as(C, `select * from public.api_request_withdrawal(50000, 'jawali', '771 000 999')`)
ok('**السحبُ إلى رقمٍ لم تدفع منه يُرفض**', refused(elsewhere) && /اسحب إلى الحساب الذي دفعت منه/.test(elsewhere.error),
  JSON.stringify(elsewhere))
ok('ولا يُحجز من رصيدها شيء', (await balance()) === 100000)

const tooMuch = await as(C, `select * from public.api_request_withdrawal(100001, 'jawali', '777123456')`)
ok('ولا بأكثر من رصيدها', refused(tooMuch) && /أكبر من رصيدك/.test(tooMuch.error), JSON.stringify(tooMuch))

const wd = await as(C, `select id, reference, matched_payment_id from public.api_request_withdrawal(60000, 'jawali', '٧٧٧١٢٣٤٥٦')`)
ok('**والرقمُ نفسُه بأرقامٍ عربيّةٍ وبلا مفتاحٍ يُطابَق**', !refused(wd) && wd[0].matched_payment_id === sent[0].id,
  JSON.stringify(wd))
ok('ويُحجز المبلغُ من الرصيد فور الطلب', (await balance()) === 40000)
ok('ورقمُه WD-السنة-تسلسل', /^WD-\d{4}-\d{4}$/.test(wd[0].reference), wd[0].reference)

const adminList = await as(ADMIN, `select public.api_admin_withdrawals('pending') r`)
const row = adminList[0].r.find((r) => r.id === wd[0].id)
ok('**واللوحةُ ترى الرقمين معاً، و«مطابق»**', row?.matched === true && row.paid_account === '+967 777 123 456'
  && row.user_name === 'عميلة', JSON.stringify(row))
ok('ولا يراها الغريب', refused(await as(X, `select public.api_admin_withdrawals()`)))

ok('**والرفضُ بلا سبب لا يُقبل**', refused(await as(ADMIN, `select public.api_admin_decide_withdrawal($1, false, '')`, [wd[0].id])))
await as(ADMIN, `select public.api_admin_decide_withdrawal($1, false, 'الرقم مقفل')`, [wd[0].id])
ok('**والرفضُ يُعيد المبلغ إلى الرصيد**', (await balance()) === 100000)
ok('ولا يُقرَّر مرّتين', refused(await as(ADMIN, `select public.api_admin_decide_withdrawal($1, true)`, [wd[0].id])))

const wd2 = await as(C, `select id from public.api_request_withdrawal(30000, 'jawali', '777123456')`)
await as(ADMIN, `select public.api_admin_decide_withdrawal($1, true)`, [wd2[0].id])
ok('و«حوّلتُ المبلغ» يُبقيه خارجاً ويُعلِم العميلة', (await balance()) === 70000
  && (await one(`select count(*) n from public.notifications where user_id = $1 and title = 'حُوِّل مبلغُ السحب'`, [me])).n > 0)

// ── ٤. الدفعُ من الرصيد ─────────────────────────────────────────────────────
const b2 = await booking(1)
const short = await as(C, `select * from public.api_pay_from_wallet($1, 'deposit')`, [b2.id])
ok('**رصيدٌ لا يغطّي العربون يُقال له ذلك**', refused(short) && /لا يكفي/.test(short.error), JSON.stringify(short))
ok('ولا يُخصم منه شيء', (await balance()) === 70000)

// «ردّ المبلغ» من اللوحة قرارُ مسؤول: يدخل فوراً.
const b3 = await booking(2)
const p3 = await as(C, `select id from public.api_submit_payment($1, 'kuraimi', 'deposit', '3001234567')`, [b3.id])
await as(ADMIN, `select public.api_admin_confirm_payment($1)`, [p3[0].id])
await as(ADMIN, `select public.api_admin_refund_payment($1, 'اعتذار')`, [p3[0].id])
ok('**«ردّ المبلغ» من اللوحة يدخل الرصيدَ فوراً**', (await balance()) === 170000)
ok('ومرّةً واحدة', refused(await as(ADMIN, `select public.api_admin_refund_payment($1)`, [p3[0].id])) && (await balance()) === 170000)

const paid = await as(C, `select id, method, status, amount from public.api_pay_from_wallet($1, 'deposit')`, [b2.id])
ok('**والدفعُ من الرصيد يتأكّد فوراً**', !refused(paid) && paid[0].method === 'wallet' && paid[0].status === 'paid'
  && num(paid[0].amount) === 100000, JSON.stringify(paid))
ok('ويُحتسب في الحجز', num((await one(`select paid_amount from public.bookings where id = $1`, [b2.id])).paid_amount) === 100000)
ok('ويُخصم من الرصيد', (await balance()) === 70000)
ok('ولا يُدفع العربونُ مرّتين', refused(await as(C, `select * from public.api_pay_from_wallet($1, 'deposit')`, [b2.id])))
ok('ولا من رصيدها حجزُ غيرها', refused(await as(X, `select * from public.api_pay_from_wallet($1, 'balance')`, [b2.id])))

// ── ٥. الرفضُ يُعيد المبلغ إلى الحجز، والسقفُ ما دُفع ──────────────────────
const b4 = await booking(3)
const p4 = await as(C, `select id from public.api_submit_payment($1, 'jawali', 'deposit', '777123456')`, [b4.id])
await as(ADMIN, `select public.api_admin_confirm_payment($1)`, [p4[0].id])
await as(C, `select public.api_cancel_booking($1)`, [b4.id])
const rfd4 = await one(`select id from public.payments where booking_id = $1 and kind = 'refund'`, [b4.id])
await as(ADMIN, `select public.api_admin_decide_refund($1, false, null, 'ألغت بعد تجهيز القاعة')`, [rfd4.id])
const after = await one(`select refunded_amount from public.bookings where id = $1`, [b4.id])
ok('**رفضُ الاسترجاع يُعيده مستحقّاً في الحجز**', num(after.refunded_amount) === 0 && (await balance()) === 70000,
  JSON.stringify(after))

// ── ٦. والدفترُ لا يُكتب إلّا بالدوالّ ─────────────────────────────────────
ok('**العميلةُ لا تكتب في دفترها مباشرةً**',
  refused(await as(C, `insert into public.wallet_entries (user_id, amount, kind) values ($1, 999999, 'refund')`, [me])))
ok('ولا في طلبات السحب',
  refused(await as(C, `update public.wallet_withdrawals set status = 'paid'`)))
const peek = await as(X, `select count(*) n from public.wallet_entries`)
ok('**والغريبُ لا يرى حركاتِها**', !refused(peek) && Number(peek[0].n) === 0, JSON.stringify(peek))
ok('ولا الزائر', refused(await as(null, `select public.api_my_wallet()`)))

const ledger = await one(`select sum(amount) s from public.wallet_entries where user_id = $1`, [me])
ok('**والرصيدُ مجموعُ الدفتر**', num(ledger.s) === (await balance()), JSON.stringify(ledger))

// ── ٧. رقمُ الفاتورة يتبع رقمَ الحجز ───────────────────────────────────────
//
// «اريد رقم فاتورة للكل حجز عشن اقدر اعرف جنب رقم الحجز». والدالّةُ المقيسةُ
// هي التي في القاعدة بعد حزمة التحصين — فهي آخرُ من يُعرّف `api_respond_to_booking`.
const waiting = await one(`select id, reference from public.bookings where status = 'pending_provider'
  and not exists (select 1 from public.bookings c where c.provider_id = bookings.provider_id
                    and c.event_date = bookings.event_date and c.status = 'confirmed') limit 1`)
const accepted = await as(ADMIN, `select status from public.api_respond_to_booking($1, true)`, [waiting.id])
const invoice = await one(`select number from public.invoices where booking_id = $1`, [waiting.id])
ok('**فاتورةُ BK-… رقمُها INV-… بالذيل نفسِه**', !refused(accepted)
  && invoice?.number === waiting.reference.replace(/^BK-/, 'INV-'), `${waiting.reference} → ${invoice?.number}`)

// ── ٨. رصيدُ مقدّم الخدمة ──────────────────────────────────────────────────
//
// «باقي مقدم الخدمة محفظة رصيد فرحتي»: صافي الحجز يدخل حين تعتمد الإدارةُ
// التنفيذ، ويُسحب إلى حسابٍ مسجَّلٍ وثّقته الإدارة وحدَه.
const PRV = '44444444-4444-4444-8444-444444444444'
const PRV2 = '55555555-5555-4555-8555-555555555555'
await db.exec(`insert into auth.users (id, email) values ('${PRV}', 'p@x.com'), ('${PRV2}', 'p2@x.com')`)
await as(PRV, `select public.api_register_profile('مزوّد', '+967773333333', 'صنعاء', 'android')`)
await as(PRV2, `select public.api_register_profile('مزوّدٌ آخر', '+967774444444', 'صنعاء', 'android')`)
const [prov, prov2] = (await q(`select id from public.service_providers where status = 'verified' order by id limit 2`)).map((r) => r.id)
await db.query(`update public.service_providers set user_id = (select id from public.app_users where auth_user_id = $1) where id = $2`, [PRV, prov])
await db.query(`update public.service_providers set user_id = (select id from public.app_users where auth_user_id = $1) where id = $2`, [PRV2, prov2])

/** حجزٌ مؤكَّدٌ للمزوّد: دُفع منه ١٠٠ ألف، والعمولةُ ١٠ آلاف — فالصافي ٩٠ ألفاً. */
const provBooking = async (i, providerId = prov) => {
  const b = await booking(i)
  await db.query(`delete from public.settlement_items where booking_id = $1`, [b.id])
  await db.query(`update public.bookings set provider_id = $1, paid_amount = 100000, refunded_amount = 0,
      commission_amount = 10000, event_date = current_date - 1 where id = $2`, [providerId, b.id])
  return b
}
const pwallet = async (auth = PRV) => (await as(auth, `select public.api_my_provider_wallet() w`))[0]?.w
const pbal = async () => num((await pwallet()).balance)

const pb = await provBooking(0)
ok('**عربونُ حجزٍ مؤكَّدٍ «ينتظر التنفيذ» بصافيه — ولا يدخل الرصيد**',
  num((await pwallet()).pending) >= 90000 && (await pbal()) === 0, JSON.stringify(await pwallet()).slice(0, 120))

ok('**ولا يُنهي المزوّدُ حجزَه بنفسه**', refused(await as(PRV, `select public.api_complete_booking($1)`, [pb.id])))
const done = await as(ADMIN, `select status from public.api_complete_booking($1)`, [pb.id])
ok('**واعتمادُ الإدارة للتنفيذ يُدخل الصافي رصيدَه — بعد العمولة**', !refused(done) && (await pbal()) === 90000,
  `${JSON.stringify(done)} ${await pbal()}`)
ok('ويصله إشعار', Number((await one(`select count(*) n from public.notifications where provider_id = $1 and title = 'دخل رصيدَك صافي حجز'`, [prov])).n) > 0)

await db.query(`update public.bookings set status = 'confirmed', completed_at = null where id = $1`, [pb.id])
await db.query(`update public.bookings set status = 'completed', completed_at = now() where id = $1`, [pb.id])
ok('**وحجزٌ يُعاد تنفيذُه لا يدخل مرّتين**', (await pbal()) === 90000)

ok('ولا يرى الآخرُ حركاتِه', Number((await as(PRV2, `select count(*) n from public.wallet_entries where provider_id = $1`, [prov]))[0].n) === 0)

// حسابُ السحب
const noAcc = await as(PRV, `select * from public.api_request_provider_withdrawal(10000)`)
ok('**بلا حسابٍ مسجَّلٍ لا سحب**', refused(noAcc) && /سجّل حسابَ السحب/.test(noAcc.error), JSON.stringify(noAcc))
ok('ولا يسجّل العميلُ حسابَ سحبٍ لمزوّد', refused(await as(C, `select * from public.api_set_payout_account('kuraimi', '3001234567', 'x')`)))
const setAcc = await as(PRV, `select status from public.api_set_payout_account('kuraimi', '3001234567', 'مؤسسة الأصالة')`)
ok('والمزوّدُ يسجّله «بانتظار التوثيق»', !refused(setAcc) && setAcc[0].status === 'pending', JSON.stringify(setAcc))
const unverified = await as(PRV, `select * from public.api_request_provider_withdrawal(10000)`)
ok('**وقبل توثيقه لا سحب**', refused(unverified) && /لم يُوثَّق/.test(unverified.error), JSON.stringify(unverified))
ok('ولا يوثّقه هو', refused(await as(PRV, `select * from public.api_admin_verify_payout_account($1, true)`, [prov])))
const listAcc = await as(ADMIN, `select public.api_admin_payout_accounts('pending') r`)
ok('والمسؤولُ يراه في قائمة التوثيق', listAcc[0].r.some((a) => a.provider_id === prov), JSON.stringify(listAcc).slice(0, 120))
await as(ADMIN, `select * from public.api_admin_verify_payout_account($1, true)`, [prov])

const pwd = await as(PRV, `select id, account, provider_id, user_id from public.api_request_provider_withdrawal(50000)`)
ok('**وبعد توثيقه يُسحب إليه — ويُحجز من الرصيد**', !refused(pwd) && pwd[0].account === '3001234567'
  && pwd[0].user_id === null && (await pbal()) === 40000, JSON.stringify(pwd))
ok('ولا بأكثر من رصيده', refused(await as(PRV, `select * from public.api_request_provider_withdrawal(40001)`)))
const prow = (await as(ADMIN, `select public.api_admin_withdrawals('pending') r`))[0].r.find((r) => r.id === pwd[0].id)
ok('**واللوحةُ تراه طلبَ مزوّدٍ، و«مطابق» لحسابه الموثَّق**', prow?.party === 'provider' && prow.matched === true
  && prow.user_name && prow.paid_account === '3001234567', JSON.stringify(prow))

await as(PRV, `select public.api_set_payout_account('jawali', '771000999', 'شخصٌ آخر')`)
const changed = await as(PRV, `select * from public.api_request_provider_withdrawal(1000)`)
ok('**وتغييرُ الحساب يعيده «بانتظار التوثيق» فيقف السحب**', refused(changed) && /لم يُوثَّق/.test(changed.error), JSON.stringify(changed))
const prow2 = (await as(ADMIN, `select public.api_admin_withdrawals('pending') r`))[0].r.find((r) => r.id === pwd[0].id)
ok('والطلبُ القديمُ صار «غير مطابق» للّوحة', prow2?.matched === false, JSON.stringify(prow2))

await as(ADMIN, `select public.api_admin_decide_withdrawal($1, false, 'الحساب تغيّر')`, [pwd[0].id])
ok('**ورفضُ سحب المزوّد يُعيد المبلغ إلى رصيده ويُعلمه**', (await pbal()) === 90000
  && Number((await one(`select count(*) n from public.notifications where provider_id = $1 and title = 'لم يُقبل طلبُ السحب'`, [prov])).n) > 0)

// «مستحقات الشركاء» سجلٌّ لما قبل الرصيد
await as(ADMIN, `select public.api_admin_build_settlements(current_date - 30, current_date)`)
ok('**وحجزٌ دخل رصيدَ مزوّده لا يُحتسب في تسوية**',
  Number((await one(`select count(*) n from public.settlement_items where booking_id = $1`, [pb.id])).n) === 0)

const settle = read('settlements.sql')
const fromSettle = settle.slice(settle.indexOf('create or replace function public.api_admin_build_settlements('),
  settle.indexOf('end $$;', settle.indexOf('create or replace function public.api_admin_build_settlements(')))
const walletSql = read('wallet.sql')
const fromWallet = walletSql.slice(walletSql.indexOf('create or replace function public.api_admin_build_settlements('),
  walletSql.indexOf('end $$;', walletSql.indexOf('create or replace function public.api_admin_build_settlements(')))
const extra = `       -- ما دخل رصيدَ مزوّده لا يُحتسب في تسوية: دُفع له من الرصيد.
       and not exists (select 1 from public.wallet_entries e where e.booking_id = b.id and e.kind = 'earning')
`
ok('**ونسخةُ الاحتساب في wallet.sql هي نسخةُ settlements.sql بسطرها الزائد وحدَه**',
  fromWallet.replace(extra, '') === fromSettle)

await db.close()
if (fail) {
  console.log(`\n${fail} سقط.`)
  process.exit(1)
}
console.log('\nكلُّ ما قيس أخضر.')
