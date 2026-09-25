// غلافُ الحجز — `v_my_bookings` تضمّ صورةَ الخدمة إلى صفّ الحجز.
//
// ── ما يُقاس ───────────────────────────────────────────────────────────────
//
//   ١. **أنّ الحرزَ حرزُ الجدول نفسِه** — وهذا أخطرُ ما في الطريقة. طريقةٌ
//      تتجاوز سياسةَ `bookings` بابٌ خلفيٌّ يُقرأ منه حجزُ كلّ أحد:
//      اسمُه وعنوانُه وكم دفع.
//   ٢. **وأنّ الأعمدةَ كلَّها موجودةٌ كما في الجدول** — فالتطبيق يقرأ منها
//      ما كان يقرؤه، ونقصُ عمودٍ يُسقط بطاقةً لا يُنقص صورة.
//   ٣. **وأنّ الغلافَ أوّلُ صورةٍ بترتيب صاحبها** — كما في `v_services`
//      حرفاً، فلا تختلف صورةُ الخدمة بين شاشتين.
//   ٤. **وأنّ المقاطعَ ليست أغلفة** — الجدولُ يحمل الثلاثةَ.
//   ٥. **وأنّ خدمةً بلا صورٍ تُعطي NULL** ولا تُسقط شيئاً.
//
// وتُشغَّل بـ`npm test` لا بالملفّ وحدَه.
import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'

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
  create role anon; create role authenticated; create role service_role;`)

for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'invitations.sql', 'service_media.sql', 'booking_cover.sql']) {
  await db.exec(read(f))
}
// إعادةُ التشغيل لا تكسر شيئاً — شرطُ كلّ ملفٍّ يُلصق في محرّر SQL.
await db.exec(read('booking_cover.sql'))

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز ──────────────────────────────────────────────────────────────────
const mine = '11111111-1111-1111-1111-111111111111'
const hers = '22222222-2222-2222-2222-222222222222'

await db.exec(`
  insert into auth.users (id, email) values
    ('${mine}', 'mine@sdd.company'), ('${hers}', 'hers@sdd.company');
  insert into public.app_users (auth_user_id, full_name, email, status) values
    ('${mine}', 'مريم', 'mine@sdd.company', 'active'),
    ('${hers}', 'سارة', 'hers@sdd.company', 'active');`)

const uid = async (auth) =>
  (await one(`select id from public.app_users where auth_user_id = $1`, [auth])).id

const myId = await uid(mine)
const herId = await uid(hers)

/// **بترتيبٍ تامّ**: `limit 1` بلا `order by` تُخرج صفّاً غيرَ معيَّن.
const serviceAt = async (offset) => (await one(
  `select id, provider_id from public.provider_services order by id offset $1 limit 1`,
  [offset]))

const first = await serviceAt(0)
const second = await serviceAt(1)

const media = async (svc, path, sort, kind = 'image') => db.query(`
  insert into public.service_media
    (service_id, provider_id, kind, path, sort_order, duration_seconds)
  values ($1, $2, $5, $3, $4, case when $5 = 'image' then 0 else 12 end)`,
  [svc.id, svc.provider_id, path, sort, kind])

// مقطعٌ يسبق الصور في الترتيب، ثمّ صورتان.
//
// **وترتيبُ الإدراج عكسُ ترتيب `sort_order` عمداً**: لو رُتّب بـ`created_at`
// لَخرجت الثانيةُ. ولولا ذلك لَصحّ الترتيبان ولم يُقَس أيُّهما وقع.
await media(first, 'svc-1/clip.mp4', 0, 'video')
await media(first, 'svc-1/a-cover.jpg', 1)
await media(first, 'svc-1/b-second.jpg', 5)
// والثانيةُ بلا صور.

let _day = 0
const book = async (userId, svc) => (await one(`
  insert into public.bookings
    (reference, user_id, service_id, provider_id, event_date, guests_count,
     address, status, total_price, deposit_amount, paid_amount)
  values ('BK-T-' || substr(md5(random()::text), 1, 6), $1, $2, $3,
          current_date + $4::integer, 300, 'حي السنينة', 'pending_provider',
          500000, 150000, 0)
  returning id, reference`, [userId, svc.id, svc.provider_id, 60 + ++_day])
)

const myWithCover = await book(myId, first)
const myNoCover = await book(myId, second)
const hersOne = await book(herId, first)

const asUser = async (auth) =>
  db.exec(`select set_config('test.uid', '${auth}', false); set role authenticated;`)
const off = () => db.exec('reset role')

// ── ١. الغلافُ أوّلُ صورةٍ بترتيب صاحبها ──────────────────────────────────
console.log('=== الغلاف ===')
await asUser(mine)
const seen = await rows(`select reference, cover_path from public.v_my_bookings
                          order by reference`)
await off()

const byRef = Object.fromEntries(seen.map((r) => [r.reference, r.cover_path]))
ok('الغلافُ أوّلُ صورةٍ بـ`sort_order` لا آخرُ ما أُدرج',
   byRef[myWithCover.reference] === 'svc-1/a-cover.jpg',
   String(byRef[myWithCover.reference]))

// ── ٢. والمقاطعُ ليست أغلفة ────────────────────────────────────────────────
ok('والمقطعُ لا يصير غلافاً وإن سبقها ترتيباً',
   byRef[myWithCover.reference] !== 'svc-1/clip.mp4')

// ── ٣. وخدمةٌ بلا صورٍ تُعطي NULL ──────────────────────────────────────────
ok('وخدمةٌ بلا صورٍ تُعطي NULL', byRef[myNoCover.reference] === null,
   String(byRef[myNoCover.reference]))

// ── ٤. **والحرزُ حرزُ الجدول نفسِه** ───────────────────────────────────────
//
// وهذا أخطرُ ما في الطريقة: من قرأ بها حجزَ غيره قرأ اسمَه وعنوانَه وكم دفع.
console.log('=== والحرز ===')
ok('مريمُ لا ترى حجزَ سارة', !(hersOne.reference in byRef),
   `${seen.length} صفّاً`)

await asUser(hers)
const hersSees = await rows(`select reference from public.v_my_bookings`)
await off()
ok('وسارةُ ترى حجزَها وحدَه',
   hersSees.length === 1 && hersSees[0].reference === hersOne.reference,
   `${hersSees.length} صفّاً`)

// ── ٥. والمجهولُ لا يقرأ شيئاً ─────────────────────────────────────────────
await db.exec(`select set_config('test.uid', '', false); set role anon;`)
let denied = false
try {
  await db.query(`select * from public.v_my_bookings`)
} catch (e) {
  denied = String(e.message).includes('permission denied')
}
await off()
ok('المجهولُ ممنوع', denied)

// ── ٦. والأعمدةُ كلُّها كما في الجدول ──────────────────────────────────────
//
// **ونقصُ عمودٍ يُسقط بطاقةً لا يُنقص صورة**: `Booking.fromMap` تقرأ هذه
// الأسماءَ بأعيانها.
console.log('=== والأعمدة ===')
const cols = async (rel) => (await rows(`
  select column_name from information_schema.columns
   where table_schema = 'public' and table_name = $1
   order by column_name`, [rel])).map((r) => r.column_name)

const table = await cols('bookings')
const view = await cols('v_my_bookings')
const missing = table.filter((c) => !view.includes(c))
ok('لا عمودَ من الجدول ناقصٌ في الطريقة', missing.length === 0, missing.join('، '))
ok('وفيها `cover_path` زائداً', view.includes('cover_path'))

await db.close()
console.log(fail === 0 ? '\n✅ كلّها' : `\n❌ سقط ${fail}`)
process.exit(fail === 0 ? 0 : 1)
