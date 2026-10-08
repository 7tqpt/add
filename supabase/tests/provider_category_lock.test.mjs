// **أقسامُ مقدّم الخدمة، وخدمةٌ في غيرها تنتظر الموافقة — `provider_category_lock.sql`.**
//
// «مقدم الخدمة يختار القسم الذي يبغى بس لايمكنه تغيير الي بعلم الادارة»، واختار
// صاحبُ المنصّة (ج): يختار أيَّ قسم، وما ليس من أقسامه ينتظر — والإدارةُ توافق
// بإضافة القسم له أو على الخدمة وحدَها، أو ترفض بسبب. ويُقاس بأدوار القاعدة
// الحقيقيّة: ما يُحفظ وبأيّ حال، وما يراه الزائر، وما يُحجز، ومن يقرّر.
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
// **واللصقُ يقع على قاعدةٍ فيها خدماتٌ قائمة** — كما في القاعدة الحيّة.
await db.exec(read('provider_category_lock.sql'))

const seen = async (who, id) => {
  const r = await as(who, `select id from public.v_services where id = $1`, [id])
  return Array.isArray(r) && r.length === 1
}

const approval = async (id) => (await one(`select approval, approval_note from public.provider_services where id = $1`, [id]))
const addAs = async (who, cat, title) => as(who, `insert into public.provider_services (provider_id, category_id, title, price, is_active)
  values ($1, $2, $3, 2000, true) returning id, approval`, [provider.id, cat, title])

// ── ما كان قائماً خارج أقسامه صار «بانتظار الموافقة» ──────────────────────────
ok('**الخدمةُ القائمةُ خارج أقسامه صارت «بانتظار الموافقة»**', (await approval(legacy)).approval === 'pending')
ok('وما في قسمه بقيت موافَقاً عليها', (await approval(mine)).approval === 'approved')

// ── المزوّدُ يضيف في أيّ قسم — وما خارج أقسامه ينتظر ─────────────────────────
const addA = await addAs(PUID, A, 'باقةٌ جديدة')
ok('في قسمه: تُحفظ وتظهر فوراً', Array.isArray(addA) && addA[0].approval === 'approved' && (await seen(null, addA[0].id)), JSON.stringify(addA))
const addB = await addAs(PUID, B, 'تصوير حفلات')
ok('**وفي غير قسمه: تُحفظ ولا تُردّ** — «بانتظار الموافقة»', Array.isArray(addB) && addB[0].approval === 'pending', JSON.stringify(addB))
ok('**ولا يراها العميل**', !(await seen(null, addB[0].id)) && !(await seen(CUID, addB[0].id)))
const near = await as(null, `select id from public.api_services_nearby(15.35, 44.2, null, '', 300)`)
ok('ولا تأتي في «الأقرب إليّ»', Array.isArray(near) && !near.some((r) => r.id === addB[0].id) && near.some((r) => r.id === mine))
const own = await as(PUID, `select id from public.provider_services where id = $1`, [addB[0].id])
ok('وصاحبُها يراها', Array.isArray(own) && own.length === 1)

// ── ولا يكتب موافقتَه ولا أقسامَه ─────────────────────────────────────────────
await as(PUID, `update public.provider_services set approval = 'approved', approval_at = now() where id = $1`, [addB[0].id])
ok('**ولا يوافق على خدمته بنفسه**', (await approval(addB[0].id)).approval === 'pending')
const selfAdd = await as(PUID, `insert into public.provider_categories (provider_id, category_id) values ($1, $2)`, [provider.id, B])
ok('**ولا يضيف لنفسه قسماً**', refused(selfAdd), JSON.stringify(selfAdd))
await as(PUID, `delete from public.provider_categories where provider_id = $1`, [provider.id])
ok('ولا يحذف قسمَه', (await q(`select 1 from public.provider_categories where provider_id = $1`, [provider.id])).length === 1)

// ── ولا تُحجز ما لم يُوافَق عليها ─────────────────────────────────────────────
const day = new Date(Date.now() + 40 * 864e5).toISOString().slice(0, 10)
const booked = await as(CUID, `select id from public.api_create_booking($1, $2::date)`, [addB[0].id, day])
ok('**ولا تُحجز برابطٍ قديم**', refused(booked) && /غير متاحة للحجز/.test(booked.error), booked.error ?? JSON.stringify(booked))

