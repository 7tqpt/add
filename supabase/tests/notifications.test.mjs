/**
 * الإشعارات: مُشغِّل الرسالة، ورمز الجهاز.
 *
 * وأهمّ ما يُثبَت هنا شيئان:
 *
 *   ١. أن إشعار الرسالة **واحدٌ لكل محادثة لا واحدٌ لكل رسالة**. ومن كتب
 *      عشرين سطراً متتابعاً كان سينتج عشرين صفّاً، فيصير الصندوق سجلَّ
 *      محادثةٍ يُدفن فيه «قُبل حجزك» بين كلامٍ عابر.
 *   ٢. أن رمز الجهاز **فريد**: FCM يُصدر رمزاً لكل تثبيت، وقد ينتقل الجهاز
 *      إلى حسابٍ آخر. فلولا الفريد لبقي الرمز مقيّداً لصاحبه الأول ووصلت
 *      إشعاراتُ حسابٍ إلى من سجّل بعده — وهو تسريبٌ لا عطبُ راحة.
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
                 'invitations.sql', 'chat.sql']) {
  await db.exec(read(f))
}
const file = read('notifications.sql')
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

// ── تجهيز ───────────────────────────────────────────────────────────────────
const mkAuth = async (email) => {
  const { rows } = await db.query(
    `insert into auth.users (id, email) values (gen_random_uuid(), $1) returning id`, [email])
  return rows[0].id
}
const customerAuth = await mkAuth('ahmed@sdd.company')
const hallAuth = await mkAuth('hall@sdd.company')

const { rows: cust } = await db.query(
  `insert into public.app_users (auth_user_id, full_name, email, status)
   values ($1, 'أحمد الشرعبي', 'ahmed@sdd.company', 'active') returning id`, [customerAuth])
const customerId = cust[0].id

const { rows: hallUser } = await db.query(
  `insert into public.app_users (auth_user_id, full_name, email, status)
   values ($1, 'صاحب القاعة', 'hall@sdd.company', 'active') returning id`, [hallAuth])
const { rows: prov } = await db.query(
  `insert into public.service_providers (user_id, full_name, business_name, email, status, verified_at)
   values ($1, 'صاحب القاعة', 'قاعة التاج', 'hall@sdd.company', 'verified', now()) returning id`,
  [hallUser[0].id])
const providerId = prov[0].id

const { rows: convo } = await as(customerAuth,
  `select public.api_open_conversation($1) as id`, [providerId])
const conversationId = convo[0].id

const send = (uid, sender, body) => as(uid,
  `insert into public.conversation_messages (conversation_id, sender, body) values ($1, $2, $3)`,
  [conversationId, sender, body])

const inbox = async (column, owner) => {
  const { rows } = await db.query(
    `select id, kind, title, body, read_at, created_at from public.notifications
      where ${column} = $1 order by created_at desc`, [owner])
  return rows
}

// ── ١. إشعار الرسالة ────────────────────────────────────────────────────────
await send(customerAuth, 'customer', 'السلام عليكم، القاعة متاحة يوم ١٥ سبتمبر؟')

let forProvider = await inbox('provider_id', providerId)
ok('رسالة العميل تُنشئ إشعاراً عند المزوّد', forProvider.length === 1)
ok('عنوانه اسمُ من كتب', forProvider[0]?.title === 'أحمد الشرعبي')
ok('ونصُّه نصُّ الرسالة', forProvider[0]?.body?.startsWith('السلام عليكم'))
ok('ونوعُه «message»', forProvider[0]?.kind === 'message')

const forCustomer = await inbox('user_id', customerId)
ok('ولا يصل المرسِلَ إشعارٌ بكلامه', forCustomer.length === 0)

// ── ٢. واحدٌ لكل محادثة ─────────────────────────────────────────────────────
await send(customerAuth, 'customer', 'وهل يوجد موقف سيارات؟')
await send(customerAuth, 'customer', 'وكم يتّسع؟')
forProvider = await inbox('provider_id', providerId)
ok('وثلاث رسائل تبقى إشعاراً واحداً', forProvider.length === 1, `${forProvider.length}`)
ok('ونصُّه آخرُ ما قيل', forProvider[0]?.body === 'وكم يتّسع؟', forProvider[0]?.body)

// ثمّ يُقرأ، فالرسالة التالية إشعارٌ جديد — وإلّا صمت الصندوق بعد أول قراءة.
await db.query(`update public.notifications set read_at = now() where id = $1`,
  [forProvider[0].id])
await send(customerAuth, 'customer', 'أنا في انتظارك')
forProvider = await inbox('provider_id', providerId)
ok('وبعد القراءة تُنبّه الرسالة التالية من جديد', forProvider.length === 2,
  `${forProvider.length}`)

// ── ٣. الاتجاه الآخر ────────────────────────────────────────────────────────
await send(hallAuth, 'provider', 'نعم متاحة، والعربون ٣٠٪.')
const backToCustomer = await inbox('user_id', customerId)
ok('وردُّ المزوّد يصل العميل', backToCustomer.length === 1)
ok('بعنوان اسم القاعة', backToCustomer[0]?.title === 'قاعة التاج')

// ── ٤. «علّم الكلّ مقروءاً» ─────────────────────────────────────────────────
const { rows: marked } = await as(hallAuth, `select public.api_mark_all_notifications_read() as n`)
ok('تعليم الكلّ يُعيد عدد ما غيّره', Number(marked[0].n) === 1, String(marked[0].n))
ok('ولا يبقى غير مقروء',
  (await inbox('provider_id', providerId)).every((r) => r.read_at !== null))
ok('ولا يمسّ صندوق غيره',
  (await inbox('user_id', customerId)).every((r) => r.read_at === null))

// ── ٥. رمز الجهاز ───────────────────────────────────────────────────────────
await as(customerAuth,
  `select public.api_register_push_token($1, 'android', 'Redmi Note 12', '14')`, ['TOKEN-A'])
// والتصفية بالرمز لا بعدّ الجدول: البذرة تملؤه بثمانين جهازاً، فعدُّ الكلّ
// يقيس البذرة لا ما سجّلناه.
let devices = (await db.query(
  `select user_id, push_token, model, platform from public.user_devices
    where push_token = 'TOKEN-A'`)).rows
ok('الرمز يُسجَّل', devices.length === 1 && devices[0].push_token === 'TOKEN-A')
ok('ومعه الطراز والمنصّة', devices[0].model === 'Redmi Note 12' && devices[0].platform === 'android')

await as(customerAuth,
  `select public.api_register_push_token($1, 'android', 'Redmi Note 12', '14')`, ['TOKEN-A'])
devices = (await db.query(
  `select count(*)::int as n from public.user_devices where push_token = 'TOKEN-A'`)).rows
ok('وإعادة تسجيله لا تُنشئ صفّاً ثانياً', devices[0].n === 1, String(devices[0].n))

// الجهاز نفسه يُسلَّم لحسابٍ آخر — وهذا هو موضع التسريب لو لم يُنقل الرمز.
await as(hallAuth,
  `select public.api_register_push_token($1, 'android', 'Redmi Note 12', '14')`, ['TOKEN-A'])
const { rows: moved } = await db.query(
  `select user_id from public.user_devices where push_token = 'TOKEN-A'`)
ok('والرمز ينتقل إلى من سجّل بعده لا يبقى لسابقه',
  moved.length === 1 && moved[0].user_id === hallUser[0].id)

await as(hallAuth, `select public.api_forget_push_token('TOKEN-A')`)
const { rows: gone } = await db.query(
  `select count(*)::int as n from public.user_devices where push_token is not null`)
ok('والخروج ينسى الرمز', gone[0].n === 0)

// من لا حساب له لا يسجّل شيئاً — ولا يسقط النداء.
await as(null, `select public.api_register_push_token('TOKEN-Z')`)
const { rows: anon } = await db.query(
  `select count(*)::int as n from public.user_devices where push_token = 'TOKEN-Z'`)
ok('ومن لا حساب له لا يُسجَّل له رمز ولا يسقط النداء', anon[0].n === 0)

// ── ٦. ما كان يكتب الإشعارات أصلاً ما زال يكتبها ────────────────────────────
// سبعةُ مواضع في `api.sql` تستدعي `notify_*`. وهذا يثبت أن الدالّتين ما زالتا
// موجودتين بالتوقيع نفسه — فتغييرُ إحداهما يُسكت سبعة أحداثٍ دفعةً واحدة.
for (const fn of ['notify_user', 'notify_provider']) {
  const { rows } = await db.query(
    `select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = $1`, [fn])
  ok(`public.${fn}() موجودة`, rows.length === 1)
}
const calls = read('api.sql').match(/perform public\.notify_(user|provider)\(/g) ?? []
ok('وسبعةُ مواضع تستدعيها في api.sql', calls.length === 7, String(calls.length))

await db.close()
console.log(fail === 0 ? '\nكل اختبارات notifications.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
