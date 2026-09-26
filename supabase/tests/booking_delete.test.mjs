// حذفُ الحجز — `api_delete_booking` تمحو الصفَّ نهائيّاً، بشروط.
//
// ── ما يُقاس ───────────────────────────────────────────────────────────────
//
//   ١. **أنّ صاحبَ الحجز وحدَه يحذفه** — ودالّةٌ `security definer` بلا هذا
//      الفحص بابٌ يُمحى منه حجزُ كلّ أحدٍ بمعرّفه.
//   ٢. **وأنّ ما دخله مالٌ لا يُمحى** — `payments.booking_id` مرجعُه
//      `on delete set null`، فيبقى مبلغٌ مدفوعٌ بلا حجزٍ يُنسب إليه.
//   ٣. **وأنّ ما دخل تسويةً لا يُمحى** — والقاعدةُ ترفضه بـ`restrict`،
//      فيُقال له لماذا بالعربيّة لا بخطأِ مفتاحٍ أجنبيّ.
//   ٤. **وأنّ ما عليه نزاعٌ مفتوحٌ لا يُمحى** — الحجزُ سندُ النزاع.
//   ٥. **وأنّ الحذفَ يقع حقّاً** حين تُستوفى الشروط.
//   ٦. **وأنّ المجهولَ ممنوعٌ من الدالّة أصلاً.**
//
// وتُشغَّل بـ`npm test` لا بالملفّ وحدَه.
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

const db = new PGlite()
const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

await db.exec(`
  create schema if not exists auth;
  create schema if not exists storage;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create table if not exists storage.buckets (
    id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table if not exists storage.objects (
    id uuid primary key default gen_random_uuid(), bucket_id text, name text);
  create or replace function storage.foldername(p text) returns text[]
    language sql immutable as $$ select string_to_array(p, '/') $$;
  create role anon; create role authenticated; create role service_role;`)

for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql', 'service_media.sql', 'booking_delete.sql']) {
  await db.exec(read(f))
}
// إعادةُ اللصق لا تكسر شيئاً — شرطُ كلّ ملفٍّ يُلصق في محرّر SQL.
await db.exec(read('booking_delete.sql'))

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز ──────────────────────────────────────────────────────────────────
const mine = '11111111-1111-1111-1111-111111111111'
const hers = '22222222-2222-2222-2222-222222222222'

await db.exec(`
  insert into auth.users (id, email) values
    ('${mine}', 'mine@sdd.company'), ('${hers}', 'hers@sdd.company');
  insert into public.app_users (auth_user_id, full_name, email, status) values
    ('${mine}', 'مريم', 'mine@sdd.company', 'active'),
    ('${hers}', 'سارة', 'hers@sdd.company', 'active');`)

const uid = async (auth) =>
  (await one(`select id from public.app_users where auth_user_id = $1`, [auth])).id

const myId = await uid(mine)
const herId = await uid(hers)

const service = await one(
  `select s.id, s.provider_id, p.business_name as provider_name
     from public.provider_services s
     join public.service_providers p on p.id = s.provider_id
    order by s.id limit 1`)

let _day = 0
const book = async (userId, { paid = 0 } = {}) => (await one(`
  insert into public.bookings
    (reference, user_id, service_id, provider_id, event_date, guests_count,
     address, status, total_price, deposit_amount, paid_amount)
  values ('BK-T-' || substr(md5(random()::text), 1, 6), $1, $2, $3,
          current_date + $4::integer, 300, 'حي السنينة', 'pending_provider',
          500000, 150000, $5)
  returning id, reference`,
  [userId, service.id, service.provider_id, 60 + ++_day, paid]))

const asUser = async (auth) =>
  db.exec(`select set_config('test.uid', '${auth}', false); set role authenticated;`)
const off = () => db.exec('reset role')

const del = async (id) => {
  try {
    await db.query(`select public.api_delete_booking($1)`, [id])
    return null
  } catch (e) {
    return String(e.message)
  }
}

const exists = async (id) =>
  (await one(`select count(*)::int as n from public.bookings where id = $1`, [id])).n > 0

// ── ١. صاحبُه وحدَه يحذفه ──────────────────────────────────────────────────
console.log('=== صاحبُه ===')
const hersOne = await book(herId)

await asUser(mine)
const stolen = await del(hersOne.id)
await off()

ok('مريمُ لا تحذف حجزَ سارة', stolen !== null && stolen.includes('صلاحية'),
   String(stolen))
ok('وحجزُ سارة باقٍ', await exists(hersOne.id))

