/**
 * المحادثة: المُشغِّل، وفتحُ الخيط، وعدُّ ما لم يُقرأ.
 *
 * وأهمّ ما يُثبَت هنا أن **العميل لا يكتب شيئاً من هذا بنفسه**: زمنُ آخر
 * رسالةٍ ونصُّها وعلامةُ القراءة كلُّها من المُشغِّل. ولو تُركت للعميل لأمكن
 * لطرفٍ أن يرفع محادثته إلى رأس قائمة الآخر، أو يُخفي عنه شارة «جديد» بأن
 * يُعلّمها مقروءة — وكلاهما يقع بجملةٍ واحدة يكتبها من عرف اسم العمود.
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
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql', 'invitations.sql']) {
  await db.exec(read(f))
}
const chat = read('chat.sql')
await db.exec(chat)
await db.exec(chat) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const mustFail = async (label, fn, expect) => {
  try {
    await fn()
    console.log(`❌ ${label} — نجح وكان يجب أن يفشل`)
    fail++
  } catch (e) {
    const hit = !expect || String(e.message).includes(expect)
    if (!hit) fail++
    console.log(`${hit ? '✅' : '❌'} ${label}${hit ? '' : ` — رُفض برسالةٍ أخرى: ${e.message}`}`)
  }
}
const as = async (uid, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid ?? ''])
  return db.query(sql, params)
}

// ── تجهيز: عميلٌ ومقدّما خدمة، لكلٍّ حساب مصادقة ─────────────────────────────
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

const { rows: pending } = await db.query(
  `insert into public.service_providers (full_name, business_name, email, status)
   values ('تحت المراجعة', 'قاعة لم تُوثّق', 'new@sdd.company', 'pending') returning id`)
const pendingProviderId = pending[0].id

// ── ١. فتح المحادثة ─────────────────────────────────────────────────────────
const { rows: opened } = await as(customerAuth,
  `select public.api_open_conversation($1) as id`, [providerId])
const conversationId = opened[0].id
ok('العميل يفتح محادثة', !!conversationId)

const { rows: again } = await as(customerAuth,
  `select public.api_open_conversation($1) as id`, [providerId])
ok('والضغط ثانيةً يعيد الخيط نفسه لا خيطاً جديداً', again[0].id === conversationId)

const { rows: names } = await db.query(
  `select user_name, provider_name from public.conversations where id = $1`, [conversationId])
ok('والأسماء تُكتب من القاعدة لا من العميل',
  names[0].user_name === 'أحمد الشرعبي' && names[0].provider_name === 'قاعة التاج',
  `${names[0].user_name} / ${names[0].provider_name}`)

await mustFail(
  'ومقدّمُ خدمةٍ غير موثّق لا تُفتح إليه محادثة',
  () => as(customerAuth, `select public.api_open_conversation($1)`, [pendingProviderId]),
  'غير موثّق',
)
await mustFail(
  'ومن لا حساب له لا يفتح شيئاً',
  () => as(null, `select public.api_open_conversation($1)`, [providerId]),
  'قبل إكمال حسابك',
)

// ── ٢. المُشغِّل ─────────────────────────────────────────────────────────────
const before = (await db.query(
  `select last_message_at from public.conversations where id = $1`, [conversationId])).rows[0]

const send = (uid, sender, body) => as(uid,
  `insert into public.conversation_messages (conversation_id, sender, body)
   values ($1, $2, $3)`, [conversationId, sender, body])

await send(customerAuth, 'customer', 'السلام عليكم، القاعة متاحة يوم ١٥ سبتمبر؟')

const after = (await db.query(
  `select last_message_at, last_message_body, last_message_sender,
          customer_read_at, provider_read_at
     from public.conversations where id = $1`, [conversationId])).rows[0]

ok('الرسالة تحرّك زمن المحادثة', after.last_message_at > before.last_message_at)
ok('ونصُّها يُحفظ للقائمة', after.last_message_body.startsWith('السلام عليكم'))
ok('ومَن أرسلها', after.last_message_sender === 'customer')
ok('والمرسِل يُعدّ قارئاً لكلامه', after.customer_read_at !== null)
ok('والطرف الآخر لا', after.provider_read_at === null)

const long = 'ا'.repeat(400)
await send(customerAuth, 'customer', long)
const cut = (await db.query(
  `select length(last_message_body) as n, (select length(body) from public.conversation_messages
     where conversation_id = $1 order by created_at desc limit 1) as full
     from public.conversations where id = $1`, [conversationId])).rows[0]
ok('والنصّ الطويل يُقصّ في القائمة ولا يُقصّ في الرسالة',
  Number(cut.n) === 160 && Number(cut.full) === 400, `${cut.n} / ${cut.full}`)

// ── ٣. عدّ ما لم يُقرأ ───────────────────────────────────────────────────────
const unreadFor = async (uid) => {
  const { rows } = await as(uid,
    `select unread_count, other_name, my_side from public.v_my_conversations where id = $1`,
    [conversationId])
  return rows[0]
}

const forProvider = await unreadFor(hallAuth)
ok('صاحب القاعة يرى رسالتين لم يقرأهما', Number(forProvider?.unread_count) === 2,
  String(forProvider?.unread_count))
ok('ويرى اسم العميل لا اسم قاعته', forProvider?.other_name === 'أحمد الشرعبي')
ok('وجانبه «provider»', forProvider?.my_side === 'provider')

const forCustomer = await unreadFor(customerAuth)
ok('والعميل لا يرى جديداً — الرسالتان له', Number(forCustomer?.unread_count) === 0)
ok('ويرى اسم القاعة', forCustomer?.other_name === 'قاعة التاج')

await as(hallAuth, `select public.api_mark_conversation_read($1)`, [conversationId])
ok('وبعد القراءة يصفر العدّاد', Number((await unreadFor(hallAuth))?.unread_count) === 0)

await send(hallAuth, 'provider', 'وعليكم السلام، متاحة. العربون ٣٠٪.')
ok('وردُّ القاعة يظهر جديداً عند العميل',
  Number((await unreadFor(customerAuth))?.unread_count) === 1)

// ── ٤. لا يُعلّم أحدٌ محادثة غيره ────────────────────────────────────────────
const outsiderAuth = await mkAuth('other@sdd.company')
await db.query(
  `insert into public.app_users (auth_user_id, full_name, email, status)
   values ($1, 'غريب', 'other@sdd.company', 'active')`, [outsiderAuth])

await as(outsiderAuth, `select public.api_mark_conversation_read($1)`, [conversationId])
const stillUnread = await unreadFor(customerAuth)
ok('غريبٌ يستدعي «علّمها مقروءة» فلا يقع شيء',
  Number(stillUnread?.unread_count) === 1, String(stillUnread?.unread_count))

const { rows: outsiderList } = await as(outsiderAuth,
  `select count(*)::int as n from public.v_my_conversations`)
ok('ولا يرى المحادثة في قائمته', outsiderList[0].n === 0)

// ── ٤ب. صاحب القاعة يبدأ محادثةً على حجزٍ له ────────────────────────────────
const { rows: svc } = await db.query(
  `insert into public.provider_services (provider_id, category_id, title, price)
   values ($1, (select id from public.service_categories limit 1), 'باقة', 100000)
   returning id`, [providerId])
const { rows: bk } = await db.query(
  `insert into public.bookings
     (reference, user_id, user_name, provider_id, provider_name, service_id, service_title,
      event_date, address, guests_count, total_price, deposit_amount)
   values ('BK-T-1', $1, 'أحمد الشرعبي', $2, 'قاعة التاج', $3, 'باقة',
           current_date + 20, 'صنعاء', 300, 100000, 30000)
   returning id`, [customerId, providerId, svc[0].id])
const bookingId = bk[0].id

const { rows: fromProvider } = await as(hallAuth,
  `select public.api_open_conversation_with_customer($1) as id`, [bookingId])
ok('صاحب القاعة يفتح المحادثة على حجزٍ له', !!fromProvider[0].id)
ok('وهي الخيط نفسه لا خيطٌ ثانٍ مع العميل نفسه', fromProvider[0].id === conversationId)

const { rows: linked } = await db.query(
  `select booking_id from public.conversations where id = $1`, [conversationId])
ok('والحجز يُربط بها', linked[0].booking_id === bookingId)

await mustFail(
  'وحجزُ غيره لا يفتح له شيئاً',
  () => as(outsiderAuth, `select public.api_open_conversation_with_customer($1)`, [bookingId]),
  'لمقدّمي الخدمة',
)

// ── ٥. السياسات موجودة كما يفترضه كلُّ ما سبق ───────────────────────────────
const { rows: pol } = await db.query(
  `select tablename, policyname, cmd from pg_policies
    where schemaname = 'public' and tablename in ('conversations', 'conversation_messages')
    order by tablename, policyname`)
ok('أربع سياساتٍ على الجدولين', pol.length === 4, pol.map((p) => p.policyname).join('، '))
ok('ولا سياسة `update` على المحادثات — التحديث للمُشغِّل وحده',
  !pol.some((p) => p.tablename === 'conversations' && p.cmd === 'UPDATE'))

const { rows: rls } = await db.query(
  `select relname, relrowsecurity from pg_class
    where relname in ('conversations', 'conversation_messages')`)
ok('وحماية الصفّ مفعّلة على الاثنين', rls.every((r) => r.relrowsecurity))

await db.close()
console.log(fail === 0 ? '\nكل اختبارات chat.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
