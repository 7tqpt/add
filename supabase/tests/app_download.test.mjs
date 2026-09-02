/**
 * رابطُ تنزيل النسخة: العمودُ وقيدُه.
 *
 * وأهمُّ ما يُقاس هنا ثلاثة:
 *
 *   ١. **أنّ القيدَ يردّ ما ليس https** — العمودُ يُقرأ في تطبيقٍ يفتح ما
 *      فيه، ورابطٌ بمخطّطٍ آخر بابٌ يُفتح على الجهاز بما لا يُقصد. والشاشةُ
 *      تُبدَّل وتُنسى، والقيدُ في القاعدة يبقى.
 *   ٢. **وأنّ الفارغَ يمرّ** — نسخةٌ قديمةٌ لم يُسجَّل لها رابطٌ لا تُمنع من
 *      البقاء، ويومَ التشغيل نفسِه تكون الصفوفُ كلُّها فارغةً.
 *   ٣. **وأنّ القراءةَ تبقى عامّة** — من لم يسجّل الدخول بعدُ قد يكون على
 *      نسخةٍ مكسورةٍ لا تُسجّله أصلاً، وهو أحوجُ الناس إلى أن يُقال له «حدّث».
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
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql']) {
  await db.exec(read(f))
}
const file = read('app_download.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond, extra = '') => {
  if (cond) console.log(`✅ ${label}`)
  else { console.log(`❌ ${label}${extra ? ` — ${extra}` : ''}`); fail++ }
}

let build = 9000
async function insert(url) {
  build++
  await db.query(
    `insert into public.app_versions (platform, version, build, download_url)
     values ('android', '9.9.9', $1, $2)`,
    [build, url],
  )
}
async function rejects(url) {
  try {
    await insert(url)
    return false
  } catch {
    return true
  }
}

// ── العمود ─────────────────────────────────────────────────────────────────

const cols = await db.query(
  `select column_name, is_nullable, column_default from information_schema.columns
   where table_schema='public' and table_name='app_versions' and column_name='download_url'`)
ok('العمودُ أُضيف', cols.rows.length === 1)
ok('ولا يقبل الفراغَ العدميّ (not null)', cols.rows[0]?.is_nullable === 'NO')
ok('وافتراضُه نصٌّ فارغ', String(cols.rows[0]?.column_default ?? '').includes("''"))

// ── القيد ──────────────────────────────────────────────────────────────────

ok('**والفارغُ يمرّ** — نسخةٌ بلا رابطٍ تبقى في الجدول',
   await insert('').then(() => true, () => false))

ok('وhttps يمرّ',
   await insert('https://sdd.company/farhati.apk').then(() => true, () => false))

ok('**وhttp يُردّ**', await rejects('http://sdd.company/farhati.apk'))
ok('**وjavascript: يُردّ**', await rejects('javascript:alert(1)'))
ok('**وfile: يُردّ**', await rejects('file:///data/app.apk'))
ok('**وintent: يُردّ**', await rejects('intent://scan/#Intent;end'))
ok('وmarket: يُردّ اليوم — ويُوسَّع عمداً إن أُريد',
   await rejects('market://details?id=company.sdd.farhati'))
ok('**وhttps في وسط النصّ لا في أوّله يُردّ**',
   await rejects('x https://sdd.company/a.apk'))

// ── القراءة ────────────────────────────────────────────────────────────────

const pol = await db.query(
  `select polname, polcmd, polroles::regrole[]::text[] as roles
   from pg_policy p join pg_class c on c.oid = p.polrelid
   where c.relname = 'app_versions'`)
const readPolicy = pol.rows.find(r => r.polname === 'versions_public_read')
ok('**وسياسةُ القراءة العامّة باقيةٌ لم يمسّها الملفّ**', Boolean(readPolicy))
ok('وتشمل anon — من لم يسجّل بعدُ يُقال له «حدّث»',
   String(readPolicy?.roles ?? '').includes('anon'))

const writePolicy = pol.rows.find(r => r.polname === 'versions_admin_write')
ok('والكتابةُ للإدارة وحدها', Boolean(writePolicy))
ok('ولا تشمل anon',
   !String(writePolicy?.roles ?? '').includes('anon'),
   String(writePolicy?.roles))

console.log(fail === 0 ? '\nكل اختبارات app_download.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
