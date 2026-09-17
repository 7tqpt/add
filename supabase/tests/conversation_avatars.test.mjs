/**
 * صورةُ الطرف الآخر في قائمة المحادثات — للطرفين.
 *
 * **وأخطرُ ما يُقاس هنا ليس أنّها تعمل.** `api_my_conversations` دالّةٌ
 * `security definer` — تتجاوز سياسةَ `app_users` بتصميمها. فحدُّها الوحيدُ
 * ما يُكتب في جسدها:
 *
 *   ــ لا تُرجع إلّا محادثاتِ المتصل — ولو سقط ذلك لَقرأ أيُّ مستخدمٍ
 *     محادثاتِ الناس كلِّهم.
 *   ــ ولا تُخرج بريداً ولا جوّالاً ولا حالةَ حساب.
 *   ــ والصورةُ للجانبين: العميلُ يرى شعارَ القاعة، ومقدّمُ الخدمة يرى
 *     صورةَ عميله — وهو ما لم يكن ممكناً في طريقة العرض.
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
                 'invitations.sql', 'profile.sql', 'chat.sql']) {
  await db.exec(read(f))
}
const file = read('conversation_avatars.sql')
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
const custAuth = await mkAuth('cust@sdd.company')
const { rows: cu } = await db.query(
  `insert into public.app_users (auth_user_id, full_name, email, phone, status, avatar_path)
   values ($1, 'أحمد الشرعبي', 'cust@sdd.company', '770000000', 'active',
           'u1/avatar-7.jpg')
   returning id`, [custAuth])
const customerId = cu[0].id

const mkProvider = async (email, name, logo) => {
  const auth = await mkAuth(email)
  const { rows: u } = await db.query(
    `insert into public.app_users (auth_user_id, full_name, email, status)
     values ($1, $2, $3, 'active') returning id`, [auth, name, email])
  const { rows: p } = await db.query(
    `insert into public.service_providers (user_id, full_name, business_name, email,
                                           status, verified_at, logo_path, governorate_id)
     values ($1, $2, $2, $3, 'verified', now(), $4,
             (select id from public.governorates order by name limit 1))
     returning id`, [u[0].id, name, email, logo])
  return { auth, providerId: p[0].id }
}

const mine = await mkProvider('hall@sdd.company', 'قاعة التاج', 'p1/logo-3.jpg')
const other = await mkProvider('rival@sdd.company', 'قاعة الضيافة', 'p2/logo-9.jpg')

const convo = async (providerId, providerName) => {
  const { rows } = await db.query(
    `insert into public.conversations (user_id, user_name, provider_id, provider_name)
     values ($1, 'أحمد الشرعبي', $2, $3) returning id`,
    [customerId, providerId, providerName])
  return rows[0].id
}
const mineConvo = await convo(mine.providerId, 'قاعة التاج')
await convo(other.providerId, 'قاعة الضيافة')

// ── ١. الصورةُ للجانبين ─────────────────────────────────────────────────────
const { rows: asCustomer } = await as(custAuth,
  `select * from public.api_my_conversations()`)
ok('العميلُ يرى محادثتيه', asCustomer.length === 2, String(asCustomer.length))
const withMine = asCustomer.find((r) => r.provider_id === mine.providerId)
ok('ويرى شعارَ القاعة', withMine?.other_avatar === 'p1/logo-3.jpg',
   String(withMine?.other_avatar))
ok('واسمَها', withMine?.other_name === 'قاعة التاج')
ok('وجانبُه «customer»', withMine?.my_side === 'customer')

const { rows: asProvider } = await as(mine.auth,
  `select * from public.api_my_conversations()`)
ok('ومقدّمُ الخدمة يرى محادثتَه هو وحدَها', asProvider.length === 1,
   String(asProvider.length))
// **وهذا ما لم يكن ممكناً في طريقة العرض.**
ok('**ويرى صورةَ عميله**', asProvider[0]?.other_avatar === 'u1/avatar-7.jpg',
   String(asProvider[0]?.other_avatar))
ok('واسمَه', asProvider[0]?.other_name === 'أحمد الشرعبي')
ok('وجانبُه «provider»', asProvider[0]?.my_side === 'provider')

// ── ٢. **ولا شيءَ غير ذلك** ────────────────────────────────────────────────
const cols = Object.keys(asProvider[0])
ok('وأعمدتُها إحدى عشرةَ لا غير', cols.length === 11, cols.join('، '))
for (const forbidden of ['email', 'phone', 'status', 'auth_user_id', 'governorate']) {
  ok(`ولا ${forbidden} فيها`, !cols.includes(forbidden))
}
const values = Object.values(asProvider[0]).map(String).join(' ')
ok('ولا أثرَ لبريدٍ في القيم', !values.includes('@'))
ok('ولا أثرَ لجوّالٍ في القيم', !values.includes('770000000'))

// ── ٣. **ولا تُرجع محادثاتِ غيره** ─────────────────────────────────────────
//
// **وهذا الحدُّ كلُّه.** الدالّةُ تتجاوز السياسة، فلو سقط الشرطُ لَقرأ أيُّ
// مستخدمٍ محادثاتِ الناس كلِّهم.
const outsiderAuth = await mkAuth('stranger@sdd.company')
await db.query(
  `insert into public.app_users (auth_user_id, full_name, email, status)
   values ($1, 'غريب', 'stranger@sdd.company', 'active')`, [outsiderAuth])
const { rows: outsider } = await as(outsiderAuth,
  `select * from public.api_my_conversations()`)
ok('وغريبٌ لا يرى شيئاً', outsider.length === 0, String(outsider.length))

const { rows: outsiderOne } = await as(outsiderAuth,
  `select * from public.api_my_conversations($1)`, [mineConvo])
ok('ولا يرى محادثةً بمعرّفها', outsiderOne.length === 0,
   String(outsiderOne.length))

const { rows: rival } = await as(other.auth,
  `select * from public.api_my_conversations($1)`, [mineConvo])
ok('ومقدّمُ خدمةٍ آخرُ لا يرى محادثةً ليست له', rival.length === 0,
   String(rival.length))

const { rows: none } = await as(null, `select * from public.api_my_conversations()`)
ok('ومن لا جلسةَ له لا يرى شيئاً', none.length === 0, String(none.length))

// ── ٤. وصفٌّ واحدٌ بمعرّفه ──────────────────────────────────────────────────
const { rows: one } = await as(mine.auth,
  `select * from public.api_my_conversations($1)`, [mineConvo])
ok('وصاحبُها يقرأ صفَّها بمعرّفه', one.length === 1 && one[0].id === mineConvo)

// ── ٥. والمنحةُ نفسُها تُقاس ────────────────────────────────────────────────
const { rows: grant } = await db.query(`
  select p.prosecdef as definer,
         has_function_privilege('anon', p.oid, 'execute')          as anon_may,
         has_function_privilege('authenticated', p.oid, 'execute') as auth_may
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'api_my_conversations'`)
ok('والدالّةُ `security definer`', grant[0]?.definer === true)
ok('**ولا تُمنح لمن لا حساب له**', grant[0]?.anon_may === false)
ok('وتُمنح لمن سجّل دخولَه', grant[0]?.auth_may === true)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات conversation_avatars.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
