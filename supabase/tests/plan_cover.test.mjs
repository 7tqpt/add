// غلافُ خطّة العرس — صورةُ أوّل خدمةٍ حُجزت فيها.
//
// ── ما يُقاس ───────────────────────────────────────────────────────────────
//
//   ١. **أنّ الصورةَ صورةُ أوّل حجزٍ لا أيِّ حجز** — والأوّلُ بوقت الحجز.
//      وخطّةٌ تُري صورةَ قاعةٍ حُجزت ثانيةً تبدّل رأسَها بلا سببٍ يراه صاحبُها.
//   ٢. **وأنّها ثابتةٌ بين النداءات** — وهذا يُقاس بالنداء عشراً. ودالّةٌ
//      بلا ترتيبٍ تامٍّ تُخرج صفّاً غيرَ معيَّن، فتمرّ مرّةً وتسقط أخرى.
//   ٣. **وأنّ خطّةَ غيرك لا تُقرأ** — والمعرّفُ يُمرَّر من التطبيق، فحرزٌ
//      يثق به حرزٌ لا شيء.
//   ٤. **وأنّ الملغى لا يُورث رأسَ الخطّة** — من ألغى قاعةً لا تبقى صورتُها.
//   ٥. **وأنّ الفارغَ `null` لا عطب** — من لم يحجز، ومن حجز خدمةً بلا صور.
//
// ── وتُشغَّل بـ`npm test` لا بالملفّ وحدَه ──────────────────────────────────
//
// تشغيلةٌ واحدةٌ خضراءُ لا تُثبت شيئاً في تجهيزٍ غيرِ معيَّن — وقد وقع في
// `plan_spend.test.mjs`. فالأمرُ الذي يقيس هو `npm test` في هذا المجلّد.
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
                 'invitations.sql', 'service_media.sql', 'plan_cover.sql']) {
  await db.exec(read(f))
}
// إعادةُ التشغيل لا تكسر شيئاً — شرطُ كلّ ملفٍّ يُلصق في محرّر SQL.
await db.exec(read('plan_cover.sql'))

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

const plan = async (owner, title) => (await one(`
  insert into public.wedding_plans (user_id, title, wedding_date, budget)
  values ($1, $2, current_date + 60, 2000000) returning id`, [owner, title])).id

const myPlan = await plan(myId, 'عرس مريم')
const herPlan = await plan(herId, 'عرس سارة')
const emptyPlan = await plan(myId, 'خطّةٌ بلا حجوزات')

/// **الخدمةُ تُختار بترتيبٍ تامّ** — `limit 1` بلا `order by` تُخرج صفّاً
/// غيرَ معيَّن، فيختلف الاختبارُ من تشغيلةٍ إلى تشغيلة بلا أن يتغيّر حرف.
const serviceAt = async (offset) => (await one(
  `select id, provider_id from public.provider_services order by id offset $1 limit 1`,
  [offset]))

let _day = 0
/// حجزٌ في خطّة. **ويومٌ خاصٌّ لكلّ حجز**: `bookings_confirmed_provider_day_key`
/// يمنع حجزين مؤكَّدين لمزوّدٍ واحدٍ في يوم.
const book = async (planId, userId, svc, when, status = 'confirmed') => {
  const r = await one(`
    insert into public.bookings
      (reference, user_id, plan_id, service_id, provider_id, event_date,
       guests_count, address, status, total_price, deposit_amount, paid_amount,
       created_at, confirmed_at, cancelled_at)
    values ('BK-T-' || substr(md5(random()::text), 1, 6), $1, $2, $3, $4,
            current_date + $5::integer, 300, 'حي السنينة', $6, 500000, 150000, 0,
            $7::timestamptz,
            case when $6 in ('confirmed', 'completed') then now() end,
            case when $6 in ('cancelled', 'rejected', 'expired') then now() end)
    returning id`,
    [userId, planId, svc.id, svc.provider_id, 60 + ++_day, status, when])
  return r.id
}

/// **و`service_media_clip_has_duration` قيدٌ قائمٌ لا يُلتفّ عليه**: مقطعٌ
/// بلا مدّةٍ يُردّ. فتُعطى المقاطعُ مدّتَها والصورُ صفراً.
const media = async (svc, path, sort, kind = 'image') => db.query(`
  insert into public.service_media
    (service_id, provider_id, kind, path, sort_order, duration_seconds)
  values ($1, $2, $5, $3, $4, case when $5 = 'image' then 0 else 12 end)`,
  [svc.id, svc.provider_id, path, sort, kind])

const first = await serviceAt(0)
const second = await serviceAt(1)
const third = await serviceAt(2)

// صورتان للخدمة الأولى — فيُقاس أنّ الغلافَ أوّلُهما بالترتيب.
await media(first, 'svc-1/b-second.jpg', 5)
await media(first, 'svc-1/a-cover.jpg', 1)
await media(second, 'svc-2/cover.jpg', 1)
// **ومقطعٌ يسبقها كلَّها في الترتيب.** و`service_media` تحمل الصورةَ
// والفيديو والصوتَ في جدولٍ واحد، فبلا شرطِ `kind` يصير «الغلافُ» مساراً
// لا صورةَ فيه — ولا يُرى في الشاشة إلّا فراغ.
await media(first, 'svc-1/clip.mp4', 0, 'video')
// والثالثةُ بلا صور.

