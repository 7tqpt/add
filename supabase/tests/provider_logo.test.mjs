/**
 * شعارُ مقدّم الخدمة: العمود، والطريقة العامة، ومن يملك الكتابة.
 *
 * وأهمّ ما يُثبَت هنا ثلاثة:
 *
 *   ١. أن `install.sql` و`provider_logo.sql` **يتّفقان**: الأوّل لقاعدةٍ جديدة
 *      والثاني لقاعدةٍ قائمة، فلو افترقا لصار شكلُ الطريقة يتبع الترتيب الذي
 *      شُغِّلا به — وهو أسوأ من عطبٍ ظاهر.
 *   ٢. أن المزوّد يكتب شعارَه بنفسه، وأن المُشغِّل ما زال يمنعه من ترقية نفسه
 *      بالضغطة نفسها.
 *   ٣. أن غيرَه لا يكتب شعارَه.
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

// ── ١. القاعدةُ الجديدة تحمل العمود قبل أن يُشغَّل ملفُّ الترقيع ─────────────
const before = await rows(`
  select ordinal_position from information_schema.columns
   where table_schema='public' and table_name='v_providers' and column_name='logo_path'`)
if (before.length !== 1) {
  throw new Error('install.sql لا يعرض logo_path — افترق عن api.sql')
}

// ── ٢. وملفُّ الترقيع لا يغيّر شيئاً في قاعدةٍ جديدة، ويُعاد بلا ضرر ─────────
const patch = read('provider_logo.sql')
await db.exec(patch)
await db.exec(patch)

const after = await rows(`
  select ordinal_position from information_schema.columns
   where table_schema='public' and table_name='v_providers' and column_name='logo_path'`)
if (after.length !== 1 || after[0].ordinal_position !== before[0].ordinal_position) {
  throw new Error(
    `موضعُ العمود اختلف بين install.sql وprovider_logo.sql: ` +
    `${before[0].ordinal_position} ثم ${after[0].ordinal_position}`,
  )
}

const bucket = await rows(`select public, file_size_limit from storage.buckets where id='avatars'`)
if (bucket.length !== 1 || bucket[0].public !== true) throw new Error('سلّة avatars ناقصة')

// ── ٣. المزوّد يكتب شعارَه ولا يرقّي نفسه ───────────────────────────────────
// البذرة لا تربط مزوّديها بحساباتِ مصادقة (‏`user_id` فارغ‏) — فيُربط واحدٌ
// هنا، إذ الحارس والسياسة كلاهما يمرّ بـ`auth.uid()`.
const [provider] = await rows(`
  select id from public.service_providers where status = 'verified' limit 1`)
if (!provider) throw new Error('البذرة بلا مزوّدٍ موثّق')

const authUid = '11111111-1111-1111-1111-111111111111'
const [appUser] = await rows(`select id from public.app_users limit 1`)
await db.exec(`
  insert into auth.users (id, email) values ('${authUid}', 'p@sdd.company')
    on conflict (id) do nothing;
  update public.app_users set auth_user_id = '${authUid}' where id = '${appUser.id}';
  update public.service_providers set user_id = '${appUser.id}' where id = '${provider.id}';`)
provider.auth_user_id = authUid

// `set local` بلا معاملةٍ لا أثر له، و`is_local = true` كذلك: PGlite
// تُنفّذ كل جملةٍ وحدها. فبقي الدور صاحبَ القاعدة وRLS لا تسري عليه —
// ومرّ اختبارُ الحراسة وهو لا يحرس شيئاً.
await db.exec(`set role authenticated`)
await db.exec(`select set_config('test.uid', '${provider.auth_user_id}', false)`)

await db.exec(`
  update public.service_providers
     set logo_path = '${provider.auth_user_id}/provider.jpg'
   where id = '${provider.id}'`)

const [saved] = await rows(
  `select logo_path from public.v_providers where id = $1`, [provider.id])
if (!saved || !saved.logo_path.endsWith('/provider.jpg')) {
  throw new Error('المزوّد لم يستطع كتابة شعاره')
}

let raised = false
try {
  await db.exec(`
    update public.service_providers set is_featured = true where id = '${provider.id}'`)
} catch (e) {
  raised = /إدارة المنصة/.test(e.message)
}
if (!raised) throw new Error('المزوّد رقّى نفسه إلى «مميّز» — الحارس سقط')

// ── ٤. وغيرُه لا يكتب شعارَه ─────────────────────────────────────────────────
const [other] = await rows(`
  select p.id from public.service_providers p where p.id <> $1 limit 1`, [provider.id])
await db.exec(`
  update public.service_providers set logo_path = 'دخيل' where id = '${other.id}'`)
const [untouched] = await rows(
  `select logo_path from public.service_providers where id = $1`, [other.id])
if (untouched.logo_path === 'دخيل') {
  throw new Error('مزوّدٌ كتب شعارَ مزوّدٍ آخر — سياسة RLS لا تحرس')
}

await db.exec(`reset role`)
await db.close()
console.log('✅ شعار المزوّد: العمود والطريقة والسياسة.')
