/**
 * وسائط الخدمة: الجدول وقيوده وسياساته.
 *
 * وأهمّ ما يُثبَت هنا ثلاثة:
 *
 *   ١. أن ملفاً لا يُنسب إلى خدمةٍ ليست لصاحبه — والمفتاح المركّب هو الحارس،
 *      لا نيّةُ العميل. فلو كُتب `provider_id` بيدٍ من عرف اسم العمود لصار
 *      لصاحبه سلطانٌ على وسائط غيره عبر سياسة الكتابة نفسها.
 *   ٢. أن الدقيقة حدٌّ لا اقتراح.
 *   ٣. أن الحدّ العددي يقع فعلاً — قيدُ `check` لا يعدّ صفوفاً، فالمُشغِّل هو
 *      كلّ ما بيننا وبين أربعين صورةً في بطاقةٍ واحدة.
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

const media = read('service_media.sql')
await db.exec(media)
// إعادة التشغيل لا تكسر شيئاً: المالك يشغّل الملف مرّتين حين يشكّ.
await db.exec(media)

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

// ── تجهيز: مزوّدان لكلٍّ خدمة ────────────────────────────────────────────────
const { rows: cats } = await db.query(`select id from public.service_categories limit 1`)
const categoryId = cats[0].id

const makeProvider = async (email, status = 'verified') => {
  const { rows } = await db.query(
    `insert into public.service_providers (full_name, business_name, email, status, verified_at)
     values ($1, $1, $2, $3, case when $3 = 'verified' then now() end)
     returning id`,
    [email.split('@')[0], email, status],
  )
  return rows[0].id
}
const makeService = async (providerId, title, active = true) => {
  const { rows } = await db.query(
    `insert into public.provider_services (provider_id, category_id, title, price, is_active)
     values ($1, $2, $3, 100000, $4) returning id`,
    [providerId, categoryId, title, active],
  )
  return rows[0].id
}

const p1 = await makeProvider('hall@sdd.company')
const p2 = await makeProvider('band@sdd.company')
const s1 = await makeService(p1, 'قاعة التاج — باقة شاملة')
const s2 = await makeService(p2, 'فرقة صنعاء')

const add = (serviceId, providerId, kind, path, seconds = 0, order = 0) =>
  db.query(
    `insert into public.service_media (service_id, provider_id, kind, path, duration_seconds, sort_order)
     values ($1, $2, $3, $4, $5, $6) returning id`,
    [serviceId, providerId, kind, path, seconds, order],
  )

// ── ١. النسبة الخاطئة تُرفض من القاعدة ───────────────────────────────────────
await mustFail(
  'ملفٌ يُنسب إلى خدمةِ غيره يُرفض',
  () => add(s1, p2, 'image', `${p2}/${s1}/theft.jpg`),
  'service_media_service_fkey',
)
ok('والنسبة الصحيحة تُقبل', (await add(s1, p1, 'image', `${p1}/${s1}/1.jpg`)).rows.length === 1)

// ── ٢. الدقيقة حدّ ───────────────────────────────────────────────────────────
await mustFail(
  'مقطعٌ فوق الستّين ثانية يُرفض',
  () => add(s1, p1, 'video', `${p1}/${s1}/long.mp4`, 61),
  'duration_seconds',
)
ok('وستّون بالضبط تُقبل', (await add(s1, p1, 'video', `${p1}/${s1}/ok.mp4`, 60)).rows.length === 1)
await mustFail(
  'ومقطعٌ بلا مدّةٍ يُرفض — «صفر ثانية» تعني أن القياس لم يقع',
  () => add(s2, p2, 'audio', `${p2}/${s2}/silent.m4a`, 0),
  'service_media_clip_has_duration',
)
await mustFail(
  'وصورةٌ بمدّةٍ تُرفض',
  () => add(s2, p2, 'image', `${p2}/${s2}/weird.jpg`, 5),
  'service_media_still_has_no_duration',
)

// ── ٣. الحدّ العددي ──────────────────────────────────────────────────────────
await mustFail(
  'مقطع فيديو ثانٍ للخدمة يُرفض',
  () => add(s1, p1, 'video', `${p1}/${s1}/second.mp4`, 30),
  'مقطع فيديو واحد',
)
for (let i = 2; i <= 8; i++) await add(s1, p1, 'image', `${p1}/${s1}/${i}.jpg`, 0, i)
await mustFail(
  'والصورة التاسعة تُرفض',
  () => add(s1, p1, 'image', `${p1}/${s1}/9.jpg`, 0, 9),
  'ثماني صور',
)
ok(
  'والحدّ لكل خدمةٍ لا للمنصّة: خدمةٌ أخرى تبدأ من الصفر',
  (await add(s2, p2, 'audio', `${p2}/${s2}/sample.m4a`, 45)).rows.length === 1,
)

// ── ٤. المسار لا يتكرّر ──────────────────────────────────────────────────────
await mustFail(
  'مسارٌ مكرَّر يُرفض — صفّان على ملفٍ واحد يعني حذفاً يترك أحدهما معلّقاً',
  () => add(s2, p2, 'image', `${p1}/${s1}/1.jpg`),
  'service_media_path_key',
)

// ── ٥. حذف الخدمة يحذف وسائطها ──────────────────────────────────────────────
const s3 = await makeService(p2, 'خدمةٌ ستُحذف')
await add(s3, p2, 'image', `${p2}/${s3}/x.jpg`)
await db.query(`delete from public.provider_services where id = $1`, [s3])
const { rows: orphans } = await db.query(
  `select count(*)::int as n from public.service_media where service_id = $1`, [s3])
ok('حذف الخدمة يحذف وسائطها ولا يترك صفوفاً يتيمة', orphans[0].n === 0)

// ── ٦. السلّة وسياساتها ──────────────────────────────────────────────────────
const { rows: bucket } = await db.query(
  `select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'service-media'`)
ok('السلّة أُنشئت', bucket.length === 1)
ok('وهي عامّة — الوسائط ما يُقصد أن يُرى', bucket[0]?.public === true)
ok('وحدُّ الحجم ٥٠ ميجابايت', Number(bucket[0]?.file_size_limit) === 52428800)
for (const mime of ['image/jpeg', 'video/mp4', 'video/quicktime', 'audio/mpeg', 'audio/mp4']) {
  ok(`ونوع ${mime} مقبول`, bucket[0]?.allowed_mime_types?.includes(mime))
}
ok(
  'ولا تقبل PDF ولا تنفيذياً',
  !bucket[0]?.allowed_mime_types?.some((m) => m === 'application/pdf' || m.includes('octet-stream')),
)

const { rows: rowPolicies } = await db.query(
  `select policyname, cmd from pg_policies where schemaname = 'public' and tablename = 'service_media'`)
ok('سياستا الصفّ: قراءةٌ وكتابة', rowPolicies.length === 2, rowPolicies.map((p) => p.policyname).join('، '))
ok('والقراءة للجميع', rowPolicies.some((p) => p.cmd === 'SELECT'))

const { rows: objPolicies } = await db.query(
  `select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname like '%media%'`)
ok('وأربع سياساتٍ على السلّة', objPolicies.length === 4, objPolicies.map((p) => p.policyname).join('، '))

// الدوال التي تستند إليها السياسات موجودة فعلاً بهذه الأسماء — وإلّا مرّ
// الخطأ صامتاً ومَنَع كلَّ رفع.
for (const fn of ['current_provider', 'can_write', 'is_admin']) {
  const { rows } = await db.query(
    `select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = $1`, [fn])
  ok(`public.${fn}() موجودة`, rows.length === 1)
}

// ── ٧. الغلاف في v_services ─────────────────────────────────────────────────
const { rows: view } = await db.query(
  `select cover_path, images_count, has_video, has_audio from public.v_services where id = $1`, [s1])
ok('الغلاف أوّل صورةٍ بالترتيب', view[0]?.cover_path === `${p1}/${s1}/1.jpg`)
ok('وعدد الصور ثمانٍ', Number(view[0]?.images_count) === 8)
ok('ووجود الفيديو معلوم', view[0]?.has_video === true)
ok('وغياب الصوت معلوم', view[0]?.has_audio === false)

const { rows: view2 } = await db.query(
  `select cover_path, has_audio from public.v_services where id = $1`, [s2])
ok('وخدمةٌ بلا صورٍ غلافُها فارغ لا خطأ', view2[0]?.cover_path === null)
ok('وصوتُها معلوم', view2[0]?.has_audio === true)

// الأعمدة القديمة لم تتغيّر مواضعها — `create or replace view` يرفض ذلك،
// لكنّ الرفض يقع وقت التشغيل على قاعدة المالك لا هنا إن لم يُقَس.
const { rows: cols } = await db.query(
  `select column_name from information_schema.columns
    where table_schema = 'public' and table_name = 'v_services' order by ordinal_position`)
const names = cols.map((c) => c.column_name)
ok('و`id` ما زال أوّل أعمدة العرض', names[0] === 'id')
ok('و`cover_path` مُلحقٌ في الآخر لا مدسوسٌ في الوسط', names.indexOf('cover_path') > names.indexOf('cancellation_rules'))

// ── التوثيق في صفّ الخدمة، وترتيبُ الملفّات لا يكسر شيئاً ────────────────────
//
// **وهذا ما كان ينكسر بصمت:** `create or replace view` تقبل زيادة عمودٍ في
// الآخر وترفض ما عداه، فكان تشغيل `api.sql` بعد هذا الملف يسقط — ومن أعاد
// `install.sql` يوماً وجد خطأً لا يفهم سببه. فصار الملف يحذف الطريقة ويبنيها.
const hasCol = async (col) => (await db.query(
  `select 1 from information_schema.columns
    where table_schema='public' and table_name='v_services' and column_name=$1`, [col])).rows.length > 0

ok('والتوثيق مع صفّ الخدمة', await hasCol('provider_verified'))

let reorderFailed = null
try {
  // إعادةُ `api.sql` بعد ملفّ الوسائط: لا تسقط — وكانت تسقط.
  await db.exec(read('api.sql'))
} catch (e) {
  reorderFailed = e.message
}
ok('وإعادةُ api.sql بعده لا تسقط' + (reorderFailed ? ` — ${reorderFailed}` : ''),
   reorderFailed === null)

// **وأثرُها يُقال لا يُخفى:** `api.sql` يبني الطريقة الأساسية، فيذهب الغلاف
// حتى يُعاد ملفّ الوسائط. وهذا ما يقوله التعليق في الملف نفسه، والاختبار
// يثبت أنه صادق — لا أن الأمر بلا أثر.
ok('ويذهب الغلاف حتى يُعاد ملفّ الوسائط', !(await hasCol('cover_path')))
await db.exec(read('service_media.sql'))
ok('ويبقى الغلاف والتوثيق بعدها', (await hasCol('cover_path')) && (await hasCol('provider_verified')))

await db.close()
console.log(fail === 0 ? '\nكل اختبارات service_media.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
