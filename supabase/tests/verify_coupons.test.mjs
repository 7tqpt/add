/**
 * فحصُ الكوبونات: يُصدِّق حين تكتمل القاعدة، **ويُكذِّب حين تنقص**.
 *
 * والثاني هو المقصود. فحصٌ يقول «✅» في الحالين ورقةٌ تُطمئن ولا تدلّ — وهو
 * أسوأُ من ألّا يكون هناك فحص، لأنّ صاحبه يمضي واثقاً.
 *
 * فيُشغَّل على قاعدتين: واحدةٌ شُغِّل عليها `coupons.sql` وأخرى لم يُشغَّل،
 * ويُشترط أن تكون الأولى عشرَ علاماتِ صحّةٍ والثانيةُ عشرَ علاماتِ نقص.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')
const BOOT = `
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
`

async function boot({ withCoupons }) {
  const db = new PGlite()
  await db.exec(BOOT)
  for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                   'availability.sql', 'settlements.sql']) {
    await db.exec(read(f))
  }
  if (withCoupons) await db.exec(read('coupons.sql'))
  return db
}

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}

// الفحصُ ملفٌّ فيه استعلامان: جدولُ الأحكام ثمّ ملحقُ الأكواد. ويُفصلان هنا
// لأن `db.query` تنفّذ واحداً، والملحقُ يقرأ `v_coupons` فلا وجود له في
// القاعدة الناقصة.
const [verdicts, appendix] = read('verify_coupons.sql')
  .split('-- ملحق: أكوادُك وحصادُها')

const rowsOf = async (db) => (await db.query(verdicts)).rows

// ── القاعدةُ الكاملة: كلُّ بندٍ ✅ ────────────────────────────────────────────
const full = await boot({ withCoupons: true })
const good = await rowsOf(full)

ok('الفحصُ يعرض عشرة بنود', good.length === 10)
for (const row of good) {
  ok(`✔ ${row.البند}`, row.الحكم === '✅')
}
// ولا سطرَ خطوةٍ يُعرض حين يكون البند سليماً.
ok('ولا خطوةَ تُطلب ممّا هو سليم',
   good.every((r) => r['ما تفعله'] === '—'))

// والملحقُ يعمل ولا يسقط على قاعدةٍ بلا أكواد — والفراغُ ليس عطباً.
const empty = await full.query(appendix.split('\n').slice(5).join('\n'))
ok('وملحقُ الأكواد يعمل على قاعدةٍ فارغة', empty.rows.length === 0)

await full.exec(`
  insert into public.coupons (code, description, kind, value, ends_at)
       values ('EID25', 'حملة العيد', 'percent', 25, now() + interval '20 days')`)
const listed = await full.query(appendix.split('\n').slice(5).join('\n'))
ok('ويعرض الكودَ بعد إنشائه',
   listed.rows.length === 1 && listed.rows[0].الكود === 'EID25')
ok('ويقول إنّه سارٍ', listed.rows[0].الحال === 'سارٍ')

await full.close()

// ── القاعدةُ الناقصة: كلُّ بندٍ ❌ ومعه خطوته ────────────────────────────────
//
// **وهذا ضبطُ عيار الفحص نفسه.** ولولاه لَما عرفنا أنّ بنداً منها يسأل عن
// شيءٍ موجودٍ أصلاً في `install.sql` فيقول «✅» ولو لم يُشغَّل الملفّ قطّ.
const bare = await boot({ withCoupons: false })
const bad = await rowsOf(bare)

ok('وعلى قاعدةٍ لم يُشغَّل عليها الملفُّ: عشرة بنود', bad.length === 10)
for (const row of bad) {
  ok(`✘ ${row.البند}`, row.الحكم === '❌')
}
ok('ولكلِّ ناقصٍ خطوةٌ مكتوبة',
   bad.every((r) => typeof r['ما تفعله'] === 'string' && r['ما تفعله'] !== '—'))

await bare.close()

console.log(fail === 0
  ? '\nالفحص يُصدِّق حين تكتمل القاعدة ويُكذِّب حين تنقص.'
  : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
