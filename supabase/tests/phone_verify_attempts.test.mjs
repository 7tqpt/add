// `phone_verify_attempts.sql` قطعةٌ من `phone_verify.sql` — والملفّان لا يفترقان.
//
// ── ولماذا ملفّان أصلاً ────────────────────────────────────────────────────
//
// `phone_verify.sql` أربعُمئةٍ واثنان وثلاثون سطراً، ولصقُه في محرّر Supabase
// **انقطع في ثلثه** فخرج `$$` بلا غلق ورُدَّ الملفُّ كلُّه:
// `42601: unterminated dollar-quoted string`. فأُخرجت القطعةُ الجديدةُ وحدَها
// — مئةٌ وسبعةٌ وستّون سطراً تُلصَق في مرّة.
//
// ── وملفّان بالنصّ نفسِه يفترقان، وقد وقع ─────────────────────────────────
//
// **وهذا مقيسٌ لا متوقَّع**: حارسُ `v_admin_providers` كُتب في `apply.sql`
// و`provider_columns.sql` معاً، وضابطٌ سالبٌ كشف أنّ نسخةَ `apply.sql` لم
// تكن مقيسةً أصلاً — الملفُّ التالي يعيد تعريفَ الطريقة فيستر كسرَها.
//
// فلا يُترك هذان إلى النيّة: **يُقابَل نصُّ القطعة بنصّ أصلها حرفاً**. ومن
// عدّل الحدَّ في أحدهما ونسي الآخرَ وجد الحزمةَ حمراءَ في السطر نفسِه.
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

let fail = 0
const ok = (label, cond, extra = '') => {
  if (!cond) fail++
  console.log(`${cond ? '✅' : '❌'} ${label}${extra ? ' — ' + extra : ''}`)
}

const full = read('phone_verify.sql')
const part = read('phone_verify_attempts.sql')

// ── ١. القطعةُ داخلَ أصلها حرفاً ───────────────────────────────────────────
//
// ويُقتطع من القطعة رأسُها (تعليقُ الترويسة و`begin;`) وذيلُها (`commit;`)،
// ويبقى ما بينهما — وهو ما يجب أن يكون في الأصل كما هو.
const body = part
  .slice(part.indexOf('begin;') + 'begin;'.length, part.lastIndexOf('commit;'))
  .trim()

ok('القطعةُ ليست فارغة', body.length > 2000, `${body.length} حرفاً`)
ok('**ونصُّها في `phone_verify.sql` حرفاً**', full.includes(body),
   full.includes(body) ? '' : 'افترق الملفّان — عُدّل أحدُهما ونُسي الآخر')

// ── ٢. وما تُنشئه القطعةُ هو ما يُنشئه الأصل ──────────────────────────────
//
// **والنصُّ وحدَه لا يكفي**: سطرٌ زائدٌ خارج المقتطع في الأصل (منحٌ، أو
// مُشغِّل) لا يظهر في المقابلة أعلاه. فتُبنى قاعدتان وتُقابَل نتيجتاهما.
const build = async (files) => {
  const db = new PGlite()
  await db.exec(`
    create schema if not exists auth;
    create table if not exists auth.users (id uuid primary key, email text);
    create or replace function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('test.uid', true), '')::uuid $$;
    create role anon; create role authenticated;`)
  await db.exec(read('install.sql'))
  for (const f of files) await db.exec(read(f))
  return db
}

