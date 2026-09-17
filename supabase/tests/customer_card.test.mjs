/**
 * بطاقةُ العميل: دالّةٌ ضيّقةٌ ترى الصفَّ ولا تُخرج منه إلّا حقلين.
 *
 * **وأخطرُ ما يُقاس هنا ليس أنّها تعمل، بل أنّها لا تعمل لغير أهلها ولا
 * تُخرج غيرَ ما وُعد به.** سياسةُ `app_users` تقول «لا يرى حسابات غيره
 * إطلاقاً»، وهذه الدالّةُ `security definer` — أي أنّها تتجاوزها بتصميمها.
 * فحدُّها الوحيدُ ما يُكتب في جسدها، وما يُكتب في جسدها يُقاس هنا:
 *
 *   ــ لا تعمل لمن ليس مقدّمَ خدمة.
 *   ــ ولا تعمل على محادثةٍ ليس هو طرفَها — ولو كانت موجودة.
 *   ــ ولا تُخرج بريداً ولا جوّالاً ولا حالةَ حساب.
 *   ــ وحسابُ الحجوزات **معه هو** لا مع غيره.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

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
  create role anon; create role authenticated;
`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql', 'profile.sql', 'chat.sql']) {
  await db.exec(read(f))
}
const card = read('customer_card.sql')
await db.exec(card)
await db.exec(card) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const mustFail = async (label, fn, expect) => {
  try {
    await fn()
    console.log(`❌ ${label} — نجح وكان يجب أن يفشل`)
    fail++
  } catch (e) {
    const hit = !expect || String(e.message).includes(expect)
    if (!hit) fail++
    console.log(`${hit ? '✅' : '❌'} ${label}${hit ? '' : ` — رُفض برسالةٍ أخرى: ${e.message}`}`)
  }
}
const as = async (uid, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid ?? ''])
  return db.query(sql, params)
}

// ── تجهيزٌ: عميلٌ ومقدّما خدمة ───────────────────────────────────────────────
const mkAuth = async (email) => {
  const { rows } = await db.query(
    `insert into auth.users (id, email) values (gen_random_uuid(), $1) returning id`,
    [email])
  return rows[0].id
}

const custAuth = await mkAuth('cust@sdd.company')
const { rows: cu } = await db.query(
  `insert into public.app_users (auth_user_id, full_name, email, phone, status,
                                 governorate, avatar_path)
   values ($1, 'أحمد الشرعبي', 'cust@sdd.company', '770000000', 'active',
           'صنعاء', 'u1/avatar-7.jpg')
   returning id`, [custAuth])
const customerId = cu[0].id

const mkProvider = async (email, name) => {
  const auth = await mkAuth(email)
  const { rows: u } = await db.query(
    `insert into public.app_users (auth_user_id, full_name, email, status)
     values ($1, $2, $3, 'active') returning id`, [auth, name, email])
  const { rows: p } = await db.query(
    `insert into public.service_providers (user_id, full_name, business_name, email,
                                           status, verified_at, governorate_id)
     values ($1, $2, $2, $3, 'verified', now(),
             (select id from public.governorates order by name limit 1))
     returning id`, [u[0].id, name, email])
  return { auth, providerId: p[0].id }
}

const mine = await mkProvider('hall@sdd.company', 'قاعة التاج')
const other = await mkProvider('rival@sdd.company', 'قاعة الضيافة')

const convo = async (providerId, providerName) => {
  const { rows } = await db.query(
    `insert into public.conversations (user_id, user_name, provider_id, provider_name)
     values ($1, 'أحمد الشرعبي', $2, $3) returning id`,
    [customerId, providerId, providerName])
  return rows[0].id
}
const mineConvo = await convo(mine.providerId, 'قاعة التاج')
const otherConvo = await convo(other.providerId, 'قاعة الضيافة')

// حجوزاتٌ معي ومع غيري — ليُقاس أنّ الحسابَ لا يخلط
const { rows: svc } = await db.query(
  `insert into public.provider_services (provider_id, category_id, title, price)
   values ($1, (select id from public.service_categories order by sort_order limit 1),
           'باقة', 100000)
   returning id`, [mine.providerId])

let ref = 0
const booking = async (providerId, status, paid, refunded = 0) => {
  ref++
  // **والطوابعُ الزمنيّةُ شرطٌ في الجدول لا زينة**: `confirmed` تحمل وقتَ
  // تأكيدها، وكلُّ حالِ إغلاقٍ تحمل وقتَها — ولا يحملها حجزٌ قائم.
  const closed = ['cancelled', 'rejected', 'expired'].includes(status)
  await db.query(
    `insert into public.bookings
       (reference, user_id, user_name, provider_id, provider_name, service_id,
        service_title, event_date, address, guests_count, total_price,
        deposit_amount, paid_amount, refunded_amount, status,
        confirmed_at, cancelled_at)
     values ($1, $2, 'أحمد الشرعبي', $3, 'قاعة', $4, 'باقة',
             current_date + 30, 'صنعاء', 100, 1000000, 100000, $5, $6, $7,
             $8, $9)`,
    [`BK-C-${ref}`, customerId, providerId, svc[0].id, paid, refunded, status,
     status === 'confirmed' ? new Date() : null,
     closed ? new Date() : null])
}

await booking(mine.providerId, 'completed', 500000)
await booking(mine.providerId, 'completed', 400000, 50000)
await booking(mine.providerId, 'cancelled', 0)
await booking(mine.providerId, 'rejected', 0)
await booking(mine.providerId, 'confirmed', 100000)
// ومع غيري — لا يجب أن تُحسب
await booking(other.providerId, 'completed', 900000)

// ── ١. البطاقةُ لصاحبها ─────────────────────────────────────────────────────
const { rows: mineCard } = await as(mine.auth,
  `select * from public.api_customer_card($1)`, [mineConvo])

ok('البطاقةُ تُرجع صفّاً واحداً', mineCard.length === 1, String(mineCard.length))
const c = mineCard[0]
ok('واسمُ العميل فيها', c.full_name === 'أحمد الشرعبي')
ok('وصورتُه', c.avatar_path === 'u1/avatar-7.jpg', String(c.avatar_path))
ok('ومحافظتُه', c.governorate === 'صنعاء', String(c.governorate))

// ── ٢. **ولا شيءَ غير ذلك من صفّه** ────────────────────────────────────────
//
// **وهذا لبُّ الأمر.** الدالّةُ `security definer` ترى الصفَّ كلَّه، فما
// يمنعها من إخراج البريد إلّا ما كُتب في جسدها. فتُعدّ أعمدتُها.
const cols = Object.keys(c)
ok('وأعمدتُها تسعةٌ لا غير', cols.length === 9, cols.join('، '))
for (const forbidden of ['email', 'phone', 'status', 'auth_user_id', 'app_version']) {
  ok(`ولا ${forbidden} فيها`, !cols.includes(forbidden))
}
const values = Object.values(c).map(String).join(' ')
ok('ولا أثرَ لبريدٍ في القيم', !values.includes('@'))
ok('ولا أثرَ لجوّالٍ في القيم', !values.includes('770000000'))

// ── ٣. والحسابُ معه هو ──────────────────────────────────────────────────────
ok('وحجوزاتُه معي خمسةٌ لا ستّة', c.bookings_count === 5, String(c.bookings_count))
ok('والمكتملةُ اثنتان', c.completed_count === 2, String(c.completed_count))
ok('والملغاةُ اثنتان — الملغى والمرفوض', c.cancelled_count === 2,
   String(c.cancelled_count))
ok('والقادمةُ واحدة', c.upcoming_count === 1, String(c.upcoming_count))
// **وما دُفع ناقصَ ما رُدّ**: ٥٠٠٬٠٠٠ + (٤٠٠٬٠٠٠ − ٥٠٬٠٠٠) + ١٠٠٬٠٠٠
ok('وإجماليُّ ما دُفع ناقصَ ما رُدّ', Number(c.total_paid) === 950000,
   String(c.total_paid))
ok('وأوّلُ حجزٍ مؤرّخ', c.first_booking_at !== null)

// ── ٤. **ولا تعمل لغير أهلها** ─────────────────────────────────────────────
await mustFail('ومقدّمُ خدمةٍ آخرُ لا يقرأ محادثةً ليست له',
  () => as(other.auth, `select * from public.api_customer_card($1)`, [mineConvo]),
  'ليست لك')

await mustFail('والعميلُ نفسُه لا يستدعيها',
  () => as(custAuth, `select * from public.api_customer_card($1)`, [mineConvo]),
  'لمقدّمي الخدمة')

await mustFail('ومن لا جلسةَ له لا يستدعيها',
  () => as(null, `select * from public.api_customer_card($1)`, [mineConvo]),
  'لمقدّمي الخدمة')

await mustFail('ومعرّفٌ لا وجودَ له يُردّ',
  () => as(mine.auth, `select * from public.api_customer_card($1)`,
           ['00000000-0000-0000-0000-000000000000']),
  'ليست لك')

// وصاحبُ المحادثة الأخرى يقرأ بطاقتَه هو — فالرفضُ ليس رفضاً للجميع
const { rows: otherCard } = await as(other.auth,
  `select * from public.api_customer_card($1)`, [otherConvo])
ok('وصاحبُ المحادثة الأخرى يقرأ بطاقتَه', otherCard.length === 1)
ok('وحجوزاتُه معه واحدةٌ لا خمس', otherCard[0].bookings_count === 1,
   String(otherCard[0].bookings_count))

// ── ٥. **والمنحةُ نفسُها تُقاس، لا أثرُها فقط** ────────────────────────────
//
// **وهذا ضابطٌ وُلد من ضابطٍ لم يسقط.** كُتب كسرٌ يمنح الدالّةَ لـ`anon`
// ويجعلها `security invoker`، **فبقيت الحزمةُ خضراء** — لا لأنّ المنحةَ
// سليمةٌ بأيّ صورة، بل لأنّ PGlite يشغّل كلَّ شيءٍ بصلاحية المالك، فلا
// يُمارَس دورٌ ولا تُختبر منحة. فصار الفحصُ على الكتالوج نفسِه.
const { rows: grantRows } = await db.query(`
  select
    p.prosecdef as definer,
    has_function_privilege('anon', p.oid, 'execute')          as anon_may,
    has_function_privilege('authenticated', p.oid, 'execute') as auth_may
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'api_customer_card'`)

const g = grantRows[0]
ok('والدالّةُ `security definer`', g?.definer === true, String(g?.definer))
ok('**ولا تُمنح لمن لا حساب له (`anon`)**', g?.anon_may === false,
   String(g?.anon_may))
ok('وتُمنح لمن سجّل دخولَه', g?.auth_may === true, String(g?.auth_may))

await db.close()
console.log(fail === 0 ? '\nكل اختبارات customer_card.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
