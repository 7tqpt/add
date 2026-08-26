/**
 * الملف الشخصي: قراءةٌ وتعديل.
 *
 * وأهمّ ما يُثبَت هنا ما **لا** تفعله الدالة: الحقول الأربعة وحدها تُقبل،
 * و`status` و`email` و`auth_user_id` في الجدول نفسه — ولولا الحراسة لطالتها
 * يدُ من عرف اسم العمود. ومستخدمٌ يرفع نفسه إلى `active` بنفسه يتخطّى
 * مراجعةً كاملة.
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
  -- ما يكفي من storage لتمرّ جملُ السلّة والسياسات في بيئة اختبار.
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
await db.exec(read('profile.sql'))

const as = async (uid, sql, params) => {
  await db.query(`select set_config('test.uid', $1, false)`, [uid ?? ''])
  return db.query(sql, params)
}

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
    console.log(`✅ ${label} — مُنع: ${String(e.message).split('\n')[0].slice(0, 44)}`)
  }
}

// ── مستخدمٌ حقيقيّ ───────────────────────────────────────────────────────────
const UID = '11111111-1111-1111-1111-111111111111'
await db.exec(`
  insert into auth.users (id, email) values ('${UID}', 'user@aras.ye');
  insert into public.app_users (auth_user_id, full_name, email, phone, status)
    values ('${UID}', 'أيمن', 'user@aras.ye', '770000000', 'active');
`)

console.log('=== البنية ===')
const col = await db.query(`select count(*)::int n from information_schema.columns
  where table_name='app_users' and column_name='avatar_path'`)
ok('عمود الصورة أُضيف', col.rows[0].n === 1)
const bucket = await db.query(`select public, file_size_limit from storage.buckets where id='avatars'`)
ok('السلّة عامّة', bucket.rows[0]?.public === true)
ok('وحدّها ٢ ميجابايت', Number(bucket.rows[0]?.file_size_limit) === 2097152)

console.log('\n=== القراءة ===')
const mine = await as(UID, `select full_name, email from public.api_my_profile()`)
ok('أقرأ ملفي', mine.rows[0]?.full_name === 'أيمن', mine.rows[0]?.email)
// **وعددُ الصفوف هو المقياس، لا فراغُ الحقل.**
//
// كانت الدالّة تُرجع نوعاً مركّباً واحداً، فإن لم تجد شيئاً أعادت `NULL` —
// و`count(*)` على ذلك يساوي ١ لا ٠. ولاحظتُ ذلك حين كتبتُ هذا الاختبار
// أوّلَ مرّة، ثمّ **تحايلتُ عليه** فسألتُ عن فراغ الحقل بدل عدد الصفوف.
// وكان ذلك خطأً: الحقلُ فارغٌ في الحالين، فمرّ الحارس والعطبُ تحته.
//
// والذي يصل التطبيقَ هو ما ينتجه `select * from f()` — أي صفٌّ من الأصفار
// `{"id":null,…}`، فيسقط أوّلُ تحويلٍ إلى نصّ. فصارت الدالّة `setof`،
// ويُقاس عددُ الصفوف نفسه.
const none = await as('22222222-2222-2222-2222-222222222222',
  `select count(*)::int as عدد from (select * from public.api_my_profile()) q`)
ok('ومن لا ملفَّ له يُعيد صفرَ صفوفٍ كما يقرؤه PostgREST',
   none.rows[0].عدد === 0, `${none.rows[0].عدد}`)
const some = await as(UID,
  `select count(*)::int as عدد from (select * from public.api_my_profile()) q`)
ok('ومن له ملفٌّ يُعيد صفَّه', some.rows[0].عدد === 1, `${some.rows[0].عدد}`)

console.log('\n=== التعديل ===')
const gov = await db.query(`select id, name from public.governorates order by sort_order limit 1`)
const saved = await as(UID,
  `select full_name, phone, governorate, avatar_path
     from public.api_update_profile($1, $2, $3, $4)`,
  ['أيمن الحاشدي', '771234567', gov.rows[0].id, `${UID}/avatar.jpg`])
ok('الاسم', saved.rows[0].full_name === 'أيمن الحاشدي')
ok('الجوال', saved.rows[0].phone === '771234567')
ok('واسمُ المحافظة يُشتقّ من معرّفها لا يُكتب باليد',
  saved.rows[0].governorate === gov.rows[0].name, saved.rows[0].governorate)
ok('ومسار الصورة', saved.rows[0].avatar_path === `${UID}/avatar.jpg`)

// من عدّل اسمه وحده لا يُفرَّغ جواله — وهذا ما يكسره `update` ساذج.
const partial = await as(UID,
  `select phone, avatar_path from public.api_update_profile('أيمن ح')`)
ok('تعديلٌ جزئيّ لا يمحو ما لم يُذكر',
  partial.rows[0].phone === '771234567' && partial.rows[0].avatar_path === `${UID}/avatar.jpg`)

console.log('\n=== ما لا يُعدَّل ===')
await mustFail('اسمٌ من حرف', () => as(UID, `select public.api_update_profile('أ')`))
await mustFail('اسمٌ فارغ', () => as(UID, `select public.api_update_profile('   ')`))
await mustFail('بلا جلسة', () => as(null, `select public.api_update_profile('اسم')`))
await mustFail('من لا ملفَّ له',
  () => as('33333333-3333-3333-3333-333333333333', `select public.api_update_profile('اسم')`))

// الحقول التي ليست في توقيع الدالة أصلاً — فلا سبيل إلى تمريرها.
const after = await db.query(
  `select status, email, auth_user_id from public.app_users where auth_user_id = $1`, [UID])
ok('الحالة لم تُمسّ', after.rows[0].status === 'active')
ok('والبريد لم يُمسّ', after.rows[0].email === 'user@aras.ye')
ok('وربطُ المصادقة لم يُمسّ', after.rows[0].auth_user_id === UID)

console.log('\n=== لا يعدّل أحدٌ ملفَّ غيره ===')
const OTHER = '44444444-4444-4444-4444-444444444444'
await db.exec(`
  insert into auth.users (id, email) values ('${OTHER}', 'other@aras.ye');
  insert into public.app_users (auth_user_id, full_name, email)
    values ('${OTHER}', 'آخر', 'other@aras.ye');
`)
await as(OTHER, `select public.api_update_profile('آخرُ عدّل نفسه')`)
const untouched = await db.query(
  `select full_name from public.app_users where auth_user_id = $1`, [UID])
ok('ملفّي لم يتغيّر بتعديل غيري', untouched.rows[0].full_name === 'أيمن ح')

if (fail) {
  console.log(`\n❌ ${fail} حالة فشلت.`)
  process.exit(1)
}
console.log('\n🎉 الملف الشخصي: يُقرأ ويُعدَّل، وما لا يُعدَّل محروس.')
