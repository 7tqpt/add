/**
 * غلافُ الملفّ الشخصيّ: العمودان، والدالّة، والطريقة العامّة.
 *
 * وأهمّ ما يُثبَت هنا أربعة:
 *
 *   ١. أنّ `install.sql` و`profile_cover.sql` **يتّفقان** — الأوّل لقاعدةٍ
 *      جديدة والثاني لقاعدةٍ قائمة. ولو افترقا لصار شكلُ الطريقة يتبع
 *      الترتيبَ الذي شُغِّلا به، وهو أسوأ من عطبٍ ظاهر.
 *
 *   ٢. **أنّ `api_update_profile` حِملٌ واحدٌ لا اثنان.** إضافةُ وسيطٍ خامسٍ
 *      بقيمةٍ افتراضيّة تُنشئ دالّةً ثانيةً باسمٍ واحد، فتبقى ذاتُ الأربعة
 *      إلى جانبها — وPostgREST حينئذٍ يردّ **كلَّ** نداءٍ بـ«لا يمكن اختيار
 *      الدالّة»، فيسقط حفظُ الاسم والجوال لكلّ مستخدم، لا حفظُ الغلاف وحدَه.
 *      وهذا أخطرُ ما في هذا الملفّ.
 *
 *   ٣. أنّ الغلافَ يُحفظ، **وأنّ حفظَ الاسم وحدَه لا يمحوه** — `coalesce`.
 *
 *   ٤. أنّ المزوّد يكتب غلافَه بنفسه وأنّ الحارسَ ما زال يمنعه من ترقية
 *      نفسه بالضغطة نفسها، وأنّ غيرَه لا يكتبه.
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
                 'invitations.sql', 'profile.sql']) {
  await db.exec(read(f))
}

const rows = async (q, p) => (await db.query(q, p)).rows

// ── ١. القاعدةُ الجديدة تحمل عمودَ المزوّد قبل أن يُشغَّل ملفُّ الترقيع ─────
const before = await rows(`
  select ordinal_position from information_schema.columns
   where table_schema='public' and table_name='v_providers' and column_name='cover_path'`)
if (before.length !== 1) {
  throw new Error('install.sql لا يعرض cover_path — افترق عن api.sql')
}
console.log('✅ **install.sql يعرض الغلافَ في الطريقة العامّة**')

// ── ٢. وملفُّ الترقيع يُعاد بلا ضرر، ولا يزحزح العمود ───────────────────────
const patch = read('profile_cover.sql')
await db.exec(patch)
await db.exec(patch)
console.log('✅ وملفُّ الترقيع آمنٌ عند التكرار')

const after = await rows(`
  select ordinal_position from information_schema.columns
   where table_schema='public' and table_name='v_providers' and column_name='cover_path'`)
if (after.length !== 1) throw new Error('الغلافُ سقط من الطريقة بعد الترقيع')

// **ولا يُقاس الموضعُ هنا كما في الشعار.** `profile_cover.sql` يبني الطريقةَ
// على شكل `nearby.sql` — بالنقطة والاسم البديل — وهو أوسعُ من شكل `api.sql`
// عن قصد: من شغّل `nearby.sql` ثمّ هذا الملفّ يجب ألّا يفقد «الأقرب إليّ».
// فيُقاس الوجودُ لا الترتيب.

// ── ٣. والعمودان كلاهما في الجدولين ─────────────────────────────────────────
for (const [table, label] of [['app_users', 'العميل'], ['service_providers', 'المزوّد']]) {
  const [col] = await rows(`
    select data_type, is_nullable, column_default from information_schema.columns
     where table_schema='public' and table_name=$1 and column_name='cover_path'`, [table])
  if (!col) throw new Error(`لا عمودَ غلافٍ في ${table}`)
  if (col.is_nullable !== 'NO') throw new Error(`غلافُ ${label} يقبل NULL`)
}
console.log('✅ والعمودان قائمان ولا يقبلان NULL')

// ── ٤. **والدالّةُ حِملٌ واحدٌ لا اثنان** ─────────────────────────────────────
const loads = await rows(`
  select pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'api_update_profile'`)
if (loads.length !== 1) {
  throw new Error(
    `api_update_profile لها ${loads.length} حِملاً: ` +
    loads.map((r) => `(${r.args})`).join(' و') +
    ' — وPostgREST يردّ كلَّ نداءٍ بـ«لا يمكن اختيار الدالّة»')
}
if (!loads[0].args.includes('p_cover_path')) {
  throw new Error('الحِملُ الباقي لا يعرف الغلاف')
}
console.log('✅ **والدالّةُ حِملٌ واحدٌ يعرف الغلاف** — لا حِملان متنازعان')

// ── ٥. والغلافُ يُحفظ، وحفظُ الاسم وحدَه لا يمحوه ───────────────────────────
const authUid = '11111111-1111-1111-1111-111111111111'
const [appUser] = await rows(`select id, full_name from public.app_users order by email limit 1`)
await db.exec(`
  insert into auth.users (id, email) values ('${authUid}', 'p@sdd.company')
    on conflict (id) do nothing;
  update public.app_users set auth_user_id = '${authUid}' where id = '${appUser.id}';`)

await db.exec(`set role authenticated`)
await db.exec(`select set_config('test.uid', '${authUid}', false)`)

await db.query(`select public.api_update_profile($1, null, null, null, $2)`,
  [appUser.full_name, `${authUid}/cover.jpg`])
let [me] = await rows(`select cover_path from public.app_users where id = $1`, [appUser.id])
if (me.cover_path !== `${authUid}/cover.jpg`) throw new Error('الغلافُ لم يُحفظ')
console.log('✅ والغلافُ يُحفظ')

// **ويُنادى بأربعةٍ كما ينادي التطبيقُ من لم يُبدّل غلافَه** — فلو سقطت
// القيمةُ الافتراضيّة لَمُحي الغلافُ في كلّ حفظِ اسم.
await db.query(`select public.api_update_profile($1)`, ['أيمن الحُميري'])
;[me] = await rows(`select cover_path, full_name from public.app_users where id = $1`, [appUser.id])
if (me.cover_path !== `${authUid}/cover.jpg`) {
  throw new Error('حفظُ الاسم وحدَه محا الغلاف — سقطت coalesce')
}
if (me.full_name !== 'أيمن الحُميري') throw new Error('الاسمُ لم يُحفظ')
console.log('✅ **وحفظُ الاسم وحدَه لا يمحو الغلاف**')

// ── ٦. والمزوّد يكتب غلافَه ولا يرقّي نفسه ──────────────────────────────────
// **ويُشترط أن يكون غيرَ «مميّز»** — للسبب المكتوب في `provider_logo.test.mjs`:
// الحارسُ يقارن `is distinct from`، فكتابةُ القيمة نفسِها لا ترفعه بحقّ.
await db.exec(`reset role`)
const [provider] = await rows(`
  select id from public.service_providers
   where status = 'verified' and is_featured = false order by id limit 1`)
if (!provider) throw new Error('البذرة بلا مزوّدٍ موثّقٍ غيرِ مميّز')
await db.exec(`
  update public.service_providers set user_id = '${appUser.id}' where id = '${provider.id}'`)

await db.exec(`set role authenticated`)
await db.exec(`select set_config('test.uid', '${authUid}', false)`)

await db.exec(`
  update public.service_providers
     set cover_path = '${authUid}/provider_cover.jpg'
   where id = '${provider.id}'`)

const [saved] = await rows(
  `select cover_path from public.v_providers where id = $1`, [provider.id])
if (!saved || !saved.cover_path.endsWith('/provider_cover.jpg')) {
  throw new Error('المزوّد لم يستطع كتابة غلافه — أو الطريقةُ لا تعرضه')
}
console.log('✅ **والمزوّد يكتب غلافَه ويُقرأ من الطريقة العامّة**')

let raised = false
try {
  await db.exec(`
    update public.service_providers set is_featured = true where id = '${provider.id}'`)
} catch (e) {
  raised = /إدارة المنصة/.test(e.message)
}
if (!raised) throw new Error('المزوّد رقّى نفسه إلى «مميّز» — الحارس سقط')
console.log('✅ ولا يرقّي نفسه بالضغطة نفسها — الحارس ارتفع')

// ── ٧. وغيرُه لا يكتب غلافَه ────────────────────────────────────────────────
const [other] = await rows(`
  select id, cover_path from public.service_providers where id <> $1 limit 1`, [provider.id])
await db.exec(`
  update public.service_providers set cover_path = 'دخيل' where id = '${other.id}'`)
const [untouched] = await rows(
  `select cover_path from public.service_providers where id = $1`, [other.id])
if (untouched.cover_path === 'دخيل') {
  throw new Error('مزوّدٌ كتب غلافَ غيره — سياسةُ providers_self_update سقطت')
}
console.log('✅ **وغيرُه لا يكتب غلافَه** — ولا رسالةَ خطأ: RLS تُسقط الصفَّ صامتةً')

// ── ٨. والسلّةُ عامّةٌ محدودةُ الحجم ────────────────────────────────────────
await db.exec(`reset role`)
const [bucket] = await rows(
  `select public, file_size_limit from storage.buckets where id='avatars'`)
if (!bucket || bucket.public !== true) throw new Error('سلّة avatars ناقصة')
if (Number(bucket.file_size_limit) !== 2097152) throw new Error('حدُّ الحجم تبدّل')
console.log('✅ والسلّةُ عامّةٌ بحدّ ٢ ميجابايت')

console.log('\n✅ غلافُ الملفّ الشخصيّ — كلُّ ما يُقاس أخضر')
