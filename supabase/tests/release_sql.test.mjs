/**
 * جملةُ `insert` التي يطبعها سيرُ البناء — تُنتزع من السير نفسِه وتُنفَّذ.
 *
 * ── ولماذا هذا الاختبار موجود ───────────────────────────────────────────────
 *
 * كتبتُ أوّلَ مرّة نسخةً بيدي من تلك الجملة وجرّبتُها على قاعدةٍ حقيقيّة،
 * فمرّت، فقلت «تحقّقتُ منها». **وكنتُ أجرّب نسخةً لا الأصل**: النسخةُ كتبتُ
 * فيها رقمَ البناء بيدي، والسيرُ كان يقرؤه من مكانٍ آخر يُخرج ‎٢٠٠٢‎ لا ‎٢‎ —
 * ولم يكن في تجربتي ما يكشف ذلك.
 *
 * فهذا يقرأ `apk.yml`، وينتزع سطورَ `echo` من خطوة النشر، ويشغّلها بصدفةٍ
 * حقيقيّة، ويأخذ ما بين علامتَي ```sql، ثمّ ينفّذه على القاعدة.
 *
 * وأهمُّ ما يقيسه: **أنّ الرقمَ المُدخل هو الذي يقارنه التطبيق** — رقمُ
 * `pubspec` لا `versionCode` الذي يزيده Flutter ألفاً لكلّ معماريّة.
 */
import { readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')
const repo = (f) => readFileSync(new URL(`../../${f}`, import.meta.url), 'utf8')

let fail = 0
const ok = (label, cond, extra = '') => {
  if (cond) console.log(`✅ ${label}`)
  else { console.log(`❌ ${label}${extra ? ` — ${extra}` : ''}`); fail++ }
}

// ── ١) تُنتزع سطورُ الطباعة من السير ───────────────────────────────────────

const yml = repo('.github/workflows/apk.yml')
const marker = 'echo "### أضِف النسخة إلى قاعدتك"'
const at = yml.indexOf(marker)
ok('**خطوةُ سطر الإدخال ما زالت في السير**', at >= 0)
if (at < 0) process.exit(1)

const tail = yml.slice(at)
const lines = []
for (const raw of tail.split('\n')) {
  const t = raw.trim()
  if (!t.startsWith('echo ')) break
  lines.push(t)
}
ok('وسطورُها تُقرأ', lines.length > 5, `${lines.length} سطراً`)

// ── ٢) تُشغَّل بصدفةٍ حقيقيّة — ومعها **الإسنادات** لا سطورُ الطباعة وحدها
//
// **وهذه هي الثغرةُ التي كشفها ضابطٌ سالبٌ لم يسقط.** أوّلُ نسخةٍ من هذا
// الاختبار كانت تضع `VCODE` و`ASSET` بيدها ثمّ تشغّل سطورَ `echo`. فلمّا
// أُعيد العيبُ عمداً — `VCODE=$APKCODE` بدل `$BUILD` — **مرّ الاختبار**:
// لأنّه لم يكن يقرأ الإسنادَ أصلاً، بل يحقنُ قيمتَه.
//
// فالعيبُ كان في الإسناد لا في القالب، والاختبارُ يقيس القالب. فصار
// الإسنادان يُنتزعان من السير ويُنفَّذان كما هما.

const pubspec = repo('mobile/pubspec.yaml')
const build = pubspec.match(/^version: .*\+(\d+)$/m)?.[1]
const name = pubspec.match(/^version: (.*)\+\d+$/m)?.[1]
ok('ورقمُ البناء يُقرأ من pubspec', Boolean(build), String(build))

/** ينتزع سطرَ إسنادٍ من السير بالاسم. */
function assignment(varName) {
  const re = new RegExp(`^\\s*${varName}=.*$`, 'm')
  const line = yml.match(re)?.[0]?.trim()
  ok(`وإسنادُ \`${varName}\` موجودٌ في السير`, Boolean(line), String(line))
  return line ?? ''
}

// (أ) رقمُ البناء — يُنفَّذ من جذر المستودع كما يفعل السير.
const buildLine = assignment('BUILD')
const derivedBuild = execFileSync('bash', ['-c', `${buildLine}\necho "$BUILD"`], {
  cwd: new URL('../../', import.meta.url).pathname,
  encoding: 'utf8',
}).trim()
ok('**والسيرُ يشتقُّ رقمَ البناء من pubspec لا من الحزمة**',
   derivedBuild === build, `اشتقّ ${derivedBuild} والمنتظَر ${build}`)

// (ب) وأنّ المُصدَّر هو المشتقُّ لا رقمُ الحزمة المزاح.
ok('**ويُصدّره هو — لا `APKCODE`**',
   /echo "VCODE=\$BUILD"/.test(yml) && !/echo "VCODE=\$APKCODE"/.test(yml))

// (ج) والرابط.
const assetLine = assignment('ASSET')
const asset = execFileSync('bash', ['-c', `${assetLine}\necho "$ASSET"`], {
  env: {
    ...process.env,
    GITHUB_SERVER_URL: 'https://github.com',
    GITHUB_REPOSITORY: '7tqpt/add',
    TAG: 'build-99',
    ARM64: 'dist/farhati-arm64.apk',
  },
  encoding: 'utf8',
}).trim()

const printed = execFileSync('bash', ['-c', lines.join('\n')], {
  env: { ...process.env, VNAME: name, VCODE: derivedBuild, ASSET: asset },
  encoding: 'utf8',
})

const sql = printed.split('```sql')[1]?.split('```')[0]?.trim()
ok('وتُخرج كتلةَ sql', Boolean(sql))
if (!sql) { console.log(printed); process.exit(1) }

// ── ٣) تُنفَّذ على القاعدة ──────────────────────────────────────────────────

const db = new PGlite()
await db.exec(`
  create schema if not exists auth;
  create table if not exists auth.users (id uuid primary key, email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('test.uid', true), '')::uuid $$;
  create role anon; create role authenticated;
`)
for (const f of ['install.sql', 'seed.sql', 'apply.sql', 'support.sql', 'roles.sql',
                 'app_download.sql']) {
  await db.exec(read(f))
}

let ran = true
try {
  await db.exec(sql)
} catch (e) {
  ran = false
  ok('**والجملةُ تُنفَّذ بلا خطأ**', false, String(e.message).split('\n')[0])
  console.log('\n' + sql + '\n')
}
if (ran) {
  ok('**والجملةُ تُنفَّذ بلا خطأ**', true)

  await db.exec(sql)   // إعادةُ اللصق بعد بناءٍ مُعاد

  // **ويُسأل عن الصفّ بعينه لا عن المنصّة كلِّها.** `seed.sql` يزرع نسخاً
  // تجريبيّةً لأندرويد، فسؤالٌ عامٌّ يعدّها معها — وقد عدّها أوّلَ مرّة
  // فخرج «٣ صفوف» و«الرقم ١٤٠٢»، وهو عيبٌ في السؤال لا في الجملة.
  const { rows } = await db.query(
    `select build, version, download_url from public.app_versions
     where platform = 'android' and build = $1`, [Number(build)])
  ok('وإعادتُها تُحدّث ولا تُكرّر الصفّ', rows.length === 1, `${rows.length} صفّاً`)

  // ── أهمُّ تأكيدٍ هنا ──────────────────────────────────────────────────────
  ok('**والرقمُ المُدخل هو رقمُ pubspec — لا versionCode المزاح**',
     String(rows[0]?.build) === build,
     `أُدخل ${rows[0]?.build} والمنتظَر ${build}`)
  ok('ورقمُه دون الألف — فالإزاحةُ لم تتسرّب',
     Number(rows[0]?.build) < 1000, String(rows[0]?.build))
  ok('والرابطُ رابطُ الأصل لا صفحةِ الإصدار',
     String(rows[0]?.download_url).includes('/releases/download/'),
     rows[0]?.download_url)
  ok('واسمُ النسخة يوافق pubspec', rows[0]?.version === name, rows[0]?.version)
}

// ── ٤) وثابتُ التطبيق هو رقمُ pubspec نفسُه ────────────────────────────────
//
// وهو المقارَنُ في `pickUpdate`. ويحرسه اختبارُ Flutter كذلك، ويُعاد هنا
// لأنّ هذه هي الحلقةُ التي انكسرت: السيرُ يُدخل رقماً والتطبيقُ يقارن بآخر.

const dart = repo('mobile/lib/src/core/app_version.dart')
const constant = dart.match(/const appBuild = (\d+);/)?.[1]
ok('**وثابتُ appBuild يساوي رقمَ pubspec**', constant === build,
   `الثابت ${constant} وpubspec ${build}`)

console.log(fail === 0
  ? '\nسطرُ الإدخال الذي يطبعه السيرُ صحيحٌ ويُنفَّذ.'
  : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
