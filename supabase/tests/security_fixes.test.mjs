// **الفحصُ الأمنيُّ الثاني — كلُّ ثغرةٍ تُعاد كما وُجدت، وتُردّ.**
//
// تُبنى القاعدةُ كلُّها بترتيب النشر، ثمّ `security_fixes.sql` (مرّتين:
// إعادةُ اللصق آمنة)، ثمّ يُلعب كلُّ دورٍ **بأدوار القاعدة الحقيقيّة**
// (`anon` و`authenticated`) لا بصاحبها — فصاحبُها يتجاوز RLS ولا يقيس شيئاً.
//
// والهجماتُ هي التي أُثبتت في الفحص:
//   ١. مَن قدّم طلبَ «مقدّم خدمة» يفتح محادثةً مع أيّ عميلٍ باسم «فريق دعم
//      فرحتي» فيصله إشعار. ومعرّفُ العميل من `reviews.user_id` بلا حساب.
//   ٢. المزوّدُ يرفع مستنداً «معتمداً»، أو في مجلّد غيره.
//   ٣. تخمينُ أكواد الخصم بلا حدّ.
//   ٤. ربطُ حجزِ غيرِه بمحادثته.
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'
import { buildFixes } from '../../tool/security_sql.mjs'

const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8').replace(/\r\n/g, '\n')

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

// ── ٠. الملفُّ المشحونُ هو المركَّبُ من الأصول ────────────────────────────────
ok('**security_fixes.sql مطابقٌ لما يركّبه tool/security_sql.mjs**',
  read('security_fixes.sql').trimEnd() === buildFixes().trimEnd(),
  'أعد: node tool/security_sql.mjs fixes > supabase/security_fixes.sql')

// ما توفّره Supabase ولا يوجد في Postgres عارياً.
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

// **ترتيبُ النشر كما في README** — ثمّ إصلاحاتُ الفحص الأوّل، ثمّ هذا.
const ORDER = `install seed apply storage support roles invitations profile service_media chat
  notifications push_hook provider_logo payments_app availability subscriptions settlements
  promotions broadcast plan_tasks income chat_media profile_extras coupons location nearby
  category_images app_download share_link service_delete completion_review review_avatars
  phone_verify provider_columns profile_cover plan_cover plan_spend booking_cover booking_delete
  conversation_avatars customer_card phone_verify_attempts presence security_notification_rpcs
  audit_security security_hardening`.split(/\s+/)

const build = async ({ skip = [] } = {}) => {
  const db = new PGlite()
  await db.exec(SUPABASE)
  for (const f of ORDER) if (!skip.includes(f)) await db.exec(read(`${f}.sql`))
  return db
}

// ── ١. ولا يُلصق قبل ملفّ حدود المحاولات ──────────────────────────────────────
//
// دالّةُ الرسائل صارت تردّ التحقّقَ إن غاب الحدّ (`phone-otp/index.ts`)، فقاعدةٌ
// بلا `phone_verify_attempts.sql` تعني أنّ أحداً لا يؤكّد رقمَه. فيقول الملفُّ
// ذلك بدل أن يمرّ.
{
  const bare = await build({ skip: ['phone_verify', 'phone_verify_attempts', 'security_hardening'] })
  let msg = ''
  try { await bare.exec(read('security_fixes.sql')) } catch (e) { msg = e.message }
  ok('وعلى قاعدةٍ بلا حدود المحاولات يقف ويقول ما يُلصق أوّلاً',
    /phone_verify_attempts\.sql/.test(msg), msg || 'مرّ صامتاً')
  await bare.close()
}

const db = await build()

// **والقاعدةُ الحيّةُ لم تُبنَ من `install.sql` الجديد** بل من القديم: فيها
// سياسةُ الإدخال المباشر، والتقييماتُ ممنوحةٌ للزائر كاملة. فيُعاد ذلك هنا —
// وإلّا قاس الاختبارُ التثبيتَ الجديدَ ولم يقس أنّ اللصقةَ تُصلح القائم.
await db.exec(`
  create policy conversations_parties_write on public.conversations
    for insert to authenticated
    with check (user_id = public.current_app_user() or provider_id = public.current_provider());
  grant select on public.reviews to anon;`)

await db.exec(read('security_fixes.sql'))
await db.exec(read('security_fixes.sql')) // إعادةُ اللصق آمنة

const q = async (sql, params = []) => (await db.query(sql, params)).rows
const one = async (sql, params = []) => (await q(sql, params))[0]

/** يُنفَّذ بدور القاعدة الحقيقيّ — ويُرجع الصفوفَ أو رسالةَ الرفض. */
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

