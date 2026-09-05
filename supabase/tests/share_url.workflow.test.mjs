/**
 * رابطُ الدعوة يُخبز في الحزمة — **يُنتزع من السير نفسِه ويُشغَّل**.
 *
 * ── ولماذا هذا الاختبار موجود ───────────────────────────────────────────────
 *
 * لأنّ الشيفرةَ في التطبيق لا تستطيع أن تقول إن كان `SHARE_URL` يصلها أصلاً.
 * `String.fromEnvironment('SHARE_URL')` تُعيد فارغاً في `flutter test` دائماً،
 * فاختبارُ دارت يمرّ سواءٌ أخبزه السيرُ أم لم يخبزه — **وهو بالضبط ما وقع مع
 * جملة الإصدار من قبل**: جُرّبت نسخةٌ مكتوبةٌ باليد فمرّت، والأصلُ في السير
 * كان يُخرج شيئاً آخر.
 *
 * فهذا يقرأ `apk.yml`، وينتزع خطوةَ «تهيئة مفاتيح المشروع» كما هي، ويشغّلها
 * بصدفةٍ حقيقيّة في الحالتين — بأسرارٍ وبلا أسرار — ثمّ يقرأ `env.json`
 * الخارجَ منها.
 *
 * وثلاثةٌ تُقاس:
 *   ١. أنّ `SHARE_URL` موجودٌ في الحالتين — والحالةُ بلا أسرارٍ هي الغالبة
 *      على من يبني لأوّل مرّة، وكانت تكتب `{}` فارغاً.
 *   ٢. أنّه `https://` — والقاعدةُ نفسُها التي يفرضها التطبيق، فلو خرج
 *      `http://` لَرُدّ في الجوال وخرجت الرسائلُ بلا رابطٍ وكأنّ شيئاً لم
 *      يُخبز.
 *   ٣. وأنّ المفاتيح لم تضِع بإضافته — وهي العلّةُ الأقربُ عند تبديل `printf`.
 */
import { readFileSync, mkdtempSync, writeFileSync, readFileSync as rf } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const repo = (f) => readFileSync(new URL(`../../${f}`, import.meta.url), 'utf8')

let fail = 0
const ok = (label, cond, extra = '') => {
  if (cond) console.log(`✅ ${label}`)
  else { console.log(`❌ ${label}${extra ? ` — ${extra}` : ''}`); fail++ }
}

// ── ١) تُنتزع الخطوةُ من السير ─────────────────────────────────────────────

const yml = repo('.github/workflows/apk.yml')
const marker = '      - name: تهيئة مفاتيح المشروع'
const at = yml.indexOf(marker)
ok('**خطوةُ تهيئة المفاتيح ما زالت في السير**', at >= 0)
if (at < 0) process.exit(1)

// جسمُ `run: |` — من بعد السطر إلى أوّل سطرٍ بمسافةٍ بادئةٍ أقلّ.
const tail = yml.slice(at)
const runAt = tail.indexOf('        run: |\n')
ok('وجسمُها `run: |` يُقرأ', runAt >= 0)
if (runAt < 0) process.exit(1)

const body = []
for (const raw of tail.slice(runAt + '        run: |\n'.length).split('\n')) {
  // نهايةُ الجسم: سطرٌ غيرُ فارغٍ لا يبدأ بعشر مسافات.
  if (raw.trim() !== '' && !raw.startsWith('          ')) break
  body.push(raw.replace(/^ {10}/, ''))
}
const script = body.join('\n')
ok('وفيه أسطرٌ تُشغَّل', script.split('\n').filter((l) => l.trim()).length > 4)

// ── ٢) تُشغَّل بصدفةٍ حقيقيّة في الحالتين ──────────────────────────────────

const run = (env) => {
  const dir = mkdtempSync(join(tmpdir(), 'shareurl-'))
  const file = join(dir, 'step.sh')
  // `$GITHUB_STEP_SUMMARY` يُكتب إليه في الخطوة، فيُوجَّه إلى ملفٍّ مؤقّت.
  writeFileSync(file, `set -eu\ncd "${dir}"\n${script}\n`)
  execFileSync('bash', [file], {
    env: {
      ...process.env,
      GITHUB_REPOSITORY: 'owner/repo',
      GITHUB_STEP_SUMMARY: join(dir, 'summary.md'),
      ...env,
    },
    stdio: 'pipe',
  })
  return JSON.parse(rf(join(dir, 'env.json'), 'utf8'))
}

const withSecrets = run({
  SUPABASE_URL: 'https://x.supabase.co',
  SUPABASE_ANON_KEY: 'sb_publishable_test',
})
const without = run({ SUPABASE_URL: '', SUPABASE_ANON_KEY: '' })

// ── ٣) ما يُقاس ────────────────────────────────────────────────────────────

const expected = 'https://github.com/owner/repo/releases/latest'

ok('**والرابطُ مخبوزٌ حين تُضبط الأسرار**',
  withSecrets.SHARE_URL === expected, JSON.stringify(withSecrets.SHARE_URL))

ok('**ومخبوزٌ حين لا تُضبط كذلك**',
  without.SHARE_URL === expected, JSON.stringify(without.SHARE_URL))

ok('وهو `https://` كما يشترط التطبيق',
  String(withSecrets.SHARE_URL).startsWith('https://'))

ok('ولا مسافةَ فيه — فالمسافةُ تقطع الرابط في واتساب',
  !String(withSecrets.SHARE_URL).includes(' '))

// **ولم تضِع المفاتيحُ بإضافته.**
ok('والمفاتيحُ تبقى كما كانت',
  withSecrets.SUPABASE_URL === 'https://x.supabase.co' &&
  withSecrets.SUPABASE_ANON_KEY === 'sb_publishable_test',
  JSON.stringify(withSecrets))

ok('وبلا أسرارٍ لا يُكتب مفتاحٌ فارغٌ يُظنّ مضبوطاً',
  without.SUPABASE_URL === undefined && without.SUPABASE_ANON_KEY === undefined,
  JSON.stringify(without))

// ── ٤) والتطبيقُ يقرؤه بهذا الاسم بعينه ───────────────────────────────────

const dart = repo('mobile/lib/src/core/share.dart')
ok("**والتطبيقُ يقرأ `SHARE_URL` بالاسم نفسِه**",
  dart.includes("String.fromEnvironment('SHARE_URL')"),
  'اسمٌ في السير واسمٌ في الشيفرة ⇐ رابطٌ لا يصل أبداً')

console.log(fail === 0 ? '\nكل الفحوص نجحت.' : `\n${fail} فحصاً سقط.`)
process.exit(fail === 0 ? 0 : 1)
