/**
 * الموقع على الخريطة: نقطةٌ مع العنوان لا بدلاً منه.
 *
 * وأهمُّ ما يُقاس هنا ثلاثةٌ:
 *
 *   ١. **أنّ النقطة لا تُلغي النصّ** — من حفظ نقطةً بلا وصفٍ يُردّ، لأنّ
 *      الإحداثيّات تصلح للملاحة ولا تُقرأ.
 *   ٢. **وأنّ نصفَ موقعٍ يُردّ** — خطُّ عرضٍ بلا طولٍ يُرسم في خليج غينيا.
 *   ٣. **وأنّ ما وُضع خطأً يُمحى** — لا يبقى إلى الأبد لأنّ الشيفرة كتبت
 *      `coalesce`.
 *
 * ويُقاس معها أنّ `coupons.sql` لم ينكسر بإضافة معاملَي الموقع.
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
                 'availability.sql', 'settlements.sql', 'profile.sql',
                 'profile_extras.sql', 'coupons.sql']) {
  await db.exec(read(f))
}
const file = read('location.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]
const raises = async (q, p) => {
  try { await db.query(q, p); return null } catch (e) { return e.message }
}

// ── تجهيز ───────────────────────────────────────────────────────────────────
const uid = 'eeeeeeee-1111-1111-1111-111111111111'
await db.exec(`
  insert into auth.users (id, email) values ('${uid}', 'loc@sdd.company')
    on conflict (id) do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status, governorate)
       values ('${uid}', 'عروس', 'loc@sdd.company', 'active', 'أمانة العاصمة')
  on conflict (email) do update set auth_user_id = '${uid}';`)

const asMe = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${uid}', false)`)
  await db.exec(`set role authenticated`)
}

// إحداثيّاتُ صنعاء تقريباً — رقمان حقيقيّان لا صفران.
const LAT = 15.354722
const LNG = 44.206667

// ── ١. النقطةُ تُحفظ مع العنوان ─────────────────────────────────────────────
await asMe()
const saved = await one(
  `select * from public.api_save_address(
     null, 'بيت العرس', 'حي السنينة — بجانب مسجد النور', null, true, $1, $2)`,
  [LAT, LNG])
ok('العنوانُ يُحفظ ومعه نقطته',
   Number(saved.latitude) === LAT && Number(saved.longitude) === LNG)

// وستُّ خاناتٍ عشرية تكفي بابَ بيت، وما زاد يُقرَّب ولا يُرفض.
const rounded = await one(
  `select * from public.api_save_address(
     null, 'دقّة', 'عنوانٌ ثانٍ للقياس', null, false, $1, $2)`,
  [15.3547219999, 44.2066671111])
ok('وما زاد على ستّ خاناتٍ يُقرَّب',
   Number(rounded.latitude) === 15.354722 && Number(rounded.longitude) === 44.206667)

// ── ٢. **النقطةُ لا تُغني عن النصّ** ────────────────────────────────────────
//
// ولو أُلغي شرطُ الطول لَحُفظ موقعٌ بلا وصفٍ، ولوجد المصوّرُ إحداثيّاتٍ لا
// يعرف أيَّ بيتٍ هي في العمارة.
ok('ونقطةٌ بلا وصفٍ تُردّ',
   /بتفصيلٍ يكفي/.test(
     (await raises(
       `select * from public.api_save_address(null, 'ب', 'قصير', null, false, $1, $2)`,
       [LAT, LNG])) ?? ''))

// ── ٣. **ونصفُ موقعٍ يُردّ** ────────────────────────────────────────────────
ok('وخطُّ عرضٍ بلا طولٍ يُردّ برسالةٍ تُقرأ',
   /خطَّي الطول والعرض معاً/.test(
     (await raises(
       `select * from public.api_save_address(
          null, 'ناقص', 'عنوانٌ فيه تفصيلٌ كافٍ', null, false, $1, null)`,
       [LAT])) ?? ''))

// والقيدُ في القاعدة أيضاً لا في الدالّة وحدها: ثلاثُ شاشاتٍ تكتب العمودين.
await db.exec(`reset role`)
ok('والقاعدةُ نفسها ترفض نصفَ موقع',
   /address_point_sane|violates check/i.test(
     (await raises(
       `update public.user_addresses set latitude = 15.3, longitude = null
         where id = $1`, [saved.id])) ?? ''))

// وخارج المدى يُردّ — خطُّ عرضٍ ٩١ ليس مكاناً على الأرض.
ok('وخطُّ عرضٍ خارج المدى يُردّ',
   /address_point_sane|violates check/i.test(
     (await raises(
       `update public.user_addresses set latitude = 91, longitude = 44
         where id = $1`, [saved.id])) ?? ''))

// ── ٤. **وما وُضع خطأً يُمحى** ──────────────────────────────────────────────
//
// ولو كُتب `coalesce(lat, a.latitude)` لَما استطاع من وضع نقطةً خطأً أن
// يزيلها أبداً — يصحّحها ولا يحذفها، ويبقى المصوّر يُساق إلى بيتٍ ليس بيته.
await asMe()
const cleared = await one(
  `select * from public.api_save_address(
     $1, 'بيت العرس', 'حي السنينة — بجانب مسجد النور', null, true, null, null)`,
  [saved.id])
ok('والنقطةُ الخطأ تُمحى بحفظٍ بلا نقطة',
   cleared.latitude === null && cleared.longitude === null)

// ── ٥. الحجزُ يحمل النقطة إلى مقدّم الخدمة ──────────────────────────────────
const svc = await one(`
  select s.id from public.provider_services s
    join public.service_providers p on p.id = s.provider_id
   where s.is_active and p.status = 'verified' limit 1`)
const day = new Date(Date.now() + 9 * 86400000).toISOString().slice(0, 10)

await asMe()
const booking = await one(
  `select * from public.api_create_booking(
     $1, $2, null, null, 300, 'حي السنينة', '', false, '', $3, $4)`,
  [svc.id, day, LAT, LNG])
ok('الحجزُ يحمل نقطة العرس',
   Number(booking.latitude) === LAT && Number(booking.longitude) === LNG)

// وحجزٌ بلا نقطةٍ يبقى كما كان — والنقطةُ إضافةٌ لا شرط.
const plain = await one(
  `select * from public.api_create_booking(
     $1, $2, null, null, 300, 'حي السنينة', '', false)`,
  [svc.id, new Date(Date.now() + 10 * 86400000).toISOString().slice(0, 10)])
ok('وحجزٌ بلا نقطةٍ يُقبل', plain.latitude === null && plain.id !== null)

ok('ونصفُ نقطةٍ في الحجز يُردّ',
   /خطَّي الطول والعرض معاً/.test(
     (await raises(
       `select * from public.api_create_booking(
          $1, $2, null, null, 300, 'حي', '', false, '', $3, null)`,
       [svc.id, day, LAT])) ?? ''))
await db.exec(`reset role`)

// ── ٦. والكوبونُ لم ينكسر بإضافة المعاملين ──────────────────────────────────
//
// **وهذا ما يُنسى:** `location.sql` يُعيد كتابة `api_create_booking` كاملةً،
// فأيُّ سطرٍ يسقط منها يسقط صامتاً — الحجزُ ينجح والخصمُ لا يقع.
await db.exec(`
  insert into public.coupons (code, description, kind, value)
       values ('LOC10', 'قياس', 'percent', 10)`)
await asMe()
const withCoupon = await one(
  `select * from public.api_create_booking(
     $1, $2, null, null, 300, 'حي', '', true, 'LOC10', $3, $4)`,
  [svc.id, new Date(Date.now() + 11 * 86400000).toISOString().slice(0, 10), LAT, LNG])
await db.exec(`reset role`)
ok('والكوبونُ ما زال يعمل بعد إضافة الموقع',
   withCoupon.coupon_code === 'LOC10' && Number(withCoupon.discount_amount) > 0)
ok('ويحمل النقطةَ والكودَ معاً',
   Number(withCoupon.latitude) === LAT)

// ولا توقيعان للدالّة بعد الاستبدال الثاني.
const sigs = await one(`
  select count(*)::int as ع from pg_proc
   where proname = 'api_create_booking' and pronamespace = 'public'::regnamespace`)
ok('ولا يبقى توقيعان لدالّة الحجز', sigs.ع === 1)

const addrSigs = await one(`
  select count(*)::int as ع from pg_proc
   where proname = 'api_save_address' and pronamespace = 'public'::regnamespace`)
ok('ولا توقيعان لدالّة العنوان', addrSigs.ع === 1)

// ── ٧. وفحصُ الكوبونات لا يُكذّب قاعدةً سليمة ───────────────────────────────
//
// **وهذا هو الضابط:** بندُه السادس كان يعدّ معاملات الدالّة — «تسعة» — فكسره
// هذا الملفُّ حين صارت إحدى عشرة. فصار يسأل عن اسم المعامل، ويُقاس هنا على
// قاعدةٍ شُغِّل عليها الملفّان معاً.
const [verdicts] = read('verify_coupons.sql').split('-- ملحق: أكوادُك وحصادُها')
const verdictRows = await rows(verdicts)
const bad = verdictRows.filter((r) => r.الحكم !== '✅')
ok('وفحصُ الكوبونات يبقى كلُّه ✅ بعد location.sql',
   bad.length === 0)
if (bad.length) console.log('   ', bad.map((r) => r.البند).join('، '))

await db.close()
console.log(fail === 0 ? '\nكل اختبارات location.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
