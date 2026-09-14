/**
 * مراجعةُ الإدارة لتنفيذ الحجز.
 *
 * ── وأخطرُ ما يُقاس هنا ─────────────────────────────────────────────────────
 *
 * **١) أنّ المزوّد لم يعد يملك أن يُتمّ حجزَه.** وهذا لبُّ الطلب كلِّه:
 * `api_complete_booking` كانت تقبل صاحبَ الحجز، فمن فكّ ملفَّ APK ونادى
 * الدالّةَ مباشرةً أتمّ حجزَه وزاد مستحقّاتِه بلا مراجعة. وحارسٌ في
 * `requests.dart` لا يحرس من ذلك شيئاً.
 *
 * **٢) وأنّ الطلبَ لا يُحرّك مالاً.** `total_earnings` و`completed_bookings`
 * لا تتغيّران قبل الاعتماد — وهي الحالةُ التي لو انكسرت لَدفعت المنصّةُ عن
 * عملٍ لم يُراجَع، ولا تُرى في شاشة.
 *
 * **٣) وأنّ الاعتمادَ يفعل ما كان يفعله الضغطُ من قبل** — الحالة والعدّادات
 * وبابُ التقييم — فلا يضيع شيءٌ في الطريق.
 *
 * **٤) والردُّ يُعيد الحجزَ قابلاً لطلبٍ جديد** بسببٍ يقرؤه المزوّد؛ ولا
 * يدور الطابورُ على نفسه.
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
const file = read('completion_review.sql')
await db.exec(file)
await db.exec(file) // إعادةُ التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond, extra = '') => {
  console.log(`${cond ? '✅' : '❌'} ${label}${cond || !extra ? '' : ` — ${extra}`}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: مزوّدٌ بحساب، ومسؤولٌ بصلاحية الحجوزات، وحجزٌ مؤكَّد ─────────────
const PUID = '44444444-4444-4444-4444-444444444444'
const AUID = '55555555-5555-5555-5555-555555555555'
const OUID = '66666666-6666-6666-6666-666666666666' // مزوّدٌ آخر
const FUID = '77777777-7777-7777-7777-777777777777' // محاسبٌ: يقرأ ولا يكتب

const both = await rows(`select id from public.service_providers order by id limit 2`)
const provider = both[0]
const other = both[1]

await db.exec(`
  insert into auth.users (id, email) values
    ('${PUID}', 'p@sdd.company'), ('${AUID}', 'a@sdd.company'),
    ('${OUID}', 'o@sdd.company'), ('${FUID}', 'f@sdd.company')
  on conflict (id) do nothing;

  insert into public.app_users (auth_user_id, full_name, email, status)
       values ('${PUID}', 'صاحب قاعة', 'p@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = '${PUID}';

  insert into public.app_users (auth_user_id, full_name, email, status)
       values ('${OUID}', 'صاحب قاعةٍ أخرى', 'o@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = '${OUID}';

  update public.service_providers
     set user_id = (select id from public.app_users where auth_user_id = '${PUID}')
   where id = '${provider.id}';

  -- **ومزوّدٌ ثانٍ بملفٍّ حقيقيّ.** بلا ملفٍّ يسقط النداءُ على «لا ملفَّ
  -- مزوّدٍ لهذا الحساب» قبل أن يبلغ حارسَ الملكيّة — فيمرّ الاختبارُ وهو
  -- لا يقيس ما يظنّ. كشفه ضابطٌ سالب.
  update public.service_providers
     set user_id = (select id from public.app_users where auth_user_id = '${OUID}')
   where id = '${other.id}';

  -- ومسؤولٌ يقرأ الحجوزات ولا يكتبها: المحاسبُ مجالُه المال لا الحجوزات.
  insert into public.admins (user_id, email, role)
       values ('${FUID}', 'f@sdd.company', 'finance')
  on conflict (user_id) do update set role = 'finance';

  insert into public.admins (user_id, email, role)
       values ('${AUID}', 'a@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';
`)

const booking = await one(`
  update public.bookings
     set provider_id = $1, status = 'confirmed', confirmed_at = now(),
         cancelled_at = null, completed_at = null,
         total_price = 100000, deposit_amount = 30000, paid_amount = 30000,
         commission_amount = 10000
   where id = (select id from public.bookings order by reference limit 1)
  returning id, reference, user_id`, [provider.id])

// **والهويّةُ للجلسة لا للمعاملة.** `set local` و`set_config(..., true)`
// ينتهيان بانتهاء المعاملة، وكلُّ نداءٍ هنا معاملةٌ وحدَه.
const as = async (uid, sql, params) => {
  await db.exec(`set role authenticated; select set_config('test.uid', '${uid}', false);`)
  try {
    return await db.query(sql, params)
  } finally {
    await db.exec('reset role')
  }
}

const earnings = async () => Number((await one(
  `select total_earnings, completed_bookings from public.service_providers
    where id = $1`, [provider.id])).total_earnings)
const doneCount = async () => Number((await one(
  `select completed_bookings from public.service_providers where id = $1`,
  [provider.id])).completed_bookings)
const state = () => one(
  `select status, completed_at, completion_requested_at, completion_rejected_at,
          completion_reject_reason
     from public.bookings where id = $1`, [booking.id])

const before = { earnings: await earnings(), done: await doneCount() }

// ── ١) المزوّد لا يملك الإتمام — وهذا لبُّ الطلب ────────────────────────────
{
  let threw = ''
  try {
    await as(PUID, `select public.api_complete_booking($1)`, [booking.id])
  } catch (e) { threw = String(e.message || e) }
  ok('**المزوّد لا يُتمّ حجزَه بنفسه**', /للإدارة وحدَها/.test(threw), threw || 'لم تُرمَ')

  const s = await state()
  ok('ولا تغيّرت حالُ الحجز بمحاولته', s.status === 'confirmed')
  ok('ولا زادت مستحقّاتُه', (await earnings()) === before.earnings)
}

// ── ٢) والطلبُ يُختم ولا يُحرّك مالاً ───────────────────────────────────────
{
  await as(PUID, `select public.api_request_completion($1)`, [booking.id])
  const s = await state()
  ok('طلبُ الاعتماد يُختم بوقته', s.completion_requested_at !== null)
  ok('**والحجزُ يبقى مؤكَّداً** — لا حالةَ سابعةَ في status', s.status === 'confirmed')
  ok('**ولا يُحرَّك مالٌ قبل المراجعة**', (await earnings()) === before.earnings,
    `صارت ${await earnings()} وكانت ${before.earnings}`)
  ok('ولا عدّادُ المنفَّذ', (await doneCount()) === before.done)
}

// ── ٣) ولا يطلب أحدٌ اعتمادَ حجزِ غيره ──────────────────────────────────────
{
  let threw = ''
  try {
    await as(OUID, `select public.api_request_completion($1)`, [booking.id])
  } catch (e) { threw = String(e.message || e) }
  ok('ولا يطلب أحدٌ اعتمادَ حجزِ غيره', /ليس لك/.test(threw), threw || 'لم تُرمَ')
}

// ── ٣ب) ولا يعتمد مسؤولٌ لا يملك مجالَ الحجوزات ─────────────────────────────
//
// **والسؤالُ «أتملك الحجوزات؟» لا «أمسؤولٌ أنت؟».** المحاسبُ يقرأ الحجوزات
// ولا يكتبها، ولو اعتمد لَصرف مالاً ليس من مجاله. كشفه ضابطٌ سالب: كان
// الاختبارُ يمرّ والحارسُ مُبدَّلٌ بـ`is_admin()`.
{
  let threw = ''
  try {
    await as(FUID, `select public.api_complete_booking($1)`, [booking.id])
  } catch (e) { threw = String(e.message || e) }
  ok('**ولا يعتمد محاسبٌ ولا مطّلع** — المجالُ لا الصفة',
    /للإدارة وحدَها/.test(threw), threw || 'لم تُرمَ')

  let threw2 = ''
  try {
    await as(FUID, `select public.api_reject_completion($1, 'لا')`, [booking.id])
  } catch (e) { threw2 = String(e.message || e) }
  ok('ولا يردّ طلباً', /للإدارة وحدَها/.test(threw2), threw2 || 'لم تُرمَ')
}

// ── ٤) والردُّ يُعيده قابلاً لطلبٍ جديد، بسبب ───────────────────────────────
{
  let threw = ''
  try {
    await as(AUID, `select public.api_reject_completion($1, '  ')`, [booking.id])
  } catch (e) { threw = String(e.message || e) }
  ok('**والردُّ بلا سببٍ يُرفض** — وإلّا دار الطابورُ على نفسه',
    /سببَ الردّ/.test(threw), threw || 'لم تُرمَ')

  await as(AUID, `select public.api_reject_completion($1, 'العربون لم يصل بعد')`,
    [booking.id])
  const s = await state()
  ok('الردُّ يمسح الطلب', s.completion_requested_at === null)
  ok('ويحفظ سببَه', s.completion_reject_reason === 'العربون لم يصل بعد')
  ok('والحجزُ ما زال مؤكَّداً', s.status === 'confirmed')

  const note = await one(
    `select body from public.notifications
      where provider_id = $1 order by created_at desc limit 1`, [provider.id])
  ok('والسببُ يصل المزوّدَ إشعاراً', note?.body === 'العربون لم يصل بعد',
    note?.body ?? 'لا إشعار')

  // ويُعاد الطلبُ فيُمحى أثرُ الردّ.
  await as(PUID, `select public.api_request_completion($1)`, [booking.id])
  const again = await state()
  ok('ويُعاد الطلبُ بعد الردّ', again.completion_requested_at !== null)
  ok('ويُمحى أثرُ الردّ معه', again.completion_reject_reason === '')
}

// ── ٥) والاعتمادُ يفعل ما كان يفعله الضغطُ من قبل ───────────────────────────
{
  await as(AUID, `select public.api_complete_booking($1)`, [booking.id])
  const s = await state()
  ok('**الاعتمادُ يُتمّ الحجز**', s.status === 'completed')
  ok('ويختم وقتَ التنفيذ', s.completed_at !== null)
  ok('ويُنظّف طلبَ الاعتماد', s.completion_requested_at === null)

  const net = 100000 - 10000
  ok('**والمستحقّاتُ تزيد بصافي الحجز**', (await earnings()) === before.earnings + net,
    `صارت ${await earnings()} والمنتظَر ${before.earnings + net}`)
  ok('وعدّادُ المنفَّذ يزيد واحداً', (await doneCount()) === before.done + 1)

  const review = await one(
    `select kind from public.notifications
      where user_id = $1 and kind = 'review' order by created_at desc limit 1`,
    [booking.user_id])
  ok('**وبابُ التقييم يُفتح للعميل** — وهو ما يتأخّر بهذا التغيير كلِّه',
    review?.kind === 'review')
}

// ── ٦) ولا يُطلب اعتمادُ حجزٍ منفَّذ ────────────────────────────────────────
{
  let threw = ''
  try {
    await as(PUID, `select public.api_request_completion($1)`, [booking.id])
  } catch (e) { threw = String(e.message || e) }
  ok('ولا يُطلب اعتمادُ حجزٍ غيرِ مؤكَّد', /غيرِ مؤكَّد/.test(threw), threw || 'لم تُرمَ')
}

console.log(fail === 0
  ? '\nكل اختبارات completion_review.sql نجحت.'
  : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
