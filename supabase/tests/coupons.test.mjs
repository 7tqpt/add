/**
 * الكوبونات: من يخصم، وممّن يُخصم، ومن يستطيع أن يقرأ الأكواد.
 *
 * وأهمّ ما يُثبَت هنا ثلاثةٌ، وكلُّها مالٌ لا شاشات:
 *
 *   ١. **أنّ الخصم من جيب المنصّة لا من جيب مقدّم الخدمة** — يُحسب نصيبُه
 *      بالكوبون وبدونه ويُقارَن الرقمان. ولو خُصم منه لخرج من المنصّة.
 *   ٢. **وأنّ الكود لا يُصرف مرّتين** — لا لمستخدمٍ تجاوز حدَّه، ولا فوق
 *      عدد الاستعمالات، ولا في حجزٍ واحدٍ مرّتين.
 *   ٣. **وأنّ أحداً لا يستطيع قراءة جدول الأكواد** — ولا العميل. فلو قُرئ
 *      لَجمع أوّلُ فضوليٍّ كلَّ كودٍ في المنصّة.
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
                 'availability.sql', 'settlements.sql']) {
  await db.exec(read(f))
}
const file = read('coupons.sql')
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
const cuid = 'dddddddd-1111-1111-1111-111111111111'
const auid = 'dddddddd-2222-2222-2222-222222222222'

const svc = await one(`
  select s.id, s.price, s.deposit_percent, s.category_id, s.provider_id,
         coalesce(p.commission_percent, (select commission_percent from public.app_settings where id = 1))
           as commission
    from public.provider_services s
    join public.service_providers p on p.id = s.provider_id
   where s.is_active and p.status = 'verified'
   order by s.price desc limit 1`)

await db.exec(`
  insert into auth.users (id, email) values ('${cuid}', 'c9@sdd.company')
    on conflict (id) do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status, governorate)
       values ('${cuid}', 'عميلة', 'c9@sdd.company', 'active', 'أمانة العاصمة')
  on conflict (email) do update set auth_user_id = '${cuid}';

  insert into auth.users (id, email) values ('${auid}', 'a9@sdd.company')
    on conflict (id) do nothing;
  insert into public.admins (user_id, email, role)
       values ('${auid}', 'a9@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';
`)
const customer = await one(
  `select id from public.app_users where auth_user_id = '${cuid}'`)

const asCustomer = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${cuid}', false)`)
  await db.exec(`set role authenticated`)
}
const asAdmin = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${auid}', false)`)
  await db.exec(`set role authenticated`)
}
const asNobody = async () => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '', false)`)
  await db.exec(`set role anon`)
}

const price = Number(svc.price)
const commissionBase = Math.round(price * Number(svc.commission)) / 100
const day = (n) => {
  const d = new Date(Date.now() + n * 86400000)
  return d.toISOString().slice(0, 10)
}
let dayOffset = 3
const nextDay = () => day(dayOffset++)

const makeCoupon = async (code) => {
  await db.exec(`reset role`)
  await db.exec(`
    delete from public.coupons where code = '${code}';
    insert into public.coupons (code, description, kind, value)
         values ('${code}', 'حملة', 'percent', 10);`)
  return one(`select * from public.coupons where code = '${code}'`)
}

// ── ١. لا أحد يقرأ الأكواد إلّا الإدارة ─────────────────────────────────────
//
// **وهذا أوّلُ ما يُقاس، قبل أي حساب.** جدولٌ مقروءٌ يعني أنّ كلَّ حملةٍ
// تُسرَّب يومَ إطلاقها، وأنّ خصم «كبار العملاء» يصير خصمَ الجميع.
await makeCoupon('EID25')
await asCustomer()
ok('العميل لا يرى أي كود',
   (await rows(`select * from public.coupons`)).length === 0)
await asNobody()
ok('وغيرُ المسجَّل كذلك',
   (await rows(`select * from public.coupons`)).length === 0)
await asAdmin()
ok('والإدارةُ تراها', (await rows(`select * from public.coupons`)).length >= 1)

// ولا يكتب العميلُ كوداً لنفسه.
await asCustomer()
ok('ولا يُنشئ العميل كوداً لنفسه',
   /policy|violates/i.test(
     (await raises(
       `insert into public.coupons (code, kind, value) values ('MINE', 'percent', 90)`)) ?? ''))

// ── ٢. الاستشارة قبل الحجز تُرجع المبلغ الحقيقي ─────────────────────────────
await db.exec(`reset role`)
await db.exec(`update public.coupons set value = 10, kind = 'percent' where code = 'EID25'`)
await asCustomer()
const checked = await one(
  `select * from public.api_check_coupon('EID25', $1)`, [svc.id])
const tenPercent = Math.round(price * 10) / 100
ok('الاستشارة تُرجع الخصم بالريال',
   Number(checked.discount) === Math.min(tenPercent, commissionBase))

// والحروفُ الصغيرة تُقبل: من يكتب `eid25` يقصد `EID25`.
const lower = await one(
  `select * from public.api_check_coupon('  eid25 ', $1)`, [svc.id])
ok('وحروفٌ صغيرةٌ ومسافاتٌ تُقبل', Number(lower.discount) === Number(checked.discount))

ok('وكودٌ لا وجود له يُردّ برسالة',
   /غير صحيح/.test(
     (await raises(`select * from public.api_check_coupon('NOPE', $1)`, [svc.id])) ?? ''))

// **ولا صفَّ من NULLات:** الدالّة `returns table` لا نوعاً مركَّباً، فالخطأ
// يُرفع ولا يعود صفٌّ فارغٌ يُقرأ في التطبيق فيسقط بـ Null is not a String.
ok('ولا يعود صفٌّ فارغٌ بدل الخطأ',
   (await raises(`select * from public.api_check_coupon('NOPE', $1)`, [svc.id])) !== null)

// ── ٣. **الخصمُ من جيب المنصّة لا من جيب مقدّم الخدمة** ─────────────────────
//
// يُحجز حجزان متطابقان — أحدهما بكوبونٍ والآخر بدونه — ويُقارَن ما يستحقّه
// المزوّدُ في الاثنين. وهو الرقم الذي يخرج به من المنصّة إن نقص.
await asCustomer()
const plain = await one(
  `select * from public.api_create_booking($1, $2, null, null, 0, '', '', true)`,
  [svc.id, nextDay()])
const withCoupon = await one(
  `select * from public.api_create_booking($1, $2, null, null, 0, '', '', true, 'EID25')`,
  [svc.id, nextDay()])
await db.exec(`reset role`)

const discount = Number(withCoupon.discount_amount)
ok('الحجزُ يحمل كودَه ومبلغَه',
   withCoupon.coupon_code === 'EID25' && discount > 0)
ok('والسعرُ الأصليّ لم يُمسّ',
   Number(withCoupon.total_price) === Number(plain.total_price))

const payOf = async (b) =>
  one(`select * from public.payments where booking_id = $1`, [b.id])
const p1 = await payOf(plain)
const p2 = await payOf(withCoupon)

ok('والعميلُ يدفع أقلَّ بمقدار الخصم',
   Number(p1.amount) - Number(p2.amount) === discount)
ok('**ونصيبُ المزوّد لم ينقص ريالاً**',
   Number(p2.net_amount) === Number(p1.net_amount))
ok('والفرقُ كلُّه من نصيب المنصّة',
   Number(p1.platform_share) - Number(p2.platform_share) === discount)

// **والتسويةُ هي الحَكَم لا صفُّ الدفعة.**
//
// `settlements.sql` لا يقرأ `payments` أصلاً — بل `bookings.paid_amount` ناقص
// `bookings.commission_amount`. وهنا وقع الخطأ فعلاً: كان صفُّ الدفعة صحيحاً
// بينما `api_respond_to_booking` تكتب العمولةَ كاملةً من `total_price` وحده،
// فيخرج الفرقُ من جيب المزوّد يومَ التسوية بعد أسابيع.
//
// فيُقبل الحجزان بالدالّة نفسها التي يستعملها المزوّد — لا بـ `update` بيدي،
// فالحارسُ الذي يلتفّ على مسار الشيفرة لا يحرس شيئاً.
await db.query(
  `update public.service_providers set user_id = $1 where id = $2`,
  [customer.id, svc.provider_id])
await asCustomer()
for (const b of [plain, withCoupon]) {
  await db.query(`select * from public.api_respond_to_booking($1, true)`, [b.id])
}
await db.exec(`reset role`)
await db.query(
  `update public.bookings set paid_amount = total_price - discount_amount
    where id in ($1, $2)`, [plain.id, withCoupon.id])

const settleOf = async (b) => one(
  `select b.paid_amount - b.refunded_amount
          - least(b.commission_amount, b.paid_amount - b.refunded_amount) as due
     from public.bookings b where b.id = $1`, [b.id])
ok('**ومستحقُّه في التسوية سواءٌ في الحجزين**',
   Number((await settleOf(plain)).due) === Number((await settleOf(withCoupon)).due))

// والفاتورةُ تقول للعميل ما جرى: إجماليٌّ، وخصمٌ، ومطلوب.
const inv = await one(
  `select * from public.invoices where booking_id = $1`, [withCoupon.id])
ok('والفاتورةُ تحمل الخصم وتنقصه من المطلوب',
   Number(inv.discount) === discount &&
   Number(inv.total) === Number(inv.subtotal) - discount)

// ── ٤. الكودُ لا يُصرف مرّتين ───────────────────────────────────────────────
await asCustomer()
ok('ولا يُستعمل الكودُ مرّتين لنفس المستخدم',
   /من قبل/.test(
     (await raises(
       `select * from public.api_create_booking($1, $2, null, null, 0, '', '', true, 'EID25')`,
       [svc.id, nextDay()])) ?? ''))
await db.exec(`reset role`)

const counted = await one(`select used_count from public.coupons where code = 'EID25'`)
ok('والعدّادُ يزيد مرّةً واحدة', counted.used_count === 1)

// وحدُّ العدد الكلّي يُقفل الباب ولو كان المستخدمُ جديداً.
await db.exec(`
  update public.coupons set max_uses = 1, max_uses_per_user = 99 where code = 'EID25'`)
await asCustomer()
ok('وعددٌ كلّيٌّ منتهٍ يُقفل الكود',
   /انتهى عدد/.test(
     (await raises(
       `select * from public.api_create_booking($1, $2, null, null, 0, '', '', true, 'EID25')`,
       [svc.id, nextDay()])) ?? ''))
await db.exec(`reset role`)

// ── ٥. والحجزُ الذي لم يقع يردّ الكود ───────────────────────────────────────
//
// يحجز العميل بكوده فيعتذر المزوّد — فلو بقي الكودُ محترقاً لَصارت كلُّ حملةٍ
// تذاكرَ دعم.
await db.query(
  `update public.bookings set status = 'pending_provider', confirmed_at = null
    where id = $1`, [withCoupon.id])
await asCustomer()
await db.query(
  `select * from public.api_respond_to_booking($1, false, 'اعتذار')`, [withCoupon.id])
await db.exec(`reset role`)
const afterReject = await one(`select used_count from public.coupons where code = 'EID25'`)
ok('اعتذارُ المزوّد يردّ الاستعمال', afterReject.used_count === 0)
ok('ويُمحى صفُّ الاستعمال',
   (await rows(`select 1 from public.coupon_redemptions where booking_id = $1`,
               [withCoupon.id])).length === 0)

// ── ٦. القواعد: النافذة والقسم والحدّ الأدنى ────────────────────────────────
await db.exec(`
  update public.coupons set max_uses = 0, max_uses_per_user = 9,
         starts_at = now() - interval '10 days', ends_at = now() - interval '1 day'
   where code = 'EID25'`)
await asCustomer()
ok('وكودٌ منتهي المدّة يُردّ',
   /انتهت صلاحية/.test(
     (await raises(`select * from public.api_check_coupon('EID25', $1)`, [svc.id])) ?? ''))
await db.exec(`reset role`)

await db.exec(`
  update public.coupons set starts_at = now() + interval '2 days', ends_at = null
   where code = 'EID25'`)
await asCustomer()
ok('وكودٌ لم يبدأ بعدُ يُردّ',
   /لم تبدأ/.test(
     (await raises(`select * from public.api_check_coupon('EID25', $1)`, [svc.id])) ?? ''))
await db.exec(`reset role`)

await db.exec(`
  update public.coupons set starts_at = now() - interval '1 day', is_active = false
   where code = 'EID25'`)
await asCustomer()
ok('وكودٌ موقوفٌ يُردّ',
   /موقوف/.test(
     (await raises(`select * from public.api_check_coupon('EID25', $1)`, [svc.id])) ?? ''))
await db.exec(`reset role`)

const otherCat = await one(
  `select id from public.service_categories where id <> $1 limit 1`, [svc.category_id])
await db.query(
  `update public.coupons set is_active = true, category_id = $1 where code = 'EID25'`,
  [otherCat.id])
await asCustomer()
ok('وكودُ قسمٍ آخر لا ينطبق',
   /لا ينطبق على هذا القسم/.test(
     (await raises(`select * from public.api_check_coupon('EID25', $1)`, [svc.id])) ?? ''))
await db.exec(`reset role`)

await db.query(
  `update public.coupons set category_id = null, min_total = $1 where code = 'EID25'`,
  [price + 1])
await asCustomer()
ok('وحدٌّ أدنى فوق السعر يُردّ',
   /فأكثر/.test(
     (await raises(`select * from public.api_check_coupon('EID25', $1)`, [svc.id])) ?? ''))
await db.exec(`reset role`)

// ── ٧. الحساب: السقف، والقصُّ عند العمولة ───────────────────────────────────
await db.exec(`
  update public.coupons
     set min_total = 0, kind = 'percent', value = 50, max_discount = 100
   where code = 'EID25'`)
await asCustomer()
const capped = await one(
  `select * from public.api_check_coupon('EID25', $1)`, [svc.id])
ok('سقفُ النسبة يُطبَّق', Number(capped.discount) === 100)
await db.exec(`reset role`)

// **والقصُّ عند العمولة** — نسبةُ خصمٍ أكبرُ من عمولة المنصّة لا تُعطى من
// مال المزوّد. وهذه قاعدةٌ تُقاس لأنّها القرارُ الثاني في رأس الملفّ.
await db.exec(`
  update public.coupons set value = 100, max_discount = 0 where code = 'EID25'`)
await asCustomer()
const clipped = await one(
  `select * from public.api_check_coupon('EID25', $1)`, [svc.id])
ok('وخصمٌ يتجاوز العمولة يُقصّ عندها',
   Number(clipped.discount) === commissionBase && commissionBase < price)
await db.exec(`reset role`)

// ومبلغٌ ثابت.
await db.exec(`
  update public.coupons set kind = 'fixed', value = 500, max_discount = 0
   where code = 'EID25'`)
await asCustomer()
const fixed = await one(
  `select * from public.api_check_coupon('EID25', $1)`, [svc.id])
ok('ومبلغٌ ثابتٌ يُخصم كما هو',
   Number(fixed.discount) === Math.min(500, commissionBase))
await db.exec(`reset role`)

// ── ٨. حجزٌ بلا كوبونٍ يبقى كما كان ─────────────────────────────────────────
//
// **الدالّةُ أُعيدت كتابتها كاملةً بمعاملٍ زائد** — فيُقاس أنّ من لا يمرّر
// كوداً لم يتغيّر عليه شيء، لا الحسابُ ولا صفُّ الدفعة.
await asCustomer()
const untouched = await one(
  `select * from public.api_create_booking($1, $2, null, null, 0, '', '', false)`,
  [svc.id, nextDay()])
await db.exec(`reset role`)
const up = await payOf(untouched)
ok('حجزٌ بلا كوبونٍ: لا خصمَ ولا كود',
   Number(untouched.discount_amount) === 0 && untouched.coupon_code === '')
ok('وعربونُه بنسبته من السعر',
   Number(up.amount) === Math.round(price * Number(svc.deposit_percent)) / 100)

// **قفلُ صفّ الكوبون — وحارسٌ أضعفُ ممّا أريد، فيُقال ما هو.**
//
// عميلان يحجزان في اللحظة نفسها بآخر استعمالٍ في الكود: بلا `for update`
// يقرآن `used_count` نفسه فيمرّان معاً ويُصرف الكودُ مرّتين وحدُّه واحد.
//
// و PGlite وصلةٌ واحدةٌ لا تُدار فيها معاملتان معاً، فلا سبيل إلى تنظيم
// السباق هنا. فهذا يسأل عن **وجود السطر في نصّ الدالّة** لا عن سلوكها —
// يمنع حذفَه سهواً ولا يُثبت سلامةَ التزاحم. ومن أراد اليقين فليختبره على
// Postgres حقيقيّ بوصلتين.
const src = (await one(
  `select pg_get_functiondef(p.oid) as def from pg_proc p
    where p.proname = 'api_create_booking' and p.pronamespace = 'public'::regnamespace`)).def
ok('وسطرُ القفل باقٍ في دالّة الحجز (فحصُ نصٍّ لا سلوك)',
   /for update/i.test(src))

// ولا توقيعان للدالّة بعد الاستبدال — وإلّا صار النداءُ من التطبيق ملتبساً.
const sigs = await one(`
  select count(*)::int as ع from pg_proc
   where proname = 'api_create_booking'
     and pronamespace = 'public'::regnamespace`)
ok('ولا يبقى توقيعان لدالّة الحجز', sigs.ع === 1)

// ── ٩. كوبونٌ واحدٌ للحجز الواحد — قيدٌ في القاعدة ──────────────────────────
const live = await one(`select id from public.coupons where code = 'EID25'`)
ok('ولا يُلصق كوبونان بحجزٍ واحد',
   /unique|duplicate/i.test(
     (await raises(`
       insert into public.coupon_redemptions (coupon_id, user_id, booking_id, code, amount)
            values ($1, $2, $3, 'X', 1), ($1, $2, $3, 'Y', 1)`,
       [live.id, customer.id, untouched.id])) ?? ''))

// ── ١٠. وطريقةُ العرض تقول «سارٍ» مرّةً واحدةً للجميع ───────────────────────
await db.exec(`
  update public.coupons set is_active = true, starts_at = now() - interval '1 day',
         ends_at = now() + interval '30 days', max_uses = 0 where code = 'EID25'`)
await asAdmin()
const view = await one(`select * from public.v_coupons where code = 'EID25'`)
ok('وطريقةُ العرض تحسب «سارٍ»', view.is_live === true)
await db.exec(`reset role`)
await db.exec(`update public.coupons set is_active = false where code = 'EID25'`)
await asAdmin()
ok('والموقوفُ ليس سارياً',
   (await one(`select is_live from public.v_coupons where code = 'EID25'`)).is_live === false)
await db.exec(`reset role`)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات coupons.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
