/**
 * الإعلانات: من يشتري ظهوراً، ومتى يظهر.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. أن الظهور **لا يقع قبل وصول المال** — وإلّا ظهر من لم يدفع.
 *   ٢. وأن سعراً غير مضبوطٍ يُغلق البيع بدل أن يبيع بصفر.
 *   ٣. وأن المنتهي يخرج من الشريط — إعلانٌ لا ينتهي بيعٌ لمرّةٍ وأبد.
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
                 'invitations.sql', 'provider_logo.sql', 'payments_app.sql',
                 'subscriptions.sql']) {
  await db.exec(read(f))
}
const file = read('promotions.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز ───────────────────────────────────────────────────────────────────
const puid = 'bbbbbbbb-1111-1111-1111-111111111111'
const auid = 'cccccccc-1111-1111-1111-111111111111'
const provider = await one(
  `select id from public.service_providers where status = 'verified' order by id limit 1`)
await db.exec(`
  delete from public.promotions;
  insert into auth.users (id, email) values ('${puid}', 'p5@sdd.company')
    on conflict (id) do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status)
       values ('${puid}', 'صاحب قاعة', 'p5@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = '${puid}';
  update public.service_providers
     set user_id = (select id from public.app_users where auth_user_id = '${puid}')
   where id = '${provider.id}';

  insert into auth.users (id, email) values ('${auid}', 'a5@sdd.company')
    on conflict (id) do nothing;
  insert into public.admins (user_id, email, role)
       values ('${auid}', 'a5@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';`)

const asProvider = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${puid}', false)`)
  await db.exec(`set role authenticated`)
}
const asAdmin = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${auid}', false)`)
  await db.exec(`set role authenticated`)
}

// ── ١. بلا سعرٍ لا بيع ───────────────────────────────────────────────────────
//
// **وهذا ما ينكسر بصمت:** سعرٌ صفرٌ يعني إعلاناً مجّانياً للجميع، ولا يظهر
// ذلك في أي شاشة — تمتلئ الرئيسية بمن لم يدفع.
await db.exec(`update public.app_settings set promo_featured_daily = 0 where id = 1`)
await asProvider()
let raised = null
try {
  await db.query(`select public.api_request_promotion(7)`)
} catch (e) { raised = e.message }
ok('سعرٌ غير مضبوطٍ يُغلق البيع', /لم تُفتح مساحات الإعلان/.test(raised ?? ''))

// ── ٢. وبسعرٍ: الطلب مجدولٌ لا نشط ──────────────────────────────────────────
await db.exec(`reset role`)
await db.exec(`update public.app_settings set promo_featured_daily = 2000 where id = 1`)
await asProvider()
const promo = await one(
  `select * from public.api_request_promotion(7, 'jawali', '777123456')`)
await db.exec(`reset role`)

ok('الإعلان مجدولٌ لا نشط', promo.status === 'scheduled')
ok('والمبلغ = سعر اليوم × المدّة', Number(promo.amount) === 14000)

const shown = await rows(`select * from public.api_active_promotions()`)
ok('ولا يظهر في الشريط قبل الدفع', shown.length === 0)

const pay = await one(`select * from public.payments where id = $1`, [promo.payment_id])
ok('وحوالةٌ معلّقة نوعُها «إعلان»',
   pay.status === 'pending' && pay.kind === 'promotion')

// ── ٣. ولا طلبَ ثانٍ فوق معلّق ──────────────────────────────────────────────
await asProvider()
raised = null
try {
  await db.query(`select public.api_request_promotion(3)`)
} catch (e) { raised = e.message }
ok('وطلبٌ ثانٍ فوق معلّقٍ يُردّ', /قيد التأكيد/.test(raised ?? ''))

// ── ٤. والمدّة خارج الحدّ تُردّ ─────────────────────────────────────────────
raised = null
try {
  await db.query(`select public.api_request_promotion(0)`)
} catch (e) { raised = e.message }
ok('ومدّةٌ بصفر يومٍ تُردّ', /من يومٍ إلى تسعين/.test(raised ?? ''))

// ── ٥. تأكيد الحوالة يُظهره ─────────────────────────────────────────────────
await asAdmin()
await db.query(`select public.api_admin_confirm_payment($1, 'REF-PRM')`, [pay.id])
await db.exec(`reset role`)

const live = await one(`select * from public.promotions where id = $1`, [promo.id])
ok('التأكيد يجعله نشطاً', live.status === 'active')
ok('والمدّة تبدأ من لحظة التفعيل',
   new Date(live.ends_at).getTime() > Date.now() + 6 * 24 * 3600 * 1000)

const listed = await rows(`select * from public.api_active_promotions()`)
ok('ويظهر في الشريط بعد الدفع', listed.length === 1)
ok('ومعه اسمُ المزوّد في الصفّ نفسه',
   typeof listed[0].provider_name === 'string' && listed[0].provider_name.length > 0)

// ── ٦. والانتهاء يخرجه ──────────────────────────────────────────────────────
await db.query(
  `update public.promotions
      set starts_at = now() - interval '8 days', ends_at = now() - interval '1 day'
    where id = $1`, [promo.id])
const ended = Number((await one(`select public.expire_promotions() as ع`)).ع)
ok('دورةُ الانتهاء تُنهي المستحقّ', ended === 1)
ok('ويخرج من الشريط',
   (await rows(`select * from public.api_active_promotions()`)).length === 0)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات promotions.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
