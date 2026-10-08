// **مقدّمُ الخدمة مقيَّدٌ بأقسامه — `provider_category_lock.sql`.**
//
// «كيف اقيد المقدم الخدمة ب القسام الذي اختارة»، واختار صاحبُ المنصّة (أ ب):
// الإدارةُ تضبط أقسامَه، وخدماتُه خارجها تُخفى عن العملاء حتى تُراجَع. ويُقاس
// بأدوار القاعدة الحقيقيّة: ما يضيفه المزوّد، وما يراه الزائر، وما يُحجز.
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8').replace(/\r\n/g, '\n')

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

const SUPABASE = `
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create role anon; create role authenticated; create role service_role;
  grant usage on schema auth to anon, authenticated;
  grant execute on all functions in schema auth to anon, authenticated;
  create schema if not exists storage;
  create table storage.buckets (id text primary key, name text not null, public boolean not null default false,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects (id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id), name text not null, owner uuid);
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;`

const ORDER = `install seed apply storage support roles invitations profile service_media chat
  notifications push_hook provider_logo payments_app availability subscriptions settlements
  promotions broadcast plan_tasks income chat_media profile_extras coupons location nearby
  category_images app_download share_link service_delete completion_review review_avatars
  phone_verify provider_columns profile_cover plan_cover plan_spend booking_cover booking_delete
  conversation_avatars customer_card phone_verify_attempts presence security_notification_rpcs
  audit_security security_hardening security_fixes wallet banners promotions_clear provider_category_lock`.split(/\s+/)

const db = new PGlite()
await db.exec(SUPABASE)
for (const f of ORDER) await db.exec(read(`${f}.sql`))
await db.exec(read('provider_category_lock.sql')) // إعادةُ اللصق آمنة

const q = async (sql, params = []) => (await db.query(sql, params)).rows
const one = async (sql, params = []) => (await q(sql, params))[0]
const as = async (auth, sql, params = []) => {
  await db.exec('begin')
  try {
    await db.exec(`set local role ${auth ? 'authenticated' : 'anon'}`)
    await db.query(`select set_config('request.jwt.claim.sub', $1, true)`, [auth ?? ''])
    const rows = (await db.query(sql, params)).rows
    await db.exec('commit')
    return rows
  } catch (e) {
    await db.exec('rollback')
    return { error: e.message }
  }
}
const refused = (r) => !Array.isArray(r)

const PUID = '55555555-5555-4555-8555-555555555555'
const CUID = '66666666-6666-4666-8666-666666666666'
const OWNER = '33333333-3333-4333-8333-333333333333'

// مزوّدٌ موثَّقٌ بقسمٍ واحد (A)، ولخدمةٍ له قسمٌ آخر (B) من قبل القيد.
const [A, B] = (await q(`select id from public.service_categories order by sort_order limit 2`)).map((r) => r.id)
const provider = await one(`select id from public.service_providers where status = 'verified' order by id limit 1`)
await db.exec(`insert into auth.users (id, email) values ('${PUID}', 'p@x.com'), ('${CUID}', 'c@x.com'), ('${OWNER}', 'o@x.com');
  insert into public.admins (user_id, email, role) values ('${OWNER}', 'o@x.com', 'owner');`)
await as(PUID, `select public.api_register_profile('صاحب قاعة', '+967773333333', 'صنعاء', 'android')`)
await as(CUID, `select public.api_register_profile('عميلة', '+967774444444', 'صنعاء', 'android')`)
await db.query(`update public.service_providers set user_id = (select id from public.app_users where auth_user_id = $1) where id = $2`, [PUID, provider.id])
await db.query(`delete from public.provider_categories where provider_id = $1`, [provider.id])
await db.query(`insert into public.provider_categories (provider_id, category_id) values ($1, $2)`, [provider.id, A])
const legacy = (await one(`insert into public.provider_services (provider_id, category_id, title, price, is_active)
  values ($1, $2, 'خدمةٌ في قسمٍ آخر', 1000, true) returning id`, [provider.id, B])).id
const mine = (await one(`insert into public.provider_services (provider_id, category_id, title, price, is_active)
  values ($1, $2, 'خدمةٌ في قسمه', 1000, true) returning id`, [provider.id, A])).id

const seen = async (who, id) => {
  const r = await as(who, `select id from public.v_services where id = $1`, [id])
  return Array.isArray(r) && r.length === 1
}

// ── المزوّدُ يضيف في قسمه وحده ──────────────────────────────────────────────
const addA = await as(PUID, `insert into public.provider_services (provider_id, category_id, title, price, is_active)
  values ($1, $2, 'باقةٌ جديدة', 2000, true) returning id`, [provider.id, A])
ok('المزوّدُ يضيف خدمةً في قسمه', Array.isArray(addA), JSON.stringify(addA))
const addB = await as(PUID, `insert into public.provider_services (provider_id, category_id, title, price, is_active)
  values ($1, $2, 'تصوير', 2000, true) returning id`, [provider.id, B])
ok('**ولا يضيف في قسمٍ غير قسمه** — والرسالةُ تقول لماذا',
   refused(addB) && /إلّا في قسمك المسجَّل/.test(addB.error), addB.error)

