/**
 * ما ينقص «حسابي»: الدور، والعناوين، وطرقُ الدفع، والإعدادات، وحذفُ الحساب.
 *
 * وأهمُّ ما يُثبَت هنا ثلاثة:
 *
 *   ١) **دفترُ عناوين الناس ومحافظُهم لا يقرؤها أحدٌ غيرُهم** — ولا الإدارة.
 *      وهذا هو الفرق بين ميزةٍ وتسريب.
 *   ٢) **افتراضيٌّ واحدٌ لا اثنان** — والفهرسُ الفريد يحرسه لا الشيفرة، لأن
 *      ضغطتين متسارعتين تمرّان من حارس الشيفرة.
 *   ٣) **لا يُحذف حسابٌ عليه حجزٌ قائم** — يترك مقدّمَ الخدمة أمام موعدٍ لا
 *      يعرف صاحبه، والإدارةَ أمام عربونٍ لا تعرف لمن تردّه.
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
                 'invitations.sql', 'profile.sql', 'profile_extras.sql']) {
  await db.exec(read(f))
}

const as = async (uid, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid ?? ''])
  return db.query(sql, params)
}
let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const mustFail = async (label, fn) => {
  try {
    await fn()
    console.log(`❌ ${label} — نجح وكان يجب أن يفشل`)
    fail++
  } catch (e) {
    console.log(`✅ ${label} — مُنع: ${String(e.message).split('\n')[0].slice(0, 48)}`)
  }
}

// ── طرفان ────────────────────────────────────────────────────────────────────
const A = '11111111-1111-1111-1111-111111111111'
const B = '22222222-2222-2222-2222-222222222222'
await db.exec(`
  insert into auth.users (id, email) values
    ('${A}', 'ayman@aras.ye'), ('${B}', 'nabil@aras.ye');
  insert into public.app_users (auth_user_id, full_name, email, phone, status) values
    ('${A}', 'أيمن', 'ayman@aras.ye', '770000000', 'active'),
    ('${B}', 'نبيل', 'nabil@aras.ye', '771111111', 'active');
`)
const gov = (await db.query(`select id, name from public.governorates order by sort_order limit 1`)).rows[0]

console.log('=== الدور: عروسٌ أو عريس ===')
await as(A, `select public.api_set_wedding_role('groom')`)
let role = await as(A, `select wedding_role from public.api_my_profile()`)
ok('يُحفظ الدور فيبقى بعد إغلاق التطبيق', role.rows[0]?.wedding_role === 'groom')
await mustFail('ودورٌ مخترَع يُردّ',
  () => as(A, `select public.api_set_wedding_role('ملك')`))
// والفراغُ حالٌ صحيحة: من جاء ليبيع لا ليعرس.
await as(A, `select public.api_set_wedding_role('')`)
role = await as(A, `select wedding_role from public.api_my_profile()`)
ok('والفراغُ مقبولٌ لمن لا عرسَ له', role.rows[0]?.wedding_role === '')
await as(A, `select public.api_set_wedding_role('groom')`)

console.log('\n=== العناوين ===')
await db.exec(`set role authenticated`)
await as(A, `select public.api_save_address(null, 'بيت العروس', 'حدة، خلف جامع الرحمة', $1, false)`,
  [gov.id])
let mine = await as(A, `select * from public.api_my_addresses()`)
ok('أوّلُ عنوانٍ يُحفظ افتراضيٌّ بلا سؤال', mine.rows[0]?.is_default === true,
   'وإلّا لم يجد نموذجُ الحجز ما يملأ به')
ok('واسمُ المحافظة يُشتقّ من معرّفها', mine.rows[0]?.governorate === gov.name)

await as(A, `select public.api_save_address(null, 'القاعة', 'شارع الستين، قاعة التاج', $1, true)`,
  [gov.id])
mine = await as(A, `select * from public.api_my_addresses()`)
ok('وعنوانان محفوظان', mine.rows.length === 2)
ok('**وافتراضيٌّ واحدٌ لا اثنان**',
   mine.rows.filter(r => r.is_default).length === 1,
   `المحسوب ${mine.rows.filter(r => r.is_default).length}`)
ok('والأخيرُ هو الافتراضيّ', mine.rows.find(r => r.is_default)?.label === 'القاعة')

await mustFail('وعنوانٌ من حرفين يُردّ',
  () => as(A, `select public.api_save_address(null, 'x', 'حدة', null, false)`))

// **الحارس الحقيقي:** دفترُ عناوين غيري.
const theirs = await as(B, `select * from public.api_my_addresses()`)
ok('**ولا يرى نبيلٌ عناوين أيمن**', theirs.rows.length === 0,
   `رأى ${theirs.rows.length}`)
const raw = await as(B, `select count(*)::int n from public.user_addresses`)
ok('ولا من الجدول رأساً', raw.rows[0].n === 0, `رأى ${raw.rows[0].n}`)

// ولا يعدّل ولا يحذف عنوان غيره.
const aId = mine.rows[0].id
await as(B, `select public.api_delete_address($1)`, [aId])
const still = await as(A, `select count(*)::int n from public.api_my_addresses()`)
ok('ولا يحذف عنوان غيره', still.rows[0].n === 2, `بقي ${still.rows[0].n}`)

// وحذفُ الافتراضيّ لا يترك القائمة بلا افتراضيّ.
const defId = mine.rows.find(r => r.is_default).id
await as(A, `select public.api_delete_address($1)`, [defId])
mine = await as(A, `select * from public.api_my_addresses()`)
ok('وحذفُ الافتراضيّ يرفع غيرَه مكانه',
   mine.rows.length === 1 && mine.rows[0].is_default === true)

console.log('\n=== طرقُ الدفع ===')
await as(A, `select public.api_save_payment_method(null, 'jawali', '770000000', 'أيمن محمد', false)`)
let pays = await as(A, `select * from public.api_my_payment_methods()`)
ok('تُحفظ المحفظة فلا يُكتب رقمُها مع كل حوالة', pays.rows.length === 1)
ok('وأوّلُها افتراضيّة', pays.rows[0].is_default === true)
await mustFail('ووسيلةٌ مخترَعة تُردّ',
  () => as(A, `select public.api_save_payment_method(null, 'bitcoin', '770000000', '', false)`))
await mustFail('ورقمٌ من ثلاثة أحرفٍ يُردّ',
  () => as(A, `select public.api_save_payment_method(null, 'jawali', '770', '', false)`))
await mustFail('ولا يُكرَّر الرقمُ نفسه لوسيلةٍ واحدة',
  () => as(A, `select public.api_save_payment_method(null, 'jawali', '770000000', '', false)`))

const notMine = await as(B, `select count(*)::int n from public.user_payment_methods`)
ok('**ولا يرى نبيلٌ محفظة أيمن**', notMine.rows[0].n === 0, `رأى ${notMine.rows[0].n}`)

console.log('\n=== الإعدادات ===')
await as(A, `select public.api_save_settings(false, null)`)
let st = await as(A, `select * from public.api_my_settings()`)
ok('يُطفأ الدفع', st.rows[0]?.push_enabled === false)
ok('**والإعلاناتُ لم تُمسّ**', st.rows[0]?.promos_enabled === true,
   'من أطفأ الدعاية لا يقصد أن يفوته «قُبل حجزك»، والعكس كذلك')
await as(A, `select public.api_save_settings(null, false)`)
st = await as(A, `select * from public.api_my_settings()`)
ok('ثمّ تُطفأ الإعلانات وحدها', st.rows[0]?.push_enabled === false && st.rows[0]?.promos_enabled === false)
const stB = await as(B, `select count(*)::int n from public.user_settings`)
ok('ولا يقرأ إعداداتِ غيره', stB.rows[0].n === 0)

console.log('\n=== حذفُ الحساب — شرطُ Google Play ===')
await db.exec(`reset role`)
// حجزٌ قائمٌ على نبيل.
const prov = (await db.query(`select id from public.service_providers limit 1`)).rows[0]
const bUser = (await db.query(
  `select id from public.app_users where auth_user_id = '${B}'`)).rows[0]
await db.exec(`
  insert into public.bookings
    (reference, user_id, provider_id, event_date, total_price, status, confirmed_at)
  values ('BK-TEST-1', '${bUser.id}', '${prov.id}', current_date + 30, 100000,
          'confirmed', now());`)
await db.exec(`set role authenticated`)
await mustFail('**لا يُحذف حسابٌ عليه حجزٌ قائم**',
  () => as(B, `select public.api_delete_my_account()`))

// وأيمنُ لا حجزَ عليه.
await as(A, `select public.api_delete_my_account()`)
await db.exec(`reset role`)
const gone = await db.query(`select count(*)::int n from auth.users where id = '${A}'`)
ok('ويُحذف من لا شيءَ عليه', gone.rows[0].n === 0)
const cascaded = await db.query(`
  select (select count(*) from public.app_users where auth_user_id = '${A}')::int users,
         (select count(*) from public.user_addresses)::int addrs,
         (select count(*) from public.user_payment_methods)::int pays`)
ok('ويتسلسل الحذفُ إلى ملفّه وعناوينه ومحافظه',
   cascaded.rows[0].users === 0 && cascaded.rows[0].addrs === 0 && cascaded.rows[0].pays === 0,
   JSON.stringify(cascaded.rows[0]))

await db.close()
console.log(fail === 0 ? '\nكل اختبارات profile_extras.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