// ── تجهيز: عميلٌ ضحيّة، ومهاجمٌ يقدّم طلبَ مزوّد، ومسؤول ─────────────────────
const VICTIM = '11111111-1111-4111-8111-111111111111'
const ATTACKER = '22222222-2222-4222-8222-222222222222'
const ADMIN = '33333333-3333-4333-8333-333333333333'
await db.exec(`insert into auth.users (id, email) values
  ('${VICTIM}', 'victim@x.com'), ('${ATTACKER}', 'att@x.com'), ('${ADMIN}', 'boss@x.com');
  insert into public.admins (user_id, email, role) values ('${ADMIN}', 'boss@x.com', 'owner');`)

await as(VICTIM, `select public.api_register_profile('ضحيّة', '+967771234567', 'صنعاء', 'android')`)
await as(ATTACKER, `select public.api_register_profile('مهاجم', '+967770000000', 'صنعاء', 'android')`)
const victimId = (await one(`select id from public.app_users where auth_user_id = $1`, [VICTIM])).id
const category = (await one(`select id from public.service_categories limit 1`)).id
const applied = await as(ATTACKER,
  `select status from public.api_apply_as_provider('محلّ', '+967770000000', 'x', 'صنعاء', array[$1]::uuid[])`,
  [category])
ok('تجهيز: المهاجمُ مزوّدٌ تحت المراجعة', applied?.[0]?.status === 'pending', JSON.stringify(applied))
const attackerProvider = (await one(`
  select p.id from public.service_providers p join public.app_users u on u.id = p.user_id
   where u.auth_user_id = $1`, [ATTACKER])).id

// ── ٢. لا محادثةَ بإدخالٍ مباشر — ولا باسمٍ مزوَّر ────────────────────────────
const forged = await as(ATTACKER, `
  insert into public.conversations (user_id, user_name, provider_id, provider_name)
  values ($1, 'x', public.current_provider(), 'فريق دعم فرحتي') returning id`, [victimId])
ok('**مزوّدٌ لم يُوثَّق لا يفتح محادثةً مع عميلٍ باسمٍ يختاره**', refused(forged), JSON.stringify(forged))

const verified = await one(`select id from public.service_providers where status = 'verified' limit 1`)
const forgedByCustomer = await as(VICTIM, `
  insert into public.conversations (user_id, user_name, provider_id, provider_name)
  values (public.current_app_user(), 'إدارة فرحتي', $1, 'x') returning id`, [verified.id])
ok('ولا عميلٌ مع مزوّدٍ باسمٍ يختاره', refused(forgedByCustomer), JSON.stringify(forgedByCustomer))

ok('ولم يصل الضحيّةَ إشعار',
  Number((await one(`select count(*) n from public.notifications where user_id = $1`, [victimId])).n) === 0)

// والطريقُ المشروعُ باقٍ: الدالّةُ تفتحها وتكتب الاسمين من الملفّات.
const opened = await as(VICTIM, `select public.api_open_conversation($1) as id`, [verified.id])
ok('والعميلُ يفتح محادثةً بالدالّة كما كان', !refused(opened) && !!opened[0]?.id, JSON.stringify(opened))
const names = await one(`select user_name from public.conversations where id = $1`, [opened[0]?.id])
ok('واسمُه من ملفّه', names?.user_name === 'ضحيّة', names?.user_name)

// ── ٣. والحجزُ المربوطُ بالمحادثة حجزُ صاحبها ─────────────────────────────────
const someoneElses = await one(`select id, provider_id from public.bookings
  where user_id is distinct from $1 and provider_id is not null limit 1`, [victimId])
const linked = await as(VICTIM, `select public.api_open_conversation($1, $2) as id`,
  [someoneElses.provider_id, someoneElses.id])
ok('**ولا يُربط بمحادثتي حجزُ غيري**', refused(linked) && /ليس لك/.test(linked.error), JSON.stringify(linked))

// ── ٤. الزائرُ لا يرى مَن كتب التقييم ─────────────────────────────────────────
const anonIds = await as(null, `select user_id from public.reviews limit 1`)
ok('**الزائرُ لا يقرأ reviews.user_id**', refused(anonIds) && /permission denied/.test(anonIds.error),
  JSON.stringify(anonIds))
const anonReviews = await as(null,
  `select id, user_name, rating, comment, created_at from public.reviews where status = 'published' limit 3`)
ok('ويقرأ ما يُعرض كما كان', !refused(anonReviews) && anonReviews.length > 0, JSON.stringify(anonReviews))
const pub = await as(null, `select * from public.api_provider_reviews($1)`,
  [(await one(`select provider_id from public.reviews where status = 'published' limit 1`)).provider_id])