// ── ولا يكتب أقسامَه ──────────────────────────────────────────────────────────
const selfAdd = await as(PUID, `insert into public.provider_categories (provider_id, category_id) values ($1, $2)`, [provider.id, B])
ok('**ولا يضيف لنفسه قسماً**', refused(selfAdd), JSON.stringify(selfAdd))
await as(PUID, `delete from public.provider_categories where provider_id = $1`, [provider.id])
ok('ولا يحذف قسمَه', (await q(`select 1 from public.provider_categories where provider_id = $1`, [provider.id])).length === 1)

// ── والعميلُ لا يرى ما خارج أقسامه، وصاحبُها يراها ──────────────────────────
ok('**الخدمةُ خارج قسمه مخفيّةٌ عن الزائر**', !(await seen(null, legacy)))
ok('وعن العميل المسجَّل', !(await seen(CUID, legacy)))
const near = await as(null, `select id from public.api_services_nearby(15.35, 44.2, null, '', 200)`)
ok('ولا تأتي في «الأقرب إليّ»', Array.isArray(near) && !near.some((r) => r.id === legacy) && near.some((r) => r.id === mine))
ok('وخدمتُه في قسمه ظاهرة', await seen(null, mine))
const own = await as(PUID, `select id from public.provider_services where id = $1`, [legacy])
ok('**وصاحبُها يراها** — ليصلحها', Array.isArray(own) && own.length === 1)

// ── ولا تُحجز ─────────────────────────────────────────────────────────────────
const day = new Date(Date.now() + 40 * 864e5).toISOString().slice(0, 10)
const booked = await as(CUID, `select id from public.api_create_booking($1, $2::date)`, [legacy, day])
ok('**ولا تُحجز برابطٍ قديم**', refused(booked) && /غير متاحة للحجز/.test(booked.error), booked.error ?? JSON.stringify(booked))

// ── وتعديلُها بلا نقلٍ مسموحٌ وتبقى مخفيّة؛ ونقلُها إلى قسمه يُظهرها ─────────
const price = await as(PUID, `update public.provider_services set price = 1500 where id = $1 returning id`, [legacy])
ok('ويعدّل سعرَها وهي مخفيّة', Array.isArray(price) && price.length === 1, JSON.stringify(price))
ok('وتبقى مخفيّة', !(await seen(null, legacy)))
const move = await as(PUID, `update public.provider_services set category_id = $2 where id = $1 returning id`, [legacy, A])
ok('**ونقلُها إلى قسمه يُظهرها**', Array.isArray(move) && (await seen(null, legacy)), JSON.stringify(move))
await db.query(`update public.provider_services set category_id = $2 where id = $1`, [legacy, B]) // تعود كما كانت

// ── والإدارةُ تضبط أقسامَه ───────────────────────────────────────────────────
const byProvider = await as(PUID, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, [A, B]])
ok('**المزوّدُ لا يضبط أقسامَه بالدالّة**', refused(byProvider))
const none = await as(OWNER, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, []])
ok('ولا يُترك بلا قسم', refused(none) && /قسماً واحداً على الأقلّ/.test(none.error), none.error)
const both = await as(OWNER, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, [A, B]])
// والمخفيُّ يُعدّ بما في القاعدة: للمزوّد خدماتٌ من البذور في أقسامٍ أخرى.
const outside = async (cats) => Number((await one(`select count(*) n from public.provider_services
  where provider_id = $1 and category_id <> all ($2::uuid[])`, [provider.id, cats])).n)
ok('**والإدارةُ تضيف له قسماً ثانياً** — ويُعدّ ما بقي مخفيّاً', Array.isArray(both) && both[0].hidden === await outside([A, B]), JSON.stringify(both))
ok('**فتعود خدمتُه المخفيّةُ إلى العملاء** — بلا خطوةٍ ثانية', await seen(null, legacy))
const note = await one(`select title, body from public.notifications where provider_id = $1 order by created_at desc limit 1`, [provider.id])
ok('ويصله إشعارٌ بأقسامه', note?.title === 'تغيّرت أقسامُك', JSON.stringify(note))
const onlyB = await as(OWNER, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, [B]])
ok('**وتغييرُ قسمه يُخفي ما في القديم** — ويقول كم',
   Array.isArray(onlyB) && onlyB[0].hidden === await outside([B]) && onlyB[0].hidden >= 2 && !(await seen(null, mine)), JSON.stringify(onlyB))
const addB2 = await as(PUID, `insert into public.provider_services (provider_id, category_id, title, price, is_active)
  values ($1, $2, 'تصوير', 2000, true) returning id`, [provider.id, B])
ok('ويضيف في قسمه الجديد', Array.isArray(addB2), JSON.stringify(addB2))

await db.exec(read('provider_category_lock.sql'))
ok('وإعادةُ اللصق آمنة', (await q(`select 1 from public.provider_categories where provider_id = $1`, [provider.id])).length === 1)

console.log(fail === 0 ? '\nكلُّ اختبارات تقييد الأقسام نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
