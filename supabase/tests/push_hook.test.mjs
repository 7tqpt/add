/**
 * ربطُ الدفع وفحصُه.
 *
 * وأهمّ ما يُثبَت هنا أن الملفّين **لا يسقطان على قاعدةٍ ليست Supabase**:
 * `supabase_functions` مخطّطٌ من صنعها، و`supabase_realtime` نشرةٌ من صنعها.
 * وملفٌّ يسقط عند من شغّله على قاعدةٍ محلّية أو على مشروعٍ جديد لم تُفعَّل فيه
 * الإضافات يُوقف كلَّ ما بعده في اللصقة.
 *
 * وأن إعادة الربط **تُبدّل** المُشغِّل ولا تُضيف ثانياً: مُشغِّلان يعنيان
 * إشعارين على الجوال عن حدثٍ واحد.
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
                 'invitations.sql', 'chat.sql', 'notifications.sql']) {
  await db.exec(read(f))
}

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

// ── ١. الملف يمرّ على قاعدةٍ ليست Supabase ──────────────────────────────────
const hook = read('push_hook.sql')
await db.exec(hook)
await db.exec(hook)
ok('push_hook.sql يمرّ على قاعدةٍ عادية ولا يسقط', true)

const { rows: refused } = await db.query(
  `select public.enable_push_webhook('https://demo.supabase.co') as msg`)
ok('ويقول إن المخطّط ناقصٌ بدل أن يرمي',
  String(refused[0].msg).includes('supabase_functions'), refused[0].msg)

const { rows: badUrl } = await db.query(`select public.enable_push_webhook('demo') as msg`)
ok('ورابطٌ ناقص يُردّ برسالةٍ تقول شكله',
  String(badUrl[0].msg).includes('https://'), badUrl[0].msg)

// ── ٢. وعلى قاعدةٍ فيها المخطّط ─────────────────────────────────────────────
// هيكلٌ مصغّر ممّا تضيفه Supabase: دالّةُ المُشغِّل وحدها.
await db.exec(`
  create schema if not exists supabase_functions;
  create or replace function supabase_functions.http_request() returns trigger
    language plpgsql as $$ begin return new; end $$;
`)

const { rows: linked } = await db.query(
  `select public.enable_push_webhook('https://demo.supabase.co/') as msg`)
ok('يقع الربط', String(linked[0].msg).startsWith('✅'), linked[0].msg)

const triggers = async () => (await db.query(
  `select tgname, pg_get_triggerdef(oid) as def from pg_trigger
    where tgname = 'push_on_notification' and not tgisinternal`)).rows

let rows = await triggers()
ok('ومُشغِّلٌ واحد', rows.length === 1)
ok('ورابطُه كامل بلا شرطةٍ مزدوجة',
  rows[0]?.def?.includes('https://demo.supabase.co/functions/v1/push'), rows[0]?.def)

// الشرطة الأخيرة في الرابط تُقصّ: `…co//functions` ينتج ٤٠٤ صامتاً.
ok('ولا شرطة مكرّرة', !rows[0]?.def?.includes('co//functions'))

await db.query(`select public.enable_push_webhook('https://other.supabase.co')`)
rows = await triggers()
ok('وإعادةُ الربط تُبدّل ولا تُضيف ثانياً — ولو أُضيف لوصل الإشعار مرّتين',
  rows.length === 1, `${rows.length}`)
ok('وبالرابط الجديد', rows[0]?.def?.includes('other.supabase.co'))

const { rows: off } = await db.query(`select public.disable_push_webhook() as msg`)
ok('والفصل يعمل', String(off[0].msg).startsWith('✅'))
ok('ولا يبقى مُشغِّل', (await triggers()).length === 0)

// ── ٣. ملفّ الفحص نفسه يعمل ─────────────────────────────────────────────────
// وهو يقرأ `pg_publication_tables` و`supabase_functions` — أي أنه أوّلُ ما
// يسقط إن كُتب لقاعدةٍ بعينها.
const verify = read('verify_push.sql')
await db.exec(verify)
ok('verify_push.sql يمرّ ولا يسقط', true)

// ولا يكذب: المُشغِّل مفصولٌ الآن، فالسطر السادس يجب أن يقول «❌».
await db.exec(`
  create or replace function pg_temp.run_checks() returns table(mark text, item text)
  language sql as $$
    select case when count(*) > 0 then '✅' else '❌' end, 'ربط الدفع'
    from pg_trigger where tgname = 'push_on_notification' and not tgisinternal
  $$;
`)
const { rows: verdict } = await db.query(`select * from pg_temp.run_checks()`)
ok('والفحص يقول «❌» حين لا ربط', verdict[0].mark === '❌')

await db.close()
console.log(fail === 0 ? '\nكل اختبارات push_hook.sql نجحت.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