const shape = async (db) => ({
  // الدالّتان: نصُّ الجسم والصلاحيّات.
  functions: (await db.query(`
    select p.proname, p.prosrc, p.prosecdef,
           has_function_privilege('authenticated', p.oid, 'execute') as authed,
           has_function_privilege('anon', p.oid, 'execute') as anon
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname in ('otp_claim_verify', 'otp_clear_attempts')
     order by p.proname`)).rows,
  // والجدولُ: أعمدتُه وحرزُه وسياساتُه.
  columns: (await db.query(`
    select column_name, data_type from information_schema.columns
     where table_schema = 'public' and table_name = 'phone_otp_attempts'
     order by ordinal_position`)).rows,
  rls: (await db.query(`
    select relrowsecurity as on from pg_class k join pg_namespace n on n.oid = k.relnamespace
     where n.nspname = 'public' and k.relname = 'phone_otp_attempts'`)).rows,
  policies: (await db.query(`
    select policyname from pg_policies
     where schemaname = 'public' and tablename = 'phone_otp_attempts'`)).rows,
  indexes: (await db.query(`
    select indexname from pg_indexes
     where schemaname = 'public' and tablename = 'phone_otp_attempts'
     order by indexname`)).rows,
})

const a = await build(['phone_verify.sql'])
const b = await build(['phone_verify_attempts.sql'])
const [sa, sb] = [await shape(a), await shape(b)]

ok('الدالّتان موجودتان في الأصل', sa.functions.length === 2,
   sa.functions.map((f) => f.proname).join('، '))
ok('**وما تُنشئه القطعةُ هو ما يُنشئه الأصل**',
   JSON.stringify(sa) === JSON.stringify(sb))
ok('والجدولُ مفعَّلُ الحرزِ بلا سياسةٍ لأحد',
   sb.rls[0]?.on === true && sb.policies.length === 0)
ok('والدالّتان منزوعتان عن المسجَّل وعن الزائر',
   sb.functions.every((f) => f.authed === false && f.anon === false))

// ── ٣. والقطعةُ تعمل وحدَها ومرّتين ───────────────────────────────────────
await b.exec(read('phone_verify_attempts.sql'))
const twice = (await b.query(
  `select count(*)::int n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'otp_claim_verify'`)).rows[0].n
ok('إعادةُ التشغيل لا تكسر شيئاً', twice === 1)

// وتحدّ فعلاً — لا تُنشئ جدولاً وتسكت.
const U = '11111111-1111-1111-1111-111111111111'
await b.exec(`
  insert into auth.users (id, email) values ('${U}', 'a@sdd.company') on conflict do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status)
       values ('${U}', 'أيمن', 'a@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = '${U}';`)
const tries = []
for (let i = 0; i < 6; i++) {
  tries.push((await b.query(
    `select * from public.otp_claim_verify($1, $2)`, [U, '+967777654321'])).rows[0])
}
ok('الخمسُ الأُوَل تمرّ والسادسةُ تُردّ',
   tries.slice(0, 5).every((r) => r.allowed) && tries[5].allowed === false,
   tries[5].reason)

// ── ٤. والأجزاءُ الثلاثةُ تبني ما يبنيه الأصل ─────────────────────────────
//
// **واللصقُ انقطع مرّتين**: ٤٣٢ سطراً عند ١٥٠، ثمّ ١٧٢ سطراً عند ١٠٠ —
// في وسط `$$` في المرّتين، فرُدَّ الملفُّ كلُّه بـ`42601`. فقُسّمت القطعةُ
// ثلاثةً، أكبرُها تسعةٌ وسبعون سطراً.
//
// ولا يُقابَل نصُّها بالأصل حرفاً كما تُقابَل القطعةُ: **جسمُ الدالّة ضُغط
// بحذف أسطره الفارغة** ليقصر عن حدّ القطع. فيُوحَّد الفراغُ ثمّ يُقابَل —
// وهذا يكشف كلَّ تبديلٍ في الشيفرة، ولا يكشف فراغاً وحدَه.
const partNames = ['phone_otp_1.sql', 'phone_otp_2.sql', 'phone_otp_3.sql']
const parts = partNames.map(read)

/// شيفرةٌ بلا تعليقٍ ولا فراغٍ زائد.
const bare = (s) =>
  s
    .split('\n')
    .filter((l) => !l.trimStart().startsWith('--'))
    .join('\n')
    .replace(/\s+/g, ' ')
    .trim()

