/**
 * صورةُ القسم: العمودُ والسلّةُ وسياساتُها.
 *
 * وأهمُّ ما يُقاس هنا ثلاثة:
 *
 *   ١. **أنّ الصورةَ لا تُلغي الأيقونة** — العمودُ يقبل الفراغ، فمن شغّل
 *      الملفّ ولم يرفع شيئاً بعدُ لا تنكسر شاشتُه. وهذا هو الحالُ يومَ
 *      التشغيل نفسه، لا حالٌ نادرة.
 *   ٢. **وأنّ الرفعَ لأصحاب «الكتالوج» وحدهم** — من ملك صورةَ قسمٍ في الشاشة
 *      الأولى ملك واجهةَ التطبيق. والعميلُ المسجَّل ليس منهم.
 *   ٣. **وأنّ القراءةَ عامّة** — الشاشةُ الأولى تُرى بلا حساب.
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
// **وسلالٌ أخرى تُحمَّل عمداً** — الشعاراتُ ووسائطُ الخدمة — ليُقاس أنّ هذا
// الملفّ لا يُسقط سياساتِها وهو يمسّ `storage.objects` نفسَها.
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'profile.sql', 'service_media.sql']) {
  await db.exec(read(f))
}
const file = read('category_images.sql')
await db.exec(file)
await db.exec(file) // إعادة التشغيل لا تكسر شيئاً

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}
const rows = async (q, p) => (await db.query(q, p)).rows
const one = async (q, p) => (await rows(q, p))[0]

// ── ١. العمود ───────────────────────────────────────────────────────────────
const col = await one(`
  select data_type, is_nullable, column_default
    from information_schema.columns
   where table_schema = 'public' and table_name = 'service_categories'
     and column_name = 'image_path'`)
ok('عمودُ image_path أُضيف', col !== undefined)

// **والفراغُ هو الأصل** — ولو كان `not null` بلا مبدئيّ لَفشل الملفُّ على
// قاعدةٍ فيها أقسامٌ أصلاً، ولو قبل NULL لَاحتاجت كلُّ شاشةٍ فحصَ NULL.
ok('ومبدَؤه الفراغُ لا NULL',
   col?.is_nullable === 'NO' && /''/.test(col?.column_default ?? ''))

const blanks = await one(`
  select count(*)::int as ع from public.service_categories where image_path <> ''`)
ok('**والأقسامُ القائمةُ بقيت بلا صورة**', blanks.ع === 0,
   'وهي تعود إلى أيقونتها، فلا تنكسر الشاشة يومَ التشغيل')

const total = await one(`select count(*)::int as ع from public.service_categories`)
ok('تجهيزٌ: في القاعدة أقسامٌ فعلاً', total.ع > 0, `${total.ع} قسماً`)

// ── ٢. السلّة ───────────────────────────────────────────────────────────────
const bucket = await one(`
  select public, file_size_limit, allowed_mime_types
    from storage.buckets where id = 'category-images'`)
ok('السلّةُ أُنشئت', bucket !== undefined)
ok('**وقراءتُها عامّة**', bucket?.public === true,
   'الشاشةُ الأولى تُرى بلا حساب')
ok('وحدُّ الحجم نصفُ ميجابايت', Number(bucket?.file_size_limit) === 524288)
ok('ولا تقبل إلّا الصور',
   (bucket?.allowed_mime_types ?? []).every((t) => t.startsWith('image/')))

// ── ٣. **الكتابةُ لأصحاب «الكتالوج» وحدهم** ─────────────────────────────────
const policies = await rows(`
  select policyname, cmd, coalesce(qual, '') || coalesce(with_check, '') as body
    from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and (coalesce(qual,'') || coalesce(with_check,'')) like '%category-images%'`)

const byCmd = (c) => policies.filter((p) => p.cmd === c)
ok('تجهيزٌ: أربعُ سياساتٍ للسلّة', policies.length === 4, `${policies.length}`)

for (const cmd of ['INSERT', 'UPDATE', 'DELETE']) {
  const found = byCmd(cmd)
  ok(`و${cmd} مشروطةٌ بـcan_write_area('catalog')`,
     found.length === 1 && /can_write_area/.test(found[0].body) &&
     /catalog/.test(found[0].body))
}

// **ولا واحدةَ منها مفتوحةٌ لكلّ مسجَّل.** ولو سقط الشرطُ من إحداها لَاستطاع
// أيُّ عميلٍ أن يبدّل صورةَ قسمٍ في الشاشة الأولى — ولا شيءَ يمنعه.
const writes = policies.filter((p) => p.cmd !== 'SELECT')
ok('**ولا سياسةَ كتابةٍ بلا حارس**',
   writes.length === 3 && writes.every((p) => /can_write_area/.test(p.body)))

// والقراءةُ وحدها بلا شرطٍ — وهي المقصودة.
const reads = byCmd('SELECT')
ok('والقراءةُ للجميع بلا شرطِ دور',
   reads.length === 1 && !/can_write_area/.test(reads[0].body))

// ── ٤. ولا يكسر ما قبله ─────────────────────────────────────────────────────
//
// **وهذا يُنسى:** الملفُّ يمسّ `storage.objects` التي تحمل سياساتِ سلالٍ أخرى
// — الشعاراتِ ووسائطِ الخدمة. وسياسةٌ تُحذف باسمٍ مشترَكٍ تُسقط غيرَها صامتةً.
const survivors = (await rows(`
  select policyname from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and (coalesce(qual,'') || coalesce(with_check,'')) not like '%category-images%'`))
  .map((r) => r.policyname)

// وتُسمّى بأسمائها: عدٌّ مجرّدٌ يمرّ ولو بُدِّلت سياسةٌ بأخرى.
for (const name of ['anyone reads avatars', 'service media is public']) {
  ok(`وسياسةُ «${name}» باقية`, survivors.includes(name))
}
ok('وسياساتُ السلال الأخرى لم تُمسّ', survivors.length >= 6,
   `${survivors.length} باقية`)

await db.close()
console.log(fail === 0 ? '\nكل اختبارات category_images.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
