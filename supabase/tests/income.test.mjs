/**
 * دخلُ المنصّة: ثلاثةُ أبوابٍ في رقمٍ واحد — ونقديٌّ لا استحقاقيّ.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. أن **المعلَّق لا يُحسب**. حجزٌ بمليونٍ أُنشئ ولم تُؤكَّد حوالتُه يرفع
 *      «العمولة» في اللوحة القديمة مئةَ ألفٍ لم تدخل الخزنة. وهذا الرقم
 *      يُصدَّق ويُبنى عليه قرارُ إنفاق.
 *   ٢. وأن البابين الجديدين — الاشتراك والإعلان — يظهران فعلاً: بُنيا ولم
 *      يكن في اللوحة مكانٌ يعرضهما، فكان صاحبُ المنصّة يرى ثلثَ دخله.
 *   ٣. وأن المستردَّ **يُطرح**: رقمٌ لا يطرحه يكذب إلى أعلى دائماً.
 *   ٤. وأن يوماً بلا دخلٍ صفرٌ لا فجوة — الفجوةُ تُزحزح الرسم وتُري صعوداً
 *      لم يقع.
 *   ٥. وأن من لا يملك قراءة المال لا يقرأ الأرقام.
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
const file = read('income.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: مسؤولٌ مالك، ومسؤولٌ لا يقرأ المال ───────────────────────────────
const auid = 'aaaa1111-0000-0000-0000-000000000001'
const suid = 'aaaa1111-0000-0000-0000-000000000002'
await db.exec(`
  insert into auth.users (id, email) values
    ('${auid}', 'owner@sdd.company'), ('${suid}', 'help@sdd.company')
  on conflict (id) do nothing;
  insert into public.admins (user_id, email, role) values
    ('${auid}', 'owner@sdd.company', 'owner'),
    ('${suid}', 'help@sdd.company',  'support')
  on conflict (user_id) do update set role = excluded.role;`)

// دفترٌ نظيف: بيانات العرض فيها دفعاتٌ بتواريخَ شتّى، وقياسُ رقمٍ فوقها
// يقيس البذرة لا الدالّة.
await db.exec(`delete from public.payments`)

const provider = await one(
  `select id, business_name from public.service_providers order by id limit 1`)
const customer = await one(`select id, full_name from public.app_users order by email limit 1`)

const pay = async (kind, amount, share, status, daysAgo) => db.query(
  `insert into public.payments
     (reference, user_id, user_name, provider_id, provider_name,
      kind, amount, platform_share, net_amount, status, created_at)
   values ('PM-' || substr(md5(random()::text), 1, 8), $1, $2, $3, $4,
           $5, $6::numeric, $7::numeric, $6::numeric - $7::numeric, $8, now() - make_interval(days => $9::int))`,
  [customer.id, customer.full_name, provider.id, provider.business_name,
   kind, amount, share, status, daysAgo])

// عربونٌ تأكّد: مليونٌ، حصّةُ المنصّة مئةُ ألف.
await pay('deposit', 1000000, 100000, 'paid', 3)
// وعربونٌ **معلَّق** بالحجم نفسه — وهو محكُّ الاختبار كلِّه.
await pay('deposit', 1000000, 100000, 'pending', 3)
// اشتراكٌ وإعلانٌ تأكّدا.
await pay('subscription', 50000, 0, 'paid', 3)
await pay('promotion', 14000, 0, 'paid', 3)

const asOwner = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${auid}', false)`)
  await db.exec(`set role authenticated`)
}
const asSupport = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${suid}', false)`)
  await db.exec(`set role authenticated`)
}

// ── ١. المعلَّق لا يُحسب ─────────────────────────────────────────────────────
await asOwner()
const day = await one(
  `select * from public.api_admin_income(current_date - 5, current_date)
    where day = (current_date - 3)`)

ok('العمولةُ من المحصَّل وحده لا من المعلَّق', Number(day.commission) === 100000)
ok('والاشتراكُ بابٌ مستقلّ',                  Number(day.subscriptions) === 50000)
ok('والإعلانُ كذلك',                          Number(day.promotions) === 14000)

const total = await one(
  `select sum(commission + subscriptions + promotions) as كل
     from public.api_admin_income(current_date - 5, current_date)`)
ok('والمجموع يجمع الأبواب الثلاثة', Number(total.كل) === 164000)

// ── ٢. والمستردُّ يُطرح ─────────────────────────────────────────────────────
await db.exec(`reset role`)
await pay('refund', 300000, 30000, 'paid', 3)
await asOwner()
const afterRefund = await one(
  `select commission from public.api_admin_income(current_date - 5, current_date)
    where day = (current_date - 3)`)
ok('واستردادٌ يُنقص العمولة بحصّته', Number(afterRefund.commission) === 70000)

// ── ٣. ويومٌ بلا دخلٍ صفرٌ لا فجوة ───────────────────────────────────────────
const span = await rows(
  `select * from public.api_admin_income(current_date - 5, current_date)`)
ok('كلُّ يومٍ في المدّة له صفّ', span.length === 6)
const quiet = span.find((r) => Number(r.commission) === 0 &&
                               Number(r.subscriptions) === 0 &&
                               Number(r.promotions) === 0)
ok('واليومُ الساكن صفرٌ صريح', quiet !== undefined)

// ── ٤. وما خرج عن المدّة لا يدخل الرقم ──────────────────────────────────────
await db.exec(`reset role`)
await pay('subscription', 999999, 0, 'paid', 40)
await asOwner()
const bounded = await one(
  `select coalesce(sum(subscriptions), 0) as ج
     from public.api_admin_income(current_date - 5, current_date)`)
ok('ودفعةٌ خارج المدّة لا تُحسب', Number(bounded.ج) === 50000)

// ── ٥. ومن لا يقرأ المال لا يرى أرقامه ──────────────────────────────────────
//
// **والحارسُ في الدالّة لا في الشاشة:** أيُّ حاملِ جلسةٍ ينادي `rpc` مباشرةً.
await asSupport()
const hidden = await one(
  `select coalesce(sum(commission + subscriptions + promotions), 0) as ج
     from public.api_admin_income(current_date - 5, current_date)`)
ok('مسؤولُ الدعم لا يقرأ دخل المنصّة', Number(hidden.ج) === 0)
await db.exec(`reset role`)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات income.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