/// ما بين `begin;` و`commit;` — أي ما يُنشئ، دون ترويسةٍ ولا إيصال.
const between = (s) =>
  bare(s.slice(s.indexOf('begin;') + 'begin;'.length, s.lastIndexOf('commit;')))

// **ولا يُقابَل الترتيب**: كلُّ جزءٍ يحمل نزعَ صلاحيّةِ دالّتِه معه ليقوم
// وحدَه، والأصلُ يجمع النزعَين آخرَه. فتُقابَل الجملُ مجموعةً مرتَّبة —
// وهذا يكشف جملةً زائدةً أو ناقصةً أو مبدَّلةً، ولا يكشف موضعَها.
const statements = (s) => {
  const out = []
  let buf = ''
  let dollar = false
  for (let i = 0; i < s.length; i++) {
    if (s[i] === '$' && s[i + 1] === '$') { dollar = !dollar; buf += '$$'; i++; continue }
    if (s[i] === ';' && !dollar) { out.push(buf.trim()); buf = ''; continue }
    buf += s[i]
  }
  if (buf.trim()) out.push(buf.trim())
  return out.filter(Boolean).sort()
}

const mine = statements(parts.map(between).join(' '))
const theirs = statements(between(part))
const same = JSON.stringify(mine) === JSON.stringify(theirs)
ok('**والأجزاءُ الثلاثةُ مجموعةً هي القطعةُ نفسُها**', same,
   same ? `${mine.length} جملة` : 'افترق جزءٌ عن أصله')

// **وحدُّ الحجم ضمانةٌ لا زينة**: جزءٌ يتجاوز القطعَ الذي وقع يعود إلى
// العطب الذي قُسّم من أجله.
for (const [i, p] of parts.entries()) {
  const lines = p.trimEnd().split('\n').length
  const bytes = Buffer.byteLength(p, 'utf8')
  ok(`الجزء ${i + 1} يُلصق في مرّة`, lines <= 95 && bytes <= 4500,
     `${lines} سطراً · ${bytes} بايتاً`)
  // وإيصالٌ يُقرأ في «Results» — ومن انقطع لصقُه لم يره.
  ok(`وللجزء ${i + 1} إيصالٌ آخرَه`, /select '.+ ✓' as "تمّ";\s*$/.test(p))
}

const c = await build(partNames)
const sc = await shape(c)

// و`prosrc` يُقابَل بعد توحيد الفراغ للسبب نفسِه: جسمُ الدالّة في الجزء
// الثاني ضُغط بحذف أسطره الفارغة. **ولا حرفَ شيفرةٍ يفترق** — وهذا يُقاس.
const flat = (s) =>
  JSON.stringify(s, (k, v) =>
    k === 'prosrc' ? String(v).replace(/\s+/g, ' ').trim() : v)
ok('**وما تبنيه الأجزاءُ هو ما يبنيه الأصل**', flat(sa) === flat(sc))

// وتحدّ فعلاً — كما حُدَّ الأصل.
await c.exec(`
  insert into auth.users (id, email) values ('${U}', 'a@sdd.company') on conflict do nothing;
  insert into public.app_users (auth_user_id, full_name, email, status)
       values ('${U}', 'أيمن', 'a@sdd.company', 'active')
  on conflict (email) do update set auth_user_id = '${U}';`)
const cTries = []
for (let i = 0; i < 6; i++) {
  cTries.push((await c.query(
    `select * from public.otp_claim_verify($1, $2)`, [U, '+967777654321'])).rows[0])
}
ok('والأجزاءُ تحدّ كما يحدّ الأصل',
   cTries.slice(0, 5).every((r) => r.allowed) && cTries[5].allowed === false,
   cTries[5].reason)

await a.close()
await b.close()
await c.close()
console.log(fail === 0 ? '\n✅ كلّها' : `\n❌ سقط ${fail}`)
process.exit(fail === 0 ? 0 : 1)
