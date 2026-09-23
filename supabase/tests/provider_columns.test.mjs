// أعمدةُ مقدّم الخدمة — ما يراه العامّة، وما يراه صاحبُه، وما يراه المسؤول.
//
// ── الثغرةُ التي يحرس إغلاقَها ─────────────────────────────────────────────
//
// `providers_public_read` تفتح الجدولَ لـ`anon` على كلّ صفٍّ موثَّق، **وRLS
// تحجب صفوفاً لا أعمدة**. فكان من ملك المفتاحَ العامّ — وهو في كلّ حزمة
// أندرويد — يقرأ بنداءٍ واحد: بريدَ كلِّ مزوّدٍ موثَّقٍ وجوّالَه، وكم كسب،
// وعمولتَه الخاصّة، وسببَ رفضه. أي دليلَ موردي الأعراس كلَّه مرتَّباً
// بالأرباح.
//
// ── والثلاثةُ تُقاس معاً، لا الحجبُ وحدَه ─────────────────────────────────
//
// حجبٌ يُقاس وحدَه يُغري بحجبٍ يكسر التطبيق: تُنزع الأعمدةُ فتُقفل الشاشةُ
// على صاحبها واللوحةُ على المسؤول، ويخضرّ الاختبار. فيُقاس البابان
// المفتوحان مع الباب المغلق:
//
//   · المجهولُ والعميلُ لا يريان الخمسة.
//   · وصاحبُ الملفّ يراها كلَّها — بـ`api_my_provider()`، ولا يرى ملفَّ غيره.
//   · والمسؤولُ يرى الجدولَ كلَّه بـ`v_admin_providers`.
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
                 'invitations.sql', 'provider_columns.sql']) {
  await db.exec(read(f))
}
// إعادةُ التشغيل لا تكسر شيئاً — وهو شرطٌ في كلّ ملفّ يُلصق في محرّر SQL.
await db.exec(read('provider_columns.sql'))

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const mustFail = async (label, fn) => {
  try {
    await fn()
    console.log(`❌ ${label} — نجح وكان يجب أن يفشل`)
    fail++
  } catch (e) {
    console.log(`✅ ${label} — مُنع: ${String(e.message).split('\n')[0].slice(0, 58)}`)
  }
}
const one = async (sql, params) => (await db.query(sql, params)).rows[0]

const SECRET = ['email', 'phone', 'total_earnings', 'commission_percent', 'rejection_reason']

// ── تجهيز: مزوّدان موثَّقان، وعميلٌ، ومسؤول ────────────────────────────────
const owner = '11111111-1111-1111-1111-111111111111'
const rival = '22222222-2222-2222-2222-222222222222'
const buyer = '33333333-3333-3333-3333-333333333333'
const boss = '44444444-4444-4444-4444-444444444444'

await db.exec(`
  insert into auth.users (id, email) values
    ('${owner}', 'owner@sdd.company'), ('${rival}', 'rival@sdd.company'),
    ('${buyer}', 'buyer@sdd.company'), ('${boss}', 'boss@sdd.company');
  insert into public.app_users (auth_user_id, full_name, email, status) values
    ('${owner}', 'صاحب قاعة',  'owner@sdd.company', 'active'),
    ('${rival}', 'منافس',      'rival@sdd.company', 'active'),
    ('${buyer}', 'عميل',       'buyer@sdd.company', 'active');
  insert into public.admins (user_id, email, role)
       values ('${boss}', 'boss@sdd.company', 'owner')
  on conflict (user_id) do update set role = 'owner';`)

// **والتجهيزُ يقع بصفة المسؤول**: مُشغِّلُ `guard_provider_self_update` يمنع
// كتابةَ الحالة والعمولة والأرباح من غيره — وهو حرزٌ قائمٌ لا يُلتفّ عليه
// حتى في تجهيزِ اختبار.
await db.exec(`select set_config('test.uid', '${boss}', false)`)

const mine = await one(`
  update public.service_providers
     set user_id = (select id from public.app_users where auth_user_id = '${owner}'),
         status = 'verified', verified_at = now(),
         email = 'hall@sdd.company', phone = '+967770000001',
         total_earnings = 7350000, commission_percent = 7.5,
         rejection_reason = 'صورةُ السجلّ غيرُ واضحة'
   where id = (select id from public.service_providers order by id limit 1)
  returning id`)
const theirs = await one(`
  update public.service_providers
     set user_id = (select id from public.app_users where auth_user_id = '${rival}'),
         status = 'verified', verified_at = now(),
         email = 'rival@sdd.company', phone = '+967770000002',
         total_earnings = 9900000
   where id = (select id from public.service_providers where id <> $1 order by id limit 1)
  returning id`, [mine.id])

const as = async (uid) =>
  db.exec(`select set_config('test.uid', ${uid ? `'${uid}'` : "''"}, false);
           set role ${uid ? 'authenticated' : 'anon'};`)
const off = () => db.exec('reset role')

// ── ١. الخمسةُ محجوبةٌ عن المجهول وعن المسجَّل ─────────────────────────────
//
// **وعن المسجَّل كذلك لا المجهولِ وحدَه**: من يتصفّح التطبيقَ مسجَّلٌ، وحسابٌ
// يُفتح في دقيقة.
console.log('=== الأعمدةُ الخمسةُ محجوبة ===')
for (const role of ['anon', 'authenticated']) {
  for (const column of SECRET) {
    const r = await one(
      `select has_column_privilege($1, 'public.service_providers', $2, 'select') p`,
      [role, column])
    ok(`${role} لا يقرأ ${column}`, r.p === false)
  }
}

