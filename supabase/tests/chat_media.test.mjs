/**
 * مرفقاتُ المحادثة: صورةٌ وصوتٌ وفيديو وملفّ.
 *
 * وأهمّ ما يُثبَت هنا:
 *
 *   ١. **أن السلّة خاصّة.** صورةُ عقدٍ أو حديثُ رجلٍ عن عرس ابنته ليسا
 *      معروضين لأحد — ورابطٌ عامٌّ يعني أن من خمّن مساراً فتح محادثةً ليست
 *      له. وسلّةُ وسائط الخدمات عامّة، فنسخُ سطرٍ منها هنا كان يكشف
 *      المحادثات كلَّها بلا أن يظهر في أي شاشة.
 *   ٢. وأن غريباً لا يفتح مرفقَ محادثةٍ ليس طرفاً فيها.
 *   ٣. وأن **المدّة للمسموع والمرئيّ وحدهما** — صورةٌ «مدّتها ١٢ ثانية» صفٌّ
 *      لا معنى له.
 *   ٤. وأن رسالةً فارغةً من النصّ والمرفق معاً تُردّ.
 *   ٥. وأن معاينة الخيط تقول ما وصل: صورةٌ أم صوتٌ أم ملفٌّ باسمه.
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
const file = read('chat_media.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── تجهيز: عميلٌ ومزوّدٌ ومحادثةٌ بينهما، وغريبٌ ثالث ────────────────────────
const cuid = 'c0000000-0000-0000-0000-000000000001'
const puid = 'c0000000-0000-0000-0000-000000000002'
const xuid = 'c0000000-0000-0000-0000-000000000003'

const provider = await one(
  `select id from public.service_providers where status = 'verified' order by id limit 1`)

await db.exec(`
  insert into auth.users (id, email) values
    ('${cuid}', 'c@sdd.company'), ('${puid}', 'p@sdd.company'), ('${xuid}', 'x@sdd.company')
  on conflict (id) do nothing;

  insert into public.app_users (auth_user_id, full_name, email, status) values
    ('${cuid}', 'أبو العروس', 'c@sdd.company', 'active'),
    ('${puid}', 'صاحب القاعة', 'p@sdd.company', 'active'),
    ('${xuid}', 'غريب',       'x@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = excluded.auth_user_id;

  update public.service_providers
     set user_id = (select id from public.app_users where auth_user_id = '${puid}')
   where id = '${provider.id}';`)

const convo = await one(`
  insert into public.conversations (user_id, user_name, provider_id, provider_name)
       values ((select id from public.app_users where auth_user_id = '${cuid}'),
               'أبو العروس', '${provider.id}', 'قاعة')
  returning id`)

const as = async (uid) => {
  await db.exec(`reset role`)
  await db.exec(`select set_config('test.uid', '${uid}', false)`)
  await db.exec(`set role authenticated`)
}

const send = (kind, extra = {}) => db.query(
  `insert into public.conversation_messages
       (conversation_id, sender, body, attachment_path, attachment_kind,
        attachment_seconds, attachment_name, attachment_size)
   values ($1, 'customer', $2, $3, $4, $5, $6, $7) returning *`,
  [convo.id, extra.body ?? '', extra.path ?? `${convo.id}/x.bin`, kind,
   extra.seconds ?? null, extra.name ?? null, extra.size ?? null])

// ── ١. السلّة خاصّة ─────────────────────────────────────────────────────────
const bucket = await one(`select public from storage.buckets where id = 'chat-media'`)
ok('سلّةُ المرفقات خاصّة لا عامّة', bucket.public === false)

// وضبطُ عيارٍ داخل الاختبار: سلّةُ وسائط الخدمات عامّةٌ فعلاً — فلو كان
// التأكيد أعلاه يقيس شيئاً ثابتاً لمرّ بلا معنى.
await db.exec(read('service_media.sql'))
const other = await one(`select public from storage.buckets where id = 'service-media'`)
ok('وسلّةُ الخدمات عامّةٌ — فالفرقُ مقصودٌ لا صدفة', other.public === true)

// ── ٢. طرفا المحادثة يفتحان مرفقاتها، والغريبُ لا ───────────────────────────
await as(cuid)
ok('العميلُ طرفٌ في محادثته',
   (await one(`select public.in_conversation('${convo.id}') as ف`)).ف === true)
await as(puid)
ok('والمزوّدُ كذلك',
   (await one(`select public.in_conversation('${convo.id}') as ف`)).ف === true)
await as(xuid)
ok('والغريبُ لا',
   (await one(`select public.in_conversation('${convo.id}') as ف`)).ف === false)
ok('ومسارٌ مجهولٌ يُردّ', (await one(
  `select public.in_conversation('11111111-1111-1111-1111-111111111111') as ف`)).ف === false)

// ── ٣. الأنواعُ الأربعة تُقبل بشروطها ───────────────────────────────────────
await as(cuid)
const image = await one(
  `select * from public.conversation_messages where id = ($1)`,
  [(await send('image', { path: `${convo.id}/a.jpg`, size: 90000 })).rows[0].id])
ok('صورةٌ بلا مدّةٍ تُقبل', image.attachment_kind === 'image' && image.attachment_seconds === null)

const voice = (await send('audio', { path: `${convo.id}/b.m4a`, seconds: 12 })).rows[0]
ok('ورسالةٌ صوتيةٌ بمدّتها', voice.attachment_seconds === 12)

const clip = (await send('video', { path: `${convo.id}/c.mp4`, seconds: 30 })).rows[0]
ok('ومقطعُ فيديو', clip.attachment_kind === 'video')

// والفيديو يقبل غيابَ المدّة — لأنها لا تُقاس إلا بفتح المقطع، وخزنُ رقمٍ
// لم يُقَس أسوأ من تركه فارغاً.
const clipless = (await send('video', { path: `${convo.id}/c2.mp4` })).rows[0]
ok('وفيديو بلا مدّةٍ يُقبل — بخلاف الصوت', clipless.attachment_seconds === null)

const doc = (await send('file', { path: `${convo.id}/d.pdf`, name: 'العقد.pdf', size: 120000 })).rows[0]
ok('وملفٌّ باسمه', doc.attachment_name === 'العقد.pdf')

// ── ٤. والقيودُ تردّ ما لا معنى له ──────────────────────────────────────────
const rejects = async (label, run, pattern) => {
  let raised = null
  try { await run() } catch (e) { raised = e.message }
  ok(label, pattern.test(raised ?? ''))
}

await rejects('صورةٌ بمدّةٍ تُردّ',
  () => send('image', { path: `${convo.id}/e.jpg`, seconds: 12 }),
  /message_attachment_seconds/)

await rejects('وصوتٌ بلا مدّةٍ يُردّ',
  () => send('audio', { path: `${convo.id}/f.m4a` }),
  /message_attachment_seconds/)

await rejects('وفيديو فوق الدقيقة يُردّ',
  () => send('video', { path: `${convo.id}/g.mp4`, seconds: 90 }),
  /message_attachment_seconds/)

await rejects('وملفٌّ بلا اسمٍ يُردّ',
  () => send('file', { path: `${convo.id}/h.pdf` }),
  /message_file_named/)

await rejects('ونوعٌ غيرُ معروفٍ يُردّ',
  () => send('sticker', { path: `${convo.id}/i.webp` }),
  /message_attachment_kind/)

await rejects('ورسالةٌ فارغةٌ من النصّ والمرفق تُردّ',
  () => db.query(
    `insert into public.conversation_messages (conversation_id, sender, body)
          values ('${convo.id}', 'customer', '   ')`),
  /message_not_empty/)

// ── ٥. والمعاينة تقول ما وصل ────────────────────────────────────────────────
const previewOf = async () => (await one(
  `select last_message_body from public.conversations where id = '${convo.id}'`)
).last_message_body

await db.exec(`reset role`); await as(cuid)
await send('image', { path: `${convo.id}/j.jpg` })
await db.exec(`reset role`)
ok('معاينةُ الصورة تقول «صورة»', /صورة/.test(await previewOf()))

await as(cuid)
await send('file', { path: `${convo.id}/k.pdf`, name: 'عقد القاعة.pdf' })
await db.exec(`reset role`)
ok('ومعاينةُ الملفّ تحمل اسمه', /عقد القاعة\.pdf/.test(await previewOf()))

await as(puid)
await db.query(`insert into public.conversation_messages (conversation_id, sender, body)
                     values ('${convo.id}', 'provider', 'أهلاً، القاعة متاحة')`)
await db.exec(`reset role`)
ok('ورسالةٌ نصّيةٌ تُعاين بنصّها', (await previewOf()) === 'أهلاً، القاعة متاحة')

// ── ٦. وغريبٌ لا يقرأ الرسائل أصلاً ─────────────────────────────────────────
await as(xuid)
ok('الغريبُ لا يقرأ رسائل محادثةٍ ليست له',
   Number((await one(`select count(*) as ع from public.conversation_messages
                       where conversation_id = '${convo.id}'`)).ع) === 0)
await db.exec(`reset role`)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات chat_media.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