// ── الموافقةُ على خدمةٍ بعينها، والرفضُ بسبب ─────────────────────────────────
const byProvider = await as(PUID, `select id from public.api_admin_review_service($1, true)`, [addB[0].id])
ok('**المزوّدُ لا يراجع خدمتَه**', refused(byProvider))
const noReason = await as(OWNER, `select id from public.api_admin_review_service($1, false, '  ')`, [addB[0].id])
ok('ولا رفضَ بلا سبب', refused(noReason) && /سبب الرفض/.test(noReason.error), noReason.error)
const rejected = await as(OWNER, `select approval from public.api_admin_review_service($1, false, 'خارج نشاط القاعة')`, [addB[0].id])
ok('**والرفضُ يُحفظ بسببه**', Array.isArray(rejected) && (await approval(addB[0].id)).approval_note === 'خارج نشاط القاعة')
ok('والمرفوضةُ لا تظهر', !(await seen(null, addB[0].id)))
const rejNote = await one(`select body from public.notifications where provider_id = $1 order by created_at desc limit 1`, [provider.id])
ok('**ويصله السبب**', /خارج نشاط القاعة/.test(rejNote?.body ?? ''), rejNote?.body)
const reviews = await as(OWNER, `select id, approval, provider_categories from public.api_admin_service_reviews()`)
ok('**وقائمةُ المراجعة تجمع المنتظرَ والمرفوض** — مع أقسام صاحبه',
   Array.isArray(reviews) && reviews.some((r) => r.id === legacy && r.approval === 'pending') && reviews.some((r) => r.id === addB[0].id && r.approval === 'rejected') && reviews.every((r) => r.provider_categories !== undefined),
   JSON.stringify(reviews).slice(0, 200))
const reviewsP = await as(PUID, `select id from public.api_admin_service_reviews()`)
ok('ولا يراها غيرُ الإدارة', Array.isArray(reviewsP) && reviewsP.length === 0)
await as(PUID, `update public.provider_services set price = 2500 where id = $1`, [addB[0].id])
ok('**والمرفوضةُ إن عدّلها صاحبُها عادت للمراجعة**', (await approval(addB[0].id)).approval === 'pending')
const okd = await as(OWNER, `select approval from public.api_admin_review_service($1, true)`, [addB[0].id])
ok('**والموافقةُ على خدمةٍ بعينها تُظهرها** — ولو بقي قسمُها خارج أقسامه', Array.isArray(okd) && (await seen(null, addB[0].id)))
await as(PUID, `update public.provider_services set price = 2600 where id = $1`, [addB[0].id])
ok('وتعديلُ سعرها بعد الموافقة لا ينقضها', (await approval(addB[0].id)).approval === 'approved')

// ── الإدارةُ تضبط أقسامَه — وإضافةُ القسم موافقةٌ على خدماته فيه ──────────────
const setByProvider = await as(PUID, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, [A, B]])
ok('**المزوّدُ لا يضبط أقسامَه بالدالّة**', refused(setByProvider))
const none = await as(OWNER, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, []])
ok('ولا يُترك بلا قسم', refused(none) && /قسماً واحداً على الأقلّ/.test(none.error), none.error)
const waitingOutside = async (cats) => Number((await one(`select count(*) n from public.provider_services
  where provider_id = $1 and approval <> 'approved'`, [provider.id])).n)
const both = await as(OWNER, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, [A, B]])
ok('**وإضافةُ قسمها له تقبل خدماتِه فيه كلَّها**', Array.isArray(both) && (await approval(legacy)).approval === 'approved' && (await seen(null, legacy)), JSON.stringify(both))
ok('ويُعدّ ما بقي منتظراً', Array.isArray(both) && both[0].hidden === await waitingOutside())
const note = await one(`select title from public.notifications where provider_id = $1 order by created_at desc limit 1`, [provider.id])
ok('ويصله إشعارٌ بأقسامه', note?.title === 'تغيّرت أقسامُك', JSON.stringify(note))
const later = await addAs(PUID, B, 'تصوير أعراس')
ok('**وخدماتُه القادمةُ في القسم المضاف تظهر بلا انتظار**', Array.isArray(later) && later[0].approval === 'approved')
const onlyB = await as(OWNER, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, [B]])
ok('**وحذفُ قسمٍ يُعيد خدماته فيه للمراجعة**', Array.isArray(onlyB) && (await approval(mine)).approval === 'pending' && !(await seen(null, mine)), JSON.stringify(onlyB))
ok('وما وُوفق عليه بعينه في القسم الباقي باقٍ', (await approval(addB[0].id)).approval === 'approved')
const onlyA = await as(OWNER, `select * from public.api_admin_set_provider_categories($1, $2::uuid[])`, [provider.id, [A]])
ok('**وحذفُ القسم الذي قُبلت به خدماتُه يُعيدها للمراجعة**', Array.isArray(onlyA) && (await approval(legacy)).approval === 'pending', JSON.stringify(onlyA))
ok('**إلّا ما وُوفق عليه بعينه** — يبقى ظاهراً', (await approval(addB[0].id)).approval === 'approved' && (await seen(null, addB[0].id)))

await db.exec(read('provider_category_lock.sql'))
ok('وإعادةُ اللصق آمنة', (await q(`select 1 from public.provider_categories where provider_id = $1`, [provider.id])).length === 1)

console.log(fail === 0 ? '\nكلُّ اختبارات تقييد الأقسام نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
