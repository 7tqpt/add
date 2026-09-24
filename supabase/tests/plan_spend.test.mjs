// مصروفُ الخطّة حسب القسم — وحرزُه سطرٌ واحد.
//
// ── ما يُقاس ───────────────────────────────────────────────────────────────
//
//   ١. **أنّ الجمعَ صحيحٌ بالقسم** — لا مجموعٌ واحدٌ يُنسب إلى أوّل قسم.
//   ٢. **وأنّ خطّةَ غيرك لا تُقرأ** — والمعرّفُ يُمرَّر من التطبيق، فحرزٌ
//      يثق به حرزٌ لا شيء. وهذا أخطرُ ما في الدالّة: ميزانيّةُ عرسٍ وما
//      دُفع فيه ليست من شأن أحد.
//   ٣. **وأنّ الملغى لا يُعدّ** — كما في `v_plan_summary` حرفاً. وحجزٌ أُلغي
//      لا يُنفق عليه أحد، وعدُّه يُري صاحبَه مصروفاً لم يخرج من جيبه.
//   ٤. **وأنّ «المدفوع» غيرُ «المحجوز»** — ويفترقان ما دام عربونٌ لم
//      يُكمَّل. ودالّةٌ تردّ الرقمَ نفسَه في العمودين تُخفي الالتزامَ القادم.
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
                 'invitations.sql', 'plan_spend.sql']) {
  await db.exec(read(f))
}
// إعادةُ التشغيل لا تكسر شيئاً — شرطُ كلّ ملفٍّ يُلصق في محرّر SQL.
await db.exec(read('plan_spend.sql'))

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: عروسان لكلٍّ خطّتُها ────────────────────────────────────────────
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

/// حجزٌ في خطّةٍ على خدمةٍ من قسمٍ بعينه.
const book = async (planId, userId, categorySlug, total, paid, status = 'confirmed') => {
  const svc = await one(`
    select s.id from public.provider_services s
      join public.service_categories c on c.id = s.category_id
     where c.slug = $1 limit 1`, [categorySlug])
  if (!svc) throw new Error(`لا خدمةَ في قسم ${categorySlug} — البياناتُ التجريبيّة تبدّلت`)
  // **وكلُّ حالةٍ تحمل وقتَها**: `confirmed_needs_timestamp` و`closed_needs_timestamp`
  // قيدان في الجدول، وحجزٌ يُكتب بحالةٍ بلا وقتها يُردّ. وهذا حرزٌ قائمٌ لا
  // يُلتفّ عليه حتى في تجهيزِ اختبار.
  await db.query(`
    insert into public.bookings
      (reference, user_id, plan_id, service_id, provider_id, event_date,
       guests_count, address, status, total_price, deposit_amount, paid_amount,
       confirmed_at, cancelled_at)
    select 'BK-T-' || substr(md5(random()::text), 1, 6), $1, $2, $3, s.provider_id,
           current_date + 60, 300, 'حي السنينة', $4, $5, $5 * 0.3, $6,
           case when $4 in ('confirmed', 'completed') then now() end,
           case when $4 in ('cancelled', 'rejected', 'expired') then now() end
      from public.provider_services s where s.id = $3`,
    [userId, planId, svc.id, status, total, paid])
}

const halls = await one(`select slug from public.service_categories order by sort_order limit 1`)
const second = await one(
  `select slug from public.service_categories order by sort_order offset 1 limit 1`)

await book(myPlan, myId, halls.slug, 850000, 255000)
await book(myPlan, myId, halls.slug, 150000, 150000)   // قسمٌ واحدٌ وحجزان
await book(myPlan, myId, second.slug, 220000, 0)
await book(myPlan, myId, second.slug, 999000, 999000, 'cancelled') // ملغى
await book(herPlan, herId, halls.slug, 700000, 700000)             // خطّةُ غيرها

const asUser = async (auth) =>
  db.exec(`select set_config('test.uid', '${auth}', false); set role authenticated;`)
const off = () => db.exec('reset role')

// ── ١. الجمعُ بالقسم ───────────────────────────────────────────────────────
console.log('=== الجمعُ بالقسم ===')
await asUser(mine)
const got = await rows(`select * from public.api_plan_spend_by_category($1)`, [myPlan])
await off()

ok(`قسمان لا أكثر (${got.length})`, got.length === 2,
   got.map((r) => r.category_name).join(' · '))

const byName = Object.fromEntries(got.map((r) => [r.category_name, r]))
const hallName = (await one(
  `select name from public.service_categories where slug = $1`, [halls.slug])).name
const secondName = (await one(
  `select name from public.service_categories where slug = $1`, [second.slug])).name

ok(`«${hallName}»: المحجوزُ مليونٌ`, Number(byName[hallName]?.booked) === 1000000,
   String(byName[hallName]?.booked))
ok(`و«${hallName}»: المدفوعُ ٤٠٥ آلاف`, Number(byName[hallName]?.spent) === 405000,
   String(byName[hallName]?.spent))
ok(`و«${hallName}»: حجزان`, Number(byName[hallName]?.bookings) === 2)

// **والرقمان يفترقان** — ودالّةٌ تردّ الرقمَ نفسَه في العمودين تُخفي
// الالتزامَ القادم.
ok(`و«${secondName}»: محجوزٌ ٢٢٠ ألفاً ولم يُدفع منه شيء`,
   Number(byName[secondName]?.booked) === 220000 &&
   Number(byName[secondName]?.spent) === 0)

// ── ٢. الملغى لا يُعدّ ─────────────────────────────────────────────────────
console.log('=== والملغى خارج الحساب ===')
const total = got.reduce((a, r) => a + Number(r.booked), 0)
ok(`مجموعُ المحجوز ١٬٢٢٠٬٠٠٠ لا ٢٬٢١٩٬٠٠٠ (${total})`, total === 1220000,
   'عُدَّ الحجزُ الملغى')

// ── ٣. وخطّةُ غيرك لا تُقرأ ────────────────────────────────────────────────
//
// **وهذا أخطرُ ما في الدالّة.** المعرّفُ يُمرَّر من التطبيق، فحرزٌ يثق به
// حرزٌ لا شيء — وميزانيّةُ عرسٍ وما دُفع فيه ليست من شأن أحد.
console.log('=== وخطّةُ غيرك ===')
await asUser(mine)
const stolen = await rows(`select * from public.api_plan_spend_by_category($1)`, [herPlan])
await off()
ok(`مريمُ لا تقرأ خطّةَ سارة (${stolen.length} صفّاً)`, stolen.length === 0)

await asUser(hers)
const hersOwn = await rows(`select * from public.api_plan_spend_by_category($1)`, [herPlan])
await off()
ok(`وسارةُ تقرأ خطّتَها (${hersOwn.length})`, hersOwn.length === 1,
   'الحرزُ أقفل على صاحبته أيضاً')

// ── ٤. والمجهولُ لا ينادي الدالّةَ أصلاً ───────────────────────────────────
console.log('=== والصلاحيات ===')
await db.exec(`select set_config('test.uid', '', false); set role anon;`)
let denied = false
try {
  await db.query(`select * from public.api_plan_spend_by_category($1)`, [myPlan])
} catch (e) {
  denied = String(e.message).includes('permission denied')
}
await off()
ok('المجهولُ ممنوع', denied)

await db.close()
console.log(fail === 0 ? '\n✅ كلّها' : `\n❌ سقط ${fail}`)
process.exit(fail === 0 ? 0 : 1)
