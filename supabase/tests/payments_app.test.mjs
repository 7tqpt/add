/**
 * الدفع من التطبيق: من يُبلّغ، وبكم، ومن يؤكّد.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. **المبلغ من الحجز لا من المتصل** — لا مُعامِل له أصلاً، فلا سبيل إلى
 *      دفع عربون قاعةٍ بريالٍ واحد.
 *   ٢. أن حجزَ غيرِك لا تدفع عنه.
 *   ٣. أن الإبلاغ يقع **معلّقاً** لا مدفوعاً: المال لم يصل حتى يُرى.
 *   ٤. وأن التأكيد يزيد `paid_amount` مرّةً واحدة مهما تكرّر النداء.
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
const file = read('payments_app.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows

// ── تجهيز: عميلٌ بحساب مصادقة، وحجزٌ له ──────────────────────────────────────
const uid = '22222222-2222-2222-2222-222222222222'
const [customer] = await rows(`select id from public.app_users limit 1`)
await db.exec(`
  insert into auth.users (id, email) values ('${uid}', 'c@sdd.company')
    on conflict (id) do nothing;
  update public.app_users set auth_user_id = '${uid}' where id = '${customer.id}';`)

const [booking] = await rows(`
  update public.bookings
     set user_id = $1, status = 'confirmed', confirmed_at = now(),
         cancelled_at = null, total_price = 800000,
         deposit_amount = 240000, paid_amount = 0, refunded_amount = 0
   where id = (select id from public.bookings limit 1)
  returning *`, [customer.id])

// حجزُ غيره يُجلب **قبل** تبديل الدور: سياسةُ الصفوف تُخفي حجوزات الآخرين عن
// العميل، فاستعلامٌ عنها بعد التبديل يعود فارغاً — ويسقط الاختبار على غياب
// الصفّ لا على غياب الحراسة.
const [other] = await rows(
  `select id from public.bookings where id <> $1 limit 1`, [booking.id])

await db.exec(`set role authenticated`)
await db.exec(`select set_config('test.uid', '${uid}', false)`)

// ── ١. الإبلاغ: المبلغ محسوبٌ، والحالة معلّقة ────────────────────────────────
const [pay] = await rows(
  `select * from public.api_submit_payment($1, 'jawali', 'deposit', '77712345')`,
  [booking.id])
ok('المبلغ عربونُ الحجز كما حسبته القاعدة', Number(pay.amount) === 240000)
ok('والحالة معلّقة لا مدفوعة', pay.status === 'pending')
ok('ولا يتحرّك المدفوع قبل التأكيد',
   Number((await rows(`select paid_amount from public.bookings where id = $1`, [booking.id]))[0]
     .paid_amount) === 0)

// ── ٢. ولا إبلاغَ ثانٍ فوق معلّق ─────────────────────────────────────────────
let raised = null
try {
  await db.query(`select public.api_submit_payment($1, 'jawali')`, [booking.id])
} catch (e) { raised = e.message }
ok('وإبلاغٌ ثانٍ فوق معلّقٍ يُردّ', /قيد التأكيد/.test(raised ?? ''))

// ── ٣. وحجزُ غيرك لا تدفع عنه ────────────────────────────────────────────────
raised = null
try {
  await db.query(`select public.api_submit_payment($1, 'jawali')`, [other.id])
} catch (e) { raised = e.message }
ok('وحجزُ غيرك يُردّ', /ليس لك/.test(raised ?? ''))

// ── ٤. والعميل لا يؤكّد لنفسه ────────────────────────────────────────────────
raised = null
try {
  await db.query(`select public.api_admin_confirm_payment($1)`, [pay.id])
} catch (e) { raised = e.message }
ok('والعميل لا يؤكّد دفعته بنفسه', /صلاحية/.test(raised ?? ''))

// ── ٥. المسؤول يؤكّد: يزيد المدفوع مرّةً واحدة ───────────────────────────────
await db.exec(`reset role`)
// المسؤول في `admins` مفتاحُه `user_id` من `auth.users` مباشرةً — لا صفٌّ في
// `app_users`. ويُنشأ هنا مالكاً: `can_write()` تُبنى على دوره.
const auid = '33333333-3333-3333-3333-333333333333'
await db.exec(`
  insert into auth.users (id, email) values ('${auid}', 'a@sdd.company')
    on conflict (id) do nothing;
  insert into public.admins (user_id, email, role)
       values ('${auid}', 'a@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';`)
await db.exec(`select set_config('test.uid', '${auid}', false)`)
await db.exec(`set role authenticated`)

const [confirmed] = await rows(
  `select * from public.api_admin_confirm_payment($1, 'REF-1')`, [pay.id])
ok('الحالة صارت مدفوعة', confirmed.status === 'paid')
ok('والمدفوع في الحجز زاد بالمبلغ',
   Number((await rows(`select paid_amount from public.bookings where id = $1`, [booking.id]))[0]
     .paid_amount) === 240000)

// وإعادةُ التأكيد لا تُضاعف — الخطّاف قد يُنادى مرّتين.
await db.query(`select public.api_admin_confirm_payment($1, 'REF-1')`, [pay.id])
ok('وإعادةُ التأكيد لا تُضاعف المبلغ',
   Number((await rows(`select paid_amount from public.bookings where id = $1`, [booking.id]))[0]
     .paid_amount) === 240000)

// ── ٦. والباقي بعد العربون يُحسب على ما بقي ──────────────────────────────────
await db.exec(`select set_config('test.uid', '${uid}', false)`)
const [balance] = await rows(
  `select * from public.api_submit_payment($1, 'kuraimi', 'balance')`, [booking.id])
ok('الباقي = الإجمالي ناقص المدفوع', Number(balance.amount) === 560000)

await db.exec(`reset role`)
await db.close()
console.log(fail === 0 ? '\nكل اختبارات payments_app.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