// ── ٢. وما دخله مالٌ لا يُمحى ──────────────────────────────────────────────
//
// **بابان لا بابٌ واحد**: مبلغٌ مسجَّلٌ في `payments`، أو `paid_amount` في
// الصفّ نفسِه. وحجزٌ سُجّل دفعُه في أحدهما دون الآخر يقع.
console.log('=== والمال ===')
const withAmount = await book(myId, { paid: 150000 })
await asUser(mine)
const paidBlocked = await del(withAmount.id)
await off()
ok('لا يُحذف حجزٌ فيه `paid_amount`',
   paidBlocked !== null && paidBlocked.includes('مال'), String(paidBlocked))
ok('وهو باقٍ', await exists(withAmount.id))

const withPayment = await book(myId)
await db.query(`
  insert into public.payments
    (reference, user_id, user_name, provider_id, provider_name, booking_id,
     booking_reference, kind, description, amount, platform_share, net_amount,
     status)
  values ('PAY-T-1', $1, 'مريم', $2, $3, $4, $5, 'deposit', 'عربون',
          150000, 15000, 135000, 'paid')`,
  [myId, service.provider_id, service.provider_name, withPayment.id,
   withPayment.reference])

await asUser(mine)
const payBlocked = await del(withPayment.id)
await off()
ok('ولا حجزٌ له صفُّ دفعٍ ولو كان `paid_amount` صفراً',
   payBlocked !== null && payBlocked.includes('مال'), String(payBlocked))
ok('وهو باقٍ', await exists(withPayment.id))

// ── ٣. وما عليه نزاعٌ مفتوحٌ لا يُمحى ──────────────────────────────────────
console.log('=== والنزاع ===')
const disputed = await book(myId)
await db.query(`
  insert into public.disputes
    (reference, booking_id, opened_by, user_id, provider_id, category, subject,
     description, status)
  values ('DSP-T-1', $1, 'customer', $2, $3, 'quality', 'شكوى', 'تفصيل',
          'open')`,
  [disputed.id, myId, service.provider_id])

await asUser(mine)
const disputeBlocked = await del(disputed.id)
await off()
ok('لا يُحذف حجزٌ عليه نزاعٌ مفتوح',
   disputeBlocked !== null && disputeBlocked.includes('نزاع'),
   String(disputeBlocked))
ok('وهو باقٍ', await exists(disputed.id))

// **ونزاعٌ أُغلق لا يمنع** — وإلّا لَبقي الحجزُ محبوساً إلى الأبد.
await db.query(`update public.disputes
                   set status = 'resolved', resolved_at = now()
                 where booking_id = $1`, [disputed.id])
await asUser(mine)
const afterResolved = await del(disputed.id)
await off()
ok('والنزاعُ المغلَقُ لا يمنع', afterResolved === null, String(afterResolved))
ok('وقد مُحي', !(await exists(disputed.id)))

// ── ٤. وما دخل تسويةً لا يُمحى ─────────────────────────────────────────────
//
// **والقاعدةُ ترفضه بـ`restrict` على كلّ حال** — فالمقيسُ أن يُقال له
// لماذا بالعربيّة لا أن يخرج خطأُ مفتاحٍ أجنبيّ لا يفهمه أحد.
console.log('=== والتسوية ===')
const settled = await book(myId)
const settlement = await one(`
  insert into public.settlements
    (reference, provider_id, provider_name, period_start, period_end)
  values ('STL-T-1', $1, $2, current_date - 30, current_date)
  returning id`, [service.provider_id, service.provider_name])
await db.query(`
  insert into public.settlement_items (settlement_id, booking_id)
  values ($1, $2)`, [settlement.id, settled.id])

await asUser(mine)
const settledBlocked = await del(settled.id)
await off()
ok('لا يُحذف حجزٌ دخل تسوية',
   settledBlocked !== null && settledBlocked.includes('تسوية'),
   String(settledBlocked))
ok('وهو باقٍ', await exists(settled.id))

// ── ٥. والحذفُ يقع حين تُستوفى الشروط ──────────────────────────────────────
console.log('=== والحذف ===')
const clean = await book(myId)
await asUser(mine)
const done = await del(clean.id)
await off()
ok('حجزٌ نظيفٌ يُمحى', done === null, String(done))
ok('ولا أثرَ له في الجدول', !(await exists(clean.id)))

// ── ٦. والمجهولُ ممنوع ─────────────────────────────────────────────────────
console.log('=== والمجهول ===')
const forAnon = await book(myId)
let denied = false
await db.exec(`select set_config('test.uid', '', false); set role anon;`)
try {
  await db.query(`select public.api_delete_booking($1)`, [forAnon.id])
} catch (e) {
  denied = String(e.message).includes('permission denied')
}
await off()
ok('المجهولُ ممنوعٌ من الدالّة', denied)
ok('والحجزُ باقٍ', await exists(forAnon.id))

await db.close()
console.log(fail === 0 ? '\n✅ كلّها' : `\n❌ سقط ${fail}`)
process.exit(fail === 0 ? 0 : 1)