ok('ودالّةُ صفحة المزوّد كما كانت', !refused(pub) && pub.length > 0, JSON.stringify(pub).slice(0, 120))
const adminView = await as(ADMIN, `select user_id from public.v_admin_reviews where user_id is not null limit 1`)
ok('واللوحةُ ما زالت ترى صاحبَ التقييم', !refused(adminView) && adminView.length === 1, JSON.stringify(adminView))

// ── ٥. المستندُ يبدأ «قيد المراجعة»، وفي مجلّد صاحبه ─────────────────────────
const selfApproved = await as(ATTACKER, `
  insert into public.provider_documents (provider_id, type, file_name, file_url, status, reviewed_at, note)
  values (public.current_provider(), 'id_card', 'هويتي.jpg', public.current_provider()::text || '/1.jpg',
          'approved', now(), 'معتمد') returning status, reviewed_at, note`)
ok('**مستندٌ يُرفع «معتمداً» يُحفظ «قيد المراجعة»**',
  !refused(selfApproved) && selfApproved[0].status === 'pending' && selfApproved[0].reviewed_at === null
  && selfApproved[0].note === '', JSON.stringify(selfApproved))

for (const [label, path] of [
  ['مجلّد مزوّدٍ آخر', `${verified.id}/id.jpg`],
  ['صعودٌ من مجلّده', `${attackerProvider}/../${verified.id}/id.jpg`],
  ['بلا مجلّد', 'id.jpg'],
]) {
  const r = await as(ATTACKER, `
    insert into public.provider_documents (provider_id, type, file_name, file_url)
    values (public.current_provider(), 'id_card', 'x.jpg', $1) returning id`, [path])
  ok(`**ولا مستندَ في ${label}**`, refused(r) && /خارجَ مجلّدك/.test(r.error), JSON.stringify(r))
}

const doc = await one(`select id from public.provider_documents
  where provider_id = $1 and file_name = 'هويتي.jpg'`, [attackerProvider])
const reviewed = await as(ADMIN,
  `update public.provider_documents set status = 'approved', note = 'سليم', reviewed_at = now()
    where id = $1 returning status, note`, [doc.id])
ok('والمسؤولُ يعتمد كما كان', !refused(reviewed) && reviewed[0]?.status === 'approved'
  && reviewed[0]?.note === 'سليم', JSON.stringify(reviewed))

// ── ٦. أكوادُ الخصم: الخطأُ يُعدّ، والحجزُ يطلب تحقّقاً قبله ─────────────────
await db.exec(`insert into public.coupons (code, description, kind, value) values ('SAFE10', 'قياس', 'percent', 10)`)
const svc = await one(`select s.id from public.provider_services s
  join public.service_providers p on p.id = s.provider_id
 where s.is_active and p.status = 'verified' limit 1`)
const day = new Date(Date.now() + 40 * 86400000).toISOString().slice(0, 10)

const unchecked = await as(VICTIM,
  `select reference from public.api_create_booking($1, $2, null, null, 0, '', '', true, 'SAFE10')`,
  [svc.id, day])
ok('**ولا حجزَ بكودٍ لم يُتحقَّق منه** — وإلّا خُمِّنت الأكوادُ هنا بلا حدّ',
  refused(unchecked) && /تحقّق من الكود/.test(unchecked.error), JSON.stringify(unchecked))

for (let i = 1; i <= 10; i++) await as(VICTIM, `select * from public.api_check_coupon($1, $2)`, [`GUESS${i}`, svc.id])
const blocked = await as(VICTIM, `select * from public.api_check_coupon('SAFE10', $1)`, [svc.id])
ok('**وبعد عشرة أكوادٍ خاطئةٍ يقف التخمين**', refused(blocked) && /كثيرة/.test(blocked.error),
  JSON.stringify(blocked))

await db.exec(`delete from public.coupon_checks`)
const good = await as(VICTIM, `select * from public.api_check_coupon('SAFE10', $1)`, [svc.id])
ok('والكودُ الصحيحُ يُقبل', !refused(good) && good.length === 1, JSON.stringify(good))
const booked = await as(VICTIM,
  `select coupon_code from public.api_create_booking($1, $2, null, null, 0, '', '', true, 'SAFE10')`,
  [svc.id, day])
ok('ثمّ يُحجز به', !refused(booked) && booked[0]?.coupon_code === 'SAFE10', JSON.stringify(booked))

await db.close()
console.log(fail === 0 ? '\nكل اختبارات الفحص الأمني الثاني نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
