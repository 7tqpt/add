/**
 * صورةُ العميل في «آراء العملاء» — من ملفّه الشخصيّ.
 *
 * **وأخطرُ ما يُقاس هنا ليس أنّها تعمل.** `api_provider_reviews` دالّةٌ
 * `security definer` تُمنح لمن لا حسابَ له أيضاً — لأنّ صفحةَ المزوّد تُفتح
 * قبل تسجيل الدخول. فكلُّ ما يحرسها سطران في جسدها:
 *
 *   ــ `r.provider_id = p_provider_id` — فلا تُقرأ آراءُ مزوّدٍ بذكر آخر.
 *   ــ `r.status = 'published'` — **وهو الأخطر**: المخفيُّ والمُبلَّغُ عنه
 *     يراهما صاحبُهما والإدارةُ وحدَهم في السياسة، ودالّةٌ تتجاوز السياسةَ
 *     بتصميمها لا يمنعها من نشرهما للعالم إلّا هذا السطر.
 *
 * ولا تُخرج بريداً ولا جوّالاً ولا حالةَ حساب — وتُعدّ أعمدتُها لذلك.
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
                 'invitations.sql', 'profile.sql']) {
  await db.exec(read(f))
}
const file = read('review_avatars.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const as = async (uid, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid ?? ''])
  return db.query(sql, params)
}
const mkAuth = async (email) => {
  const { rows } = await db.query(
    `insert into auth.users (id, email) values (gen_random_uuid(), $1) returning id`,
    [email])
  return rows[0].id
}

// ── تجهيز ───────────────────────────────────────────────────────────────────
const mkCustomer = async (email, name, avatar) => {
  const auth = await mkAuth(email)
  const { rows } = await db.query(
    `insert into public.app_users (auth_user_id, full_name, email, phone, status,
                                   avatar_path)
     values ($1, $2, $3, '770000000', 'active', $4) returning id`,
    [auth, name, email, avatar])
  return { auth, id: rows[0].id }
}

const withPhoto = await mkCustomer('a@sdd.company', 'أحمد الشرعبي', 'u1/avatar-7.jpg')
const noPhoto = await mkCustomer('b@sdd.company', 'سُمية القدسي', '')
const hider = await mkCustomer('c@sdd.company', 'صاحبُ رأيٍ مخفيّ', 'u3/avatar-1.jpg')
const gone = await mkCustomer('d@sdd.company', 'حسابٌ سيُحذف', 'u4/avatar-2.jpg')

const mkProvider = async (email, name) => {
  const auth = await mkAuth(email)
  const { rows: u } = await db.query(
    `insert into public.app_users (auth_user_id, full_name, email, status)
     values ($1, $2, $3, 'active') returning id`, [auth, name, email])
  const { rows: p } = await db.query(
    `insert into public.service_providers (user_id, full_name, business_name, email,
                                           status, verified_at, governorate_id)
     values ($1, $2, $2, $3, 'verified', now(),
             (select id from public.governorates order by name limit 1))
     returning id`, [u[0].id, name, email])
  return { auth, providerId: p[0].id }
}

const mine = await mkProvider('hall@sdd.company', 'قاعة التاج')
const other = await mkProvider('rival@sdd.company', 'قاعة الضيافة')

const { rows: svc } = await db.query(
  `insert into public.provider_services (provider_id, category_id, title, price)
   values ($1, (select id from public.service_categories order by sort_order limit 1),
           'باقة', 100000)
   returning id`, [mine.providerId])

let ref = 0
const review = async (providerId, user, rating, comment, status = 'published') => {
  ref++
  const { rows: b } = await db.query(
    `insert into public.bookings
       (reference, user_id, user_name, provider_id, provider_name, service_id,
        service_title, event_date, address, guests_count, total_price,
        deposit_amount, paid_amount, status, confirmed_at)
     values ($1, $2, $3, $4, 'قاعة', $5, 'باقة', current_date + 30, 'صنعاء',
             100, 1000000, 100000, 1000000, 'completed', now())
     returning id`,
    [`BK-R-${ref}`, user.id, 'عميل', providerId, svc[0].id])
  const { rows } = await db.query(
    `insert into public.reviews (booking_id, user_id, user_name, provider_id,
                                 rating, comment, status)
     values ($1, $2, $3, $4, $5, $6, $7) returning id`,
    [b[0].id, user.id, comment, providerId, rating, comment, status])
  return rows[0].id
}

await review(mine.providerId, withPhoto, 5, 'قاعة نظيفة والاستقبال ممتاز')
await review(mine.providerId, noPhoto, 4, 'جيّدة والمواقف ضيّقة')
const hidden = await review(mine.providerId, hider, 1, 'رأيٌ أُخفي', 'hidden')
const flagged = await review(mine.providerId, hider, 1, 'رأيٌ مُبلَّغٌ عنه', 'flagged')
await review(other.providerId, withPhoto, 5, 'رأيٌ في قاعةٍ أخرى')
await review(mine.providerId, gone, 3, 'صاحبُه حُذف حسابُه')

// **وحسابٌ يُحذف ورأيُه باقٍ** — `on delete set null` في الجدول. ولو وُصل
// الصفّان وصلاً داخليّاً لَاختفى الرأيُ نفسُه لا صورتُه وحدَها.
await db.query(`delete from public.app_users where id = $1`, [gone.id])

// ── ١. الصورةُ تصل — ولغريبٍ لا لصاحبها ────────────────────────────────────
//
// **وهذا هو الطلبُ كلُّه.** صفحةُ المزوّد يفتحها غيرُ صاحب الرأي أبداً، وهو
// الذي كان يرى حرفاً: سياسةُ `app_users` «لا يرى حسابات غيره إطلاقاً».
const outsiderAuth = await mkAuth('stranger@sdd.company')
await db.query(
  `insert into public.app_users (auth_user_id, full_name, email, status)
   values ($1, 'غريب', 'stranger@sdd.company', 'active')`, [outsiderAuth])

const { rows: seen } = await as(outsiderAuth,
  `select * from public.api_provider_reviews($1)`, [mine.providerId])
const byName = (c) => seen.find((r) => r.comment === c)

ok('غريبٌ يرى آراءَ المزوّد', seen.length === 3, String(seen.length))
ok('**ويرى صورةَ صاحب الرأي**',
   byName('قاعة نظيفة والاستقبال ممتاز')?.avatar_path === 'u1/avatar-7.jpg',
   String(byName('قاعة نظيفة والاستقبال ممتاز')?.avatar_path))

// ── ٢. ومن لا صورةَ له يبقى فارغاً لا معطوباً ──────────────────────────────
ok('ومن لم يرفع صورةً يعود فارغاً',
   byName('جيّدة والمواقف ضيّقة')?.avatar_path === '',
   JSON.stringify(byName('جيّدة والمواقف ضيّقة')?.avatar_path))
ok('ومن حُذف حسابُه يبقى رأيُه', byName('صاحبُه حُذف حسابُه') !== undefined)
ok('وصورتُه فارغةٌ لا `null`',
   byName('صاحبُه حُذف حسابُه')?.avatar_path === '',
   JSON.stringify(byName('صاحبُه حُذف حسابُه')?.avatar_path))

// ── ٣. **والمخفيُّ والمُبلَّغُ عنه لا يخرجان** ─────────────────────────────
//
// **وهذا الحدُّ الأخطر.** الدالّةُ تتجاوز السياسة، فلو سقط الشرطُ لَنُشر
// للعالم ما أخفته الإدارةُ عمداً — ومعه صورةُ صاحبه.
ok('ولا يخرج المخفيّ', !seen.some((r) => r.comment === 'رأيٌ أُخفي'))
ok('ولا المُبلَّغُ عنه', !seen.some((r) => r.comment === 'رأيٌ مُبلَّغٌ عنه'))
ok('ولا يخرجان بمعرّفهما',
   !seen.some((r) => r.id === hidden || r.id === flagged))

// ── ٤. ولا آراءُ مزوّدٍ آخر ─────────────────────────────────────────────────
ok('ولا تخلط مزوّداً بمزوّد',
   !seen.some((r) => r.comment === 'رأيٌ في قاعةٍ أخرى'))
const { rows: otherRows } = await as(outsiderAuth,
  `select * from public.api_provider_reviews($1)`, [other.providerId])
ok('وآراءُ الآخر آراؤه هو', otherRows.length === 1 &&
   otherRows[0].comment === 'رأيٌ في قاعةٍ أخرى', String(otherRows.length))

// ── ٥. **ولا شيءَ غير ذلك** ────────────────────────────────────────────────
const cols = Object.keys(seen[0])
ok('وأعمدتُها ستٌّ لا غير', cols.length === 6, cols.join('، '))
for (const forbidden of ['email', 'phone', 'status', 'auth_user_id', 'user_id',
                         'booking_id', 'hidden_reason']) {
  ok(`ولا ${forbidden} فيها`, !cols.includes(forbidden))
}
const values = seen.map((r) => Object.values(r).map(String).join(' ')).join(' ')
ok('ولا أثرَ لبريدٍ في القيم', !values.includes('@'))
ok('ولا أثرَ لجوّالٍ في القيم', !values.includes('770000000'))

// ── ٦. والأحدثُ أوّلاً ──────────────────────────────────────────────────────
const dates = seen.map((r) => new Date(r.created_at).getTime())
ok('والأحدثُ أوّلاً',
   dates.every((d, i) => i === 0 || dates[i - 1] >= d), dates.join('، '))

// ── ٧. والمنحةُ نفسُها تُقاس ───────────────────────────────────────────────
//
// **وهنا تفترق عن `api_my_conversations`:** تلك لا تُمنح لمن لا حساب له،
// وهذه تُمنح — صفحةُ المزوّد بابُ المنصّة إلى غير المسجَّلين.
const { rows: grant } = await db.query(`
  select p.prosecdef as definer,
         has_function_privilege('anon', p.oid, 'execute')          as anon_may,
         has_function_privilege('authenticated', p.oid, 'execute') as auth_may
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'api_provider_reviews'`)
ok('والدالّةُ `security definer`', grant[0]?.definer === true)
ok('وتُمنح لمن لا حسابَ له — الصفحةُ علنيّة', grant[0]?.anon_may === true)
ok('ولمن سجّل دخولَه', grant[0]?.auth_may === true)

// ── ٨. ومن لا جلسةَ له يراها كما يراها المسجَّل ────────────────────────────
const { rows: anonRows } = await as(null,
  `select * from public.api_provider_reviews($1)`, [mine.providerId])
ok('ومن لا جلسةَ له يرى الآراءَ وصورَها', anonRows.length === 3,
   String(anonRows.length))
ok('ولا يرى المخفيّ', !anonRows.some((r) => r.comment === 'رأيٌ أُخفي'))

await db.close()
console.log(fail === 0 ? '\nكل اختبارات review_avatars.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
