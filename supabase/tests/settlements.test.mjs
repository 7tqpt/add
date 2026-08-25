/**
 * التسويات: ما تدين به المنصّة، محسوباً لا مقدَّراً.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. أن المحتسَب هو **المقبوض** لا السعر: المنصّة لا تسلّم ما لم تقبضه.
 *   ٢. وأن حجزاً واحداً لا يدخل تسويتين — وإلّا دُفع مرّتين.
 *   ٣. وأن عمولةً تفوق المقبوض تقف عند الصفر ولا تُسقط الاحتساب بقيد.
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
const file = read('settlements.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: مسؤولٌ مالك، وحجزان منفَّذان لمزوّدٍ واحد ────────────────────────
const auid = '99999999-9999-9999-9999-999999999999'
await db.exec(`
  delete from public.settlement_items;
  delete from public.settlements;
  insert into auth.users (id, email) values ('${auid}', 'a4@sdd.company')
    on conflict (id) do nothing;
  insert into public.admins (user_id, email, role)
       values ('${auid}', 'a4@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';`)

const provider = await one(`select id from public.service_providers order by id limit 1`)
// **بترتيبٍ ثابت وبتصفيرٍ صريح.** `limit 2` بلا `order by` تختار صفّين
// مختلفين في كل تشغيل، و`deposit_within_total` تسقط حين يكون عربونُ الصفّ
// المختار أكبر من السعر الذي يكتبه الاختبار. فمرّ الاختبار مرّتين وسقط في
// الثالثة — وهو أسوأ من ساقطٍ دائماً: يُنسب إلى الحظّ فيُعاد تشغيله حتى يمرّ.
const two = await rows(`select id from public.bookings order by reference limit 2`)

// حجزٌ منفَّذ: قُبض ٤٠٠٬٠٠٠ وعمولةُ المنصّة ٤٠٬٠٠٠ → الصافي ٣٦٠٬٠٠٠.
await db.query(`
  update public.bookings
     set provider_id = $1, status = 'completed', completed_at = now(),
         cancelled_at = null, confirmed_at = now(),
         event_date = date '2027-03-10',
         total_price = 400000, deposit_amount = 100000,
         paid_amount = 400000, refunded_amount = 0,
         commission_amount = 40000
   where id = $2`, [provider.id, two[0].id])

// وحجزٌ لم يُقبض منه شيء: لا يدخل التسوية.
await db.query(`
  update public.bookings
     set provider_id = $1, status = 'completed', completed_at = now(),
         cancelled_at = null, confirmed_at = now(),
         event_date = date '2027-03-14',
         total_price = 200000, deposit_amount = 50000,
         paid_amount = 0, refunded_amount = 0,
         commission_amount = 20000
   where id = $2`, [provider.id, two[1].id])

// ولا تدخل حجوزاتُ البذرة الأخرى في الحساب: تُخرَج من الفترة.
await db.query(`
  update public.bookings set event_date = date '2020-01-01'
   where id <> $1 and id <> $2`, [two[0].id, two[1].id])

const asAdmin = async () => {
  await db.exec(`select set_config('test.uid', '${auid}', false)`)
  await db.exec(`set role authenticated`)
}

// ── ١. الاحتساب: المقبوض وحده ───────────────────────────────────────────────
await asAdmin()
const made = Number((await one(
  `select public.api_admin_build_settlements(date '2027-03-01', date '2027-03-31') as ع`)).ع)
await db.exec(`reset role`)

ok('تسويةٌ واحدة لمزوّدٍ واحد', made === 1)

const stl = await one(`select * from public.settlements order by created_at desc limit 1`)
ok('الإجمالي هو المقبوض لا السعر — الحجز غير المدفوع خارجها',
   Number(stl.gross_amount) === 400000)
ok('والعمولة كما في الحجز', Number(stl.commission_amount) === 40000)
ok('والصافي = المقبوض ناقص العمولة', Number(stl.net_amount) === 360000)
ok('وحالتها «معلّقة» حتى تُعتمد', stl.status === 'pending')

const items = await rows(
  `select booking_id from public.settlement_items where settlement_id = $1`, [stl.id])
ok('وبندٌ واحدٌ فيها — الحجز المقبوض وحده', items.length === 1)
ok('وهو الحجز الصحيح', items[0].booking_id === two[0].id)

// ── ٢. وإعادة الاحتساب لا تُنتج شيئاً ───────────────────────────────────────
//
// **وهذا ما ينكسر بصمت:** تسويةٌ ثانية على الحجز نفسه تعني دفعاً مرّتين — ولا
// يشتكي منها أحد.
await asAdmin()
const again = Number((await one(
  `select public.api_admin_build_settlements(date '2027-03-01', date '2027-03-31') as ع`)).ع)
await db.exec(`reset role`)
ok('إعادةُ الاحتساب لا تُنشئ تسويةً ثانية', again === 0)
ok('ولا صفَّ بندٍ زائد',
   Number((await one(`select count(*) as ع from public.settlement_items`)).ع) === 1)

// ── ٣. وعمولةٌ تفوق المقبوض تقف عند الصفر ولا تُسقط الاحتساب ────────────────
await db.query(`
  update public.bookings
     set paid_amount = 10000, commission_amount = 90000,
         event_date = date '2027-04-02'
   where id = $1`, [two[1].id])
await asAdmin()
const edge = Number((await one(
  `select public.api_admin_build_settlements(date '2027-04-01', date '2027-04-30') as ع`)).ع)
await db.exec(`reset role`)
ok('الاحتساب يقع ولا يسقط بقيد', edge === 1)
const odd = await one(`select * from public.settlements order by created_at desc limit 1`)
ok('والعمولة مقصورةٌ على المقبوض', Number(odd.commission_amount) === 10000)
ok('والصافي صفرٌ لا سالب', Number(odd.net_amount) === 0)

// ── ٤. ومن لا يملك المال لا يحتسب ───────────────────────────────────────────
const suid = 'aaaaaaaa-9999-9999-9999-999999999999'
await db.exec(`
  insert into auth.users (id, email) values ('${suid}', 'support@sdd.company')
    on conflict (id) do nothing;
  insert into public.admins (user_id, email, role)
       values ('${suid}', 'support@sdd.company', 'support')
  on conflict (user_id) do update set role = 'support';
  select set_config('test.uid', '${suid}', false);`)
await db.exec(`set role authenticated`)
let raised = null
try {
  await db.query(`select public.api_admin_build_settlements(date '2027-05-01', date '2027-05-31')`)
} catch (e) { raised = e.message }
ok('وخدمةُ العملاء لا تحتسب مستحقّات', /يملك الكتابة في المال/.test(raised ?? ''))
await db.exec(`reset role`)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات settlements.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