console.log('=== ونداءُ العمود يُردّ فعلاً لا في الورق ===')
await as(buyer)
await mustFail('العميلُ لا يسحب بريدَ المزوّدين',
  () => db.query('select email, phone from public.service_providers'))
await mustFail('ولا أرباحَهم',
  () => db.query('select total_earnings from public.service_providers'))
await off()

await as(null)
await mustFail('والمجهولُ كذلك',
  () => db.query('select email, phone from public.service_providers'))
await off()

// ── ٢. وما يُعرض في التطبيق يبقى معروضاً ───────────────────────────────────
//
// **وهذه هي التي تمنع «حجباً يكسر»**: نزعٌ يقفل الدليلَ العامَّ على الناس
// يخضرّ في فحص الحجب ويُسقط التطبيق.
console.log('=== والدليلُ العامُّ يعمل كما كان ===')
await as(null)
const listed = await one('select count(*)::int n from public.v_providers')
ok(`المجهولُ يرى المزوّدين الموثَّقين (${listed.n})`, listed.n >= 2)
const card = await one(
  `select business_name, rating, governorate from public.v_providers limit 1`)
ok('وبطاقتُه كاملةٌ', Boolean(card.business_name) && card.rating !== null)
const services = await one('select count(*)::int n from public.v_services')
ok(`وقائمةُ الخدمات تعمل (${services.n})`, services.n > 0,
   'وسياستُها تسأل service_providers.status — فلو حُجب لَفرغت')
await off()

// ── ٣. وصاحبُ الملفّ يرى صفَّه كاملاً — وصفَّه وحدَه ───────────────────────
console.log('=== وصاحبُ الملفّ يرى أرباحَه ===')
await as(owner)
const myRow = await one('select * from public.api_my_provider()')
ok('الصفُّ وصل', myRow !== undefined && myRow.id === mine.id)
ok('وفيه الأرباح', Number(myRow.total_earnings) === 7350000, String(myRow.total_earnings))
ok('وفيه البريدُ والجوّال',
   myRow.email === 'hall@sdd.company' && myRow.phone === '+967770000001')
ok('وفيه سببُ الرفض', myRow.rejection_reason === 'صورةُ السجلّ غيرُ واضحة')
ok('وفيه العمولةُ الخاصّة', Number(myRow.commission_percent) === 7.5)

const rows = await db.query('select count(*)::int n from public.api_my_provider()')
ok('**ولا يرى إلّا صفّاً واحداً**', rows.rows[0].n === 1,
   'ولو أعادت أكثرَ لَقرأ المزوّدُ أرباحَ غيره')
await off()

console.log('=== والمنافسُ يرى صفَّه هو لا صفَّ جاره ===')
await as(rival)
const hisRow = await one('select * from public.api_my_provider()')
ok('صفُّه هو', hisRow.id === theirs.id, `${hisRow.id} ≠ ${mine.id}`)
ok('وأرباحُه هو', Number(hisRow.total_earnings) === 9900000)
await off()

console.log('=== والعميلُ الذي لا ملفَّ له لا يُخرج شيئاً ===')
// **ولا معرّفَ تأخذه الدالّة**، فلا يُمرَّر إليها معرّفُ غيره أصلاً — وهذا
// هو الحرزُ لا شرطٌ في جسمها.
await as(buyer)
const empty = await db.query('select count(*)::int n from public.api_my_provider()')
ok('لا صفّ', empty.rows[0].n === 0)
await off()

console.log('=== والمجهولُ لا ينادي الدالّةَ أصلاً ===')
await as(null)
await mustFail('ممنوع', () => db.query('select * from public.api_my_provider()'))
await off()

// ── ٤. والمسؤولُ يرى الجدولَ كلَّه ─────────────────────────────────────────
console.log('=== واللوحةُ تعمل: المسؤولُ يرى البريدَ والأرباح ===')
await as(boss)
const admin = await one(
  `select email, phone, total_earnings, commission_percent, rejection_reason, categories
     from public.v_admin_providers where id = $1`, [mine.id])
ok('البريدُ وصل اللوحة', admin?.email === 'hall@sdd.company')
ok('والأرباح', Number(admin?.total_earnings) === 7350000)
ok('والعمولة', Number(admin?.commission_percent) === 7.5)
ok('وسببُ الرفض', admin?.rejection_reason === 'صورةُ السجلّ غيرُ واضحة')
await off()

// ── ٥. والكتابةُ كما كانت — هذا نزعُ قراءةٍ لا نزعُ تعديل ──────────────────
console.log('=== واللوحةُ ما زالت توثّق وتضبط العمولة ===')
await as(boss)
await db.query(
  `update public.service_providers set commission_percent = 9 where id = $1`, [mine.id])
await off()
const changed = await one(
  'select commission_percent c from public.service_providers where id = $1', [mine.id])
ok('العمولةُ تبدّلت', Number(changed.c) === 9)

await db.close()
console.log(fail === 0 ? '\n✅ كلّها' : `\n❌ سقط ${fail}`)
process.exit(fail === 0 ? 0 : 1)
