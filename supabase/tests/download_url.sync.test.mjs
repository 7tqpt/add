/**
 * قاعدةُ رابط التنزيل مكتوبةٌ **ثلاثَ مرّات**، ولكلٍّ سببُها:
 *
 *   • في `app_download.sql` — قيدُ `check`، وهو الحارسُ الأخير: يمنع الصفَّ
 *     من الدخول أصلاً ولو كُتب بيدٍ في محرّر SQL.
 *   • في `src/services/versions.ts` — لتقول اللوحةُ للمسؤول ما العيبُ قبل
 *     أن يُرسل، بدل أن يرتدّ عليه خطأُ قاعدةٍ لا يفهمه.
 *   • في `mobile/lib/src/core/app_update.dart` — لأنّ التطبيق قد يقرأ من
 *     قاعدةٍ لم يُشغَّل عليها الملفُّ بعد، فلا قيدَ فيها يحميه.
 *
 * والتكرارُ مقصود، وخطرُه أن يتباعد الثلاثة. **وأخطرُ اتّجاهٍ للتباعد أن
 * تتساهل القاعدةُ ويتشدّد الطرفان**: عندها يدخل `javascript:` إلى الجدول
 * ويبقى راقداً حتى يقرأه تطبيقٌ أقدمُ لا يفحص.
 *
 * فهذا الاختبار يبني القاعدةَ الحقيقيّة، ويسأل الثلاثةَ عن الروابط نفسِها،
 * ويقارن الأجوبة.
 */
import { readFileSync } from 'node:fs'
import { PGlite } from '@electric-sql/pglite'

const read = (f) => readFileSync(new URL(`../${f}`, import.meta.url), 'utf8')

// كلُّ ما يخطر ببالِ من يلصق رابطاً في حقل — ونيّةً سيّئةً كذلك.
const CASES = [
  ['', true],
  ['https://sdd.company/a.apk', true],
  ['https://github.com/7tqpt/add/releases/download/build-56/x.apk', true],
  ['http://sdd.company/a.apk', false],
  ['javascript:alert(1)', false],
  ['file:///data/a.apk', false],
  ['intent://scan/#Intent;end', false],
  ['market://details?id=x', false],
  ['ftp://sdd.company/a.apk', false],
  ['sdd.company/a.apk', false],
  [' https://sdd.company/a.apk', false],
  ['x https://sdd.company/a.apk', false],
  ['HTTPS://sdd.company/a.apk', false],
]

// ── ١) القاعدة ─────────────────────────────────────────────────────────────

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

let build = 5000
async function sqlAccepts(url) {
  build++
  try {
    await db.query(
      `insert into public.app_versions (platform, version, build, download_url)
       values ('android', '0.0.0', $1, $2)`,
      [build, url],
    )
    return true
  } catch {
    return false
  }
}

// ── ٢) اللوحة ──────────────────────────────────────────────────────────────
//
// تُقرأ الدالّةُ من مصدرها وتُنفَّذ، فلا تُنسخ قاعدتُها هنا نسخاً ثانياً
// يتباعد هو الآخر.

const tsSource = readFileSync(
  new URL('../../src/services/versions.ts', import.meta.url), 'utf8')
// **وتُقصّ بموازنة الأقواس لا بأوّل `\n}`.** الدالّةُ فيها `try`/`catch`،
// فأوّلُ قوسٍ مغلقٍ في أوّل عمودٍ هو قوسُ `try` لا قوسُ الدالّة — وقد قُصّت
// كذلك أوّلَ مرّةٍ فخرجت شيفرةٌ لا تُترجَم.
function bodyOf(source, signature) {
  const at = source.indexOf(signature)
  if (at < 0) throw new Error(`لم تُوجد: ${signature}`)
  const open = source.indexOf('{', at)
  let depth = 0
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++
    else if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i)
  }
  throw new Error('قوسٌ لم يُغلق')
}

const tsBody = bodyOf(tsSource, 'export function isDownloadUrlValid')
  .replaceAll(': string', '')
const dashboardAccepts = new Function('url', tsBody)

// ── ٣) التطبيق ─────────────────────────────────────────────────────────────
//
// وقاعدتُه تُقرأ من مصدر Dart بالنصّ لا تُنفَّذ — ولا مفسّرَ Dart هنا.
// فيُتحقّق أنّ السطرين اللذين يحملانها لم يتبدّلا: تبديلُهما يُسقط هذا
// الاختبارَ فيُعاد النظرُ في الثلاثة معاً.

const dart = readFileSync(
  new URL('../../mobile/lib/src/core/app_update.dart', import.meta.url), 'utf8')

let fail = 0
const ok = (label, cond, extra = '') => {
  if (cond) console.log(`✅ ${label}`)
  else { console.log(`❌ ${label}${extra ? ` — ${extra}` : ''}`); fail++ }
}

for (const [url, expected] of CASES) {
  const shown = url === '' ? '(فارغ)' : url
  const sql = await sqlAccepts(url)
  const dash = dashboardAccepts(url)
  ok(`القاعدة ${expected ? 'تقبل' : 'تردّ'}: ${shown}`, sql === expected)
  ok(`واللوحة توافقها: ${shown}`, dash === sql, `اللوحة=${dash} القاعدة=${sql}`)
}

// **والفارغُ حالةٌ خاصّةٌ متعمَّدة في الطرفين ومختلفةٌ في الثالث:** القاعدةُ
// واللوحةُ تقبلانه (نسخةٌ لم يُسجَّل رابطُها بعد)، والتطبيقُ يردّه (لا
// يُعرض على أحد). وهذا ليس تباعداً بل تقسيمُ عمل — ويُقال هنا لئلّا يُظنّ
// عيباً فيُصلَح فيصير عيباً.
ok('**والتطبيق يشترط https في أوّل الرابط**',
   dart.includes("url.startsWith('https://')"))
ok('ويشترط مضيفاً غير فارغ',
   dart.includes('Uri.tryParse(url)?.host.isNotEmpty'))
ok('ويردّ الفارغ — فلا يُعرض إصدارٌ بلا رابطٍ على أحد',
   dart.includes("if (!url.startsWith('https://')) return false;"))

console.log(fail === 0
  ? '\nالثلاثةُ متّفقون على قاعدة الرابط.'
  : `\n${fail} فشل — تباعدت المواضع.`)
process.exit(fail === 0 ? 0 : 1)
