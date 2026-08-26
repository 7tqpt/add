/**
 * التقويم: يوم يُغلق بحجز، ويوم يُغلق بعذر — وكلاهما يُفتح.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. أن الإلغاء **يفتح** اليوم — وهو العطب الذي كان: يُغلق عند التأكيد ولا
 *      يُفتح أبداً، فيخسر المزوّد مواسمه ولا يعلم.
 *   ٢. وأن الفتح **مشروطٌ بصاحبه**: يومٌ أغلقه المزوّد بعذر لا يفتحه إلغاءُ
 *      حجزٍ صادف تاريخَه.
 *   ٣. وأن المزوّد لا يفتح يوماً فيه حجزٌ مؤكّد — وإلّا وقع عرسان في ليلة.
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
                 'invitations.sql']) {
  await db.exec(read(f))
}
const file = read('availability.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: مزوّدٌ بحساب، وحجزٌ له في يومٍ بعيد ──────────────────────────────
const puid = '44444444-4444-4444-4444-444444444444'
const provider = await one(`select id from public.service_providers order by id limit 1`)
await db.exec(`
  insert into auth.users (id, email) values ('${puid}', 'p@sdd.company')
    on conflict (id) do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status)
       values ('${puid}', 'صاحب قاعة', 'p@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = '${puid}';
  update public.service_providers
     set user_id = (select id from public.app_users where auth_user_id = '${puid}')
   where id = '${provider.id}';`)

const day = '2027-05-20'
const booking = await one(`
  update public.bookings
     set provider_id = $1, event_date = $2, status = 'pending_provider',
         cancelled_at = null
   where id = (select id from public.bookings order by reference limit 1)
  returning id, reference`, [provider.id, day])

const blocked = async (d) => Number((await one(
  `select count(*) as ع from public.provider_availability
    where provider_id = $1 and day = $2`, [provider.id, d])).ع)

// ── ١. التأكيد يغلق، والإلغاء يفتح ──────────────────────────────────────────
const confirm = (id) => db.query(
  `update public.bookings set status = 'confirmed', confirmed_at = now(),
          cancelled_at = null where id = $1`, [id])
// القيد `closed_needs_timestamp` يلزم كل حالة إغلاقٍ وقتَها، فلا تُكتب الحالة
// وحدها — والاختبار يكتب كما تكتب الدوال لا كما يشتهي.
const close = (id) => db.query(
  `update public.bookings set status = 'cancelled', cancelled_at = now()
    where id = $1`, [id])

await confirm(booking.id)
ok('التأكيد يغلق اليوم', (await blocked(day)) === 1)

await close(booking.id)
ok('والإلغاء يفتحه — وهذا هو العطب الذي كان', (await blocked(day)) === 0)

// ── ٢. ويومٌ أغلقه صاحبه بعذر لا يفتحه إلغاءُ حجز ────────────────────────────
//
// **وهذا ما ينكسر بصمت:** حذفٌ بالتاريخ وحده يفتح ما لم يُغلقه هذا الحجز.
await db.exec(`select set_config('test.uid', '${puid}', false)`)
await db.exec(`set role authenticated`)
await db.query(`select public.api_set_availability($1, true, 'سفر')`, [day])
await db.exec(`reset role`)

await confirm(booking.id)
await close(booking.id)
const note = (await one(
  `select note from public.provider_availability where provider_id = $1 and day = $2`,
  [provider.id, day]))
ok('عذرُ صاحبه يبقى بعد إلغاء حجزٍ في يومه', note?.note === 'سفر')

// ── ٣. المزوّد يفتح يومه الذي أغلقه ─────────────────────────────────────────
await db.exec(`select set_config('test.uid', '${puid}', false)`)
await db.exec(`set role authenticated`)
await db.query(`select public.api_set_availability($1, false)`, [day])
await db.exec(`reset role`)
ok('ويفتح ما أغلقه بنفسه', (await blocked(day)) === 0)

// ── ٤. ولا يفتح يوماً فيه حجزٌ مؤكّد ────────────────────────────────────────
await confirm(booking.id)
await db.exec(`select set_config('test.uid', '${puid}', false)`)
await db.exec(`set role authenticated`)
let raised = null
try {
  await db.query(`select public.api_set_availability($1, false)`, [day])
} catch (e) { raised = e.message }
ok('ولا يفتح يوماً فيه حجزٌ مؤكّد', /محجوز/.test(raised ?? ''))
ok('واليوم ما زال مغلقاً بعد المحاولة', (await blocked(day)) === 1)

// ── ٥. ولا يعدّل يوماً مضى ──────────────────────────────────────────────────
raised = null
try {
  await db.query(`select public.api_set_availability(current_date - 1, true, 'أمس')`)
} catch (e) { raised = e.message }
ok('ولا يُعدَّل يومٌ مضى', /مضى/.test(raised ?? ''))

// ── ٦. والعميل يرى التواريخ ولا يرى الملاحظات ───────────────────────────────
// `returns setof date` تُسمّي عمودها باسم الدالّة لا `day`، فيُسمّى صراحةً —
// وقارئٌ بالاسم الخطأ يجد `undefined` فيسقط الاختبار على شكل النتيجة لا على
// معناها.
const days = await rows(
  `select * from public.api_blocked_days($1, $2, $3) as t(day)`,
  [provider.id, '2027-01-01', '2027-12-31'])
const asIso = (v) => (v instanceof Date ? v.toISOString().slice(0, 10) : String(v).slice(0, 10))
ok('العميل يرى اليوم المشغول', days.some((r) => asIso(r.day) === day))

raised = null
try {
  await db.exec(`set role authenticated`)
  await db.query(`select note from public.provider_availability limit 1`)
} catch (e) { raised = e.message }
await db.exec(`reset role`)
ok('ولا يقرأ ملاحظة غيره (رقم حجزه)', /permission denied|note/i.test(raised ?? ''))

// ── ٧. ومن ليس مزوّداً لا يكتب في تقويم أحد ─────────────────────────────────
const cuid = '55555555-5555-5555-5555-555555555555'
await db.exec(`
  insert into auth.users (id, email) values ('${cuid}', 'c2@sdd.company')
    on conflict (id) do nothing;`)
await db.exec(`select set_config('test.uid', '${cuid}', false)`)
await db.exec(`set role authenticated`)
raised = null
try {
  await db.query(`select public.api_set_availability('2027-06-01', true, 'x')`)
} catch (e) { raised = e.message }
ok('ومن ليس مزوّداً يُردّ', /لمقدّمي الخدمة/.test(raised ?? ''))
await db.exec(`reset role`)

// ── فتحُ يومٍ لا صفَّ له: `null` لا صفٌّ من الأصفار ──────────────────────────
//
// **وهذا عطبٌ رآه صاحبُ المنصّة على جواله:** ضغطتان متتاليتان على «افتحه» —
// أو يومٌ حرّره إلغاءُ حجزٍ بين فتح الشاشة والضغط — والحذفُ لا يطابق شيئاً.
// و`returning * into row` حينئذٍ يترك `row` بحقولٍ كلُّها فارغة، و`return row`
// عليها يُخرج كائناً `{"day": null, …}` **لا `null`**. فيقرأ التطبيق `day`
// ويحوّله نصّاً فيسقط:
//
//     type 'Null' is not a subtype of type 'String' in type cast
//
// رسالةٌ إنجليزيةٌ في وجه صاحب القاعة مكان تقويمه.
await db.exec(`select set_config('test.uid', '${puid}', false)`)
await db.exec(`set role authenticated`)
const empty = await one(
  `select public.api_set_availability(current_date + 40, false) as ص`)
ok('فتحُ يومٍ لا صفَّ له يُعيد فراغاً لا صفّاً من الأصفار', empty.ص === null)
await db.exec(`reset role`)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات availability.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