// **والأقدمُ حجزاً يُدرَج ثانياً عمداً.** لو رُتّبت الدالّةُ بترتيب الإدراج
// — أو بتاريخ العرس، وهو الأبعدُ لهذا الحجز — لَخرجت `svc-2`. والصوابُ
// `svc-1` لأنّ `created_at` أقدم.
await book(myPlan, myId, second, '2026-03-02T10:00:00Z')
await book(myPlan, myId, first, '2026-01-05T10:00:00Z')

const asUser = async (auth) =>
  db.exec(`select set_config('test.uid', '${auth}', false); set role authenticated;`)
const off = () => db.exec('reset role')

const cover = async (planId) =>
  (await one(`select public.api_plan_cover($1) as p`, [planId])).p

// ── ١. صورةُ أوّل حجزٍ بوقته ───────────────────────────────────────────────
console.log('=== غلافُ أوّل حجز ===')
await asUser(mine)
const got = await cover(myPlan)
await off()
ok('الغلافُ من الخدمة الأقدم حجزاً لا الأوّل إدراجاً',
   got === 'svc-1/a-cover.jpg', String(got))

// ── ٢. وثابتٌ بين النداءات ─────────────────────────────────────────────────
//
// **وهذا يُقاس بالتكرار لا بالنظر.** ترتيبٌ ناقصٌ يُخرج صفّاً غيرَ معيَّن،
// فتخضرّ تشغيلةٌ وتحمرّ أخرى — وصورةٌ تتبدّل بلا سببٍ تُقرأ عطباً.
console.log('=== وثابتٌ لا يتبدّل ===')
await asUser(mine)
const ten = []
for (let i = 0; i < 10; i++) ten.push(await cover(myPlan))
await off()
ok('عشرُ نداءاتٍ تُخرج المسارَ نفسَه', new Set(ten).size === 1,
   [...new Set(ten)].join(' · '))

// ── ٣. وأوّلُ صورةٍ بترتيب صاحبها ─────────────────────────────────────────
console.log('=== وترتيبُ الصور داخلَ الخدمة ===')
await db.query(`delete from public.bookings where plan_id = $1`, [myPlan])
_day = 0
await book(myPlan, myId, first, '2026-01-05T10:00:00Z')
await asUser(mine)
const inner = await cover(myPlan)
await off()
ok('الغلافُ أوّلُ صورةٍ بـ`sort_order` لا آخرُ ما أُدرج',
   inner === 'svc-1/a-cover.jpg', String(inner))

// ── ٤. والملغى لا يُورث الرأس ──────────────────────────────────────────────
console.log('=== والملغى خارج الحساب ===')
await db.query(`delete from public.bookings where plan_id = $1`, [myPlan])
_day = 0
await book(myPlan, myId, first, '2026-01-05T10:00:00Z', 'cancelled')
await book(myPlan, myId, second, '2026-03-02T10:00:00Z')
await asUser(mine)
const afterCancel = await cover(myPlan)
await off()
ok('الملغى لا يُعطي غلافاً وإن كان أقدم',
   afterCancel === 'svc-2/cover.jpg', String(afterCancel))

// ── ٥. والفارغُ `null` لا عطب ──────────────────────────────────────────────
console.log('=== ولا صورة ===')
await asUser(mine)
const none = await cover(emptyPlan)
await off()
ok('خطّةٌ بلا حجوزاتٍ تُعيد NULL', none === null, String(none))

_day = 0
await book(emptyPlan, myId, third, '2026-02-01T10:00:00Z')
await asUser(mine)
const noMedia = await cover(emptyPlan)
await off()
ok('وخدمةٌ بلا صورٍ تُعيد NULL', noMedia === null, String(noMedia))

// ── ٦. وخطّةُ غيرك لا تُقرأ ────────────────────────────────────────────────
console.log('=== وخطّةُ غيرك ===')
_day = 0
await book(herPlan, herId, first, '2026-01-01T10:00:00Z')

await asUser(mine)
const stolen = await cover(herPlan)
await off()
ok('مريمُ لا ترى غلافَ خطّة سارة', stolen === null, String(stolen))

await asUser(hers)
const hersOwn = await cover(herPlan)
await off()
ok('وسارةُ ترى غلافَ خطّتها', hersOwn === 'svc-1/a-cover.jpg', String(hersOwn))

// ── ٧. والمجهولُ لا ينادي الدالّةَ أصلاً ───────────────────────────────────
console.log('=== والصلاحيات ===')
await db.exec(`select set_config('test.uid', '', false); set role anon;`)
let denied = false
try {
  await db.query(`select public.api_plan_cover($1)`, [myPlan])
} catch (e) {
  denied = String(e.message).includes('permission denied')
}
await off()
ok('المجهولُ ممنوع', denied)

await db.close()
console.log(fail === 0 ? '\n✅ كلّها' : `\n❌ سقط ${fail}`)
process.exit(fail === 0 ? 0 : 1)
