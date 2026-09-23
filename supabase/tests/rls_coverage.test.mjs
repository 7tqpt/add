// **كلُّ جدولٍ في `public` محميٌّ، وله سياسةٌ واحدةٌ على الأقلّ.**
//
// ── لماذا هذا الملفّ ─────────────────────────────────────────────────────────
//
// التطبيقان يتّصلان بالقاعدة مباشرةً بالمفتاح العامّ. **فالحرزُ الوحيدُ بين
// أيّ زائرٍ في الدنيا وبين جدولٍ في `public` هو RLS.** وجدولٌ خرج بلا حمايةٍ
// يُقرأ ويُكتب من غير حساب.
//
// وتُفعَّل الحمايةُ في هذا المشروع **بقائمةٍ مكتوبةٍ باليد** في `schema.sql`،
// وبأسطرٍ متفرّقةٍ في ملفّات المزايا. **ومن أضاف جدولاً ونسي السطرَ خرج
// جدولُه مكشوفاً ولم يحمرّ شيء** — لم يكن في الحزمة كلِّها ما يسأل «أكلُّ
// جدولٍ محميّ؟».
//
// **ولا تُقرأ ملفّاتُ SQL بالعين ولا بتعبيرٍ نمطيّ:** يُبنى المخطَّطُ في
// Postgres حقيقيّ ثمّ يُسأل `pg_class` — فالمقيسُ ما تنتجه القاعدةُ فعلاً بعد
// تنفيذ الملفّات بترتيبها، لا ما نظنّه مكتوباً فيها.
//
// ── وحمايةٌ بلا سياسةٍ ليست حمايةً بل قفلاً ─────────────────────────────────
//
// جدولٌ عليه RLS ولا سياسةَ له يردّ الجميعَ — وهو أسلمُ من الانكشاف، لكنّه
// عطبٌ صامتٌ من نوعٍ آخر: ميزةٌ تقف ولا يُعرف لماذا. فيُقاس الاثنان.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const read = (f) => fs.readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

// ما توفّره Supabase ولا يوجد في Postgres عارياً.
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role anon; create role authenticated; create role service_role;`)

// وهيكلٌ مصغَّرٌ من مخطَّط التخزين — PGlite لا تحمل ما تضيفه Supabase،
// و`storage.sql` يكتب عليه.
await db.exec(`
  create schema storage;
  create table storage.buckets (
    id text primary key, name text not null, public boolean not null default false,
    file_size_limit bigint, allowed_mime_types text[]
  );
  create table storage.objects (
    id uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id), name text not null, owner uuid
  );
  alter table storage.objects enable row level security;
  create function storage.foldername(name text) returns text[]
    language sql immutable as $$ select string_to_array(name, '/') $$;
`)

// **والقائمةُ هي قائمةُ الإصدار نفسُها** — ما يُطبَّق على القاعدة الحيّة.
const FILES = ['install.sql', 'seed.sql', 'apply.sql', 'storage.sql',
               'support.sql', 'roles.sql', 'invitations.sql']
for (const f of FILES) await db.exec(read(f))

const { rows } = await db.query(`
  select c.relname as name,
         c.relrowsecurity as rls,
         (select count(*) from pg_policy p where p.polrelid = c.oid)::int as policies
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
   order by c.relname`)

assert.ok(rows.length > 30, `جداولُ public ${rows.length} — المخطَّطُ لم يُبنَ`)

const unprotected = rows.filter((r) => !r.rls).map((r) => r.name)
assert.deepEqual(unprotected, [],
  `جداولٌ بلا حماية — يقرؤها ويكتب فيها أيُّ زائرٍ بلا حساب:\n  ${unprotected.join('\n  ')}`)

const lockedOut = rows.filter((r) => r.rls && r.policies === 0).map((r) => r.name)
assert.deepEqual(lockedOut, [],
  `جداولٌ محميّةٌ بلا سياسةٍ واحدة — تردّ الجميعَ فتقف ميزةٌ بلا سبب:\n  ${lockedOut.join('\n  ')}`)

console.log(`✓ ${rows.length} جدولاً في public: كلُّها محميّةٌ ولكلٍّ سياسة`)

// ── وطرقُ العرض تُسأل كذلك ──────────────────────────────────────────────────
//
// طريقةُ عرضٍ بلا `security_invoker` تعمل بصلاحيات مالكها فتلتفّ حول RLS كلِّها
// — وهي البابُ الخلفيّ الوحيدُ الذي يُبطل ما فوقه. و`views.rls.test.mjs` تسأل
// عن سبعٍ بأسمائها؛ **وهذه تسأل عن كلّ ما يُبنى، فلا تنجو واحدةٌ تُضاف غداً.**
//
// ── واستثناءٌ بشرطٍ لا استثناءٌ باسم ────────────────────────────────────────
//
// `v_admin_providers` صارت بصلاحية مالكها **عمداً**: بعد نزع أعمدة البريد
// والأرباح عن `authenticated` في `provider_columns.sql`، طريقةٌ تتبع صلاحيةَ
// سائلها تخرج للمسؤول نفسِه بأعمدةٍ فارغة.
//
// **ولا تُستثنى باسمها.** قائمةُ أسماءٍ تكبر بلا حساب، ومن أضاف اسمَه إليها
// أسكت الحارسَ عنه. فالشرطُ: طريقةٌ بصلاحية مالكها تُقبل **إن حملت حارسَها
// في نصِّها** — `is_admin()` أو `current_app_user()` أو `current_provider()`.
// وطريقةٌ بلا حارسٍ تحمّر ولو سُمّيت `v_admin_*`.
const GUARDS = ['is_admin()', 'current_app_user()', 'current_provider()']

const { rows: definer } = await db.query(`
  select c.relname as name, pg_get_viewdef(c.oid) as body from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'v'
     and coalesce((select option_value from pg_options_to_table(c.reloptions)
                    where option_name = 'security_invoker'), 'false') <> 'true'
   order by c.relname`)

const unguarded = definer
  .filter((v) => !GUARDS.some((g) => v.body.includes(g)))
  .map((v) => v.name)

assert.deepEqual(unguarded, [],
  `طرقُ عرضٍ تعمل بصلاحيات مالكها بلا حارسٍ في نصِّها، فتلتفّ حول RLS:\n  ${unguarded.join('\n  ')}`)

console.log(definer.length === 0
  ? '✓ ولا طريقةَ عرضٍ تلتفّ حول الحماية'
  : `✓ ولا طريقةَ عرضٍ تلتفّ حول الحماية (وبصلاحية مالكها بحارسها: ${definer.map((v) => v.name).join('، ')})`)
