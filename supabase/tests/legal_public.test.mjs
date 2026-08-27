/**
 * الصفحتان القانونيّتان **عامّتان** — ولا يكفي أن تكونا موجودتين.
 *
 * «جوجل بلاي» يشترط رابطاً عامّاً لسياسة الخصوصية يفتحه المراجِع بلا حساب.
 * فلو انزلقت الصفحةُ يوماً داخل `RequireAuth` — بنقلِ سطرٍ في `App.tsx` لا
 * أكثر — لَرأى المراجِعُ شاشةَ دخولٍ ورُدَّ التحديث، ولا شيء في البناء ولا في
 * المتصفّح يقول لماذا: الصفحةُ تعمل تماماً لمن هو مسجَّلٌ أصلاً، وأنت مسجَّل.
 *
 * **وهذا فحصُ بنيةٍ في المصدر لا فحصُ سلوك:** لا متصفّحَ هنا ولا خادم. يقرأ
 * `App.tsx` ويتأكّد أنّ مسارَي `/privacy` و`/terms` ليسا داخل كتلة
 * `<Route element={<RequireAuth />}>`. يمنع الانزلاق، ولا يُثبت أنّ الخادم
 * يخدمهما — ومن أراد ذلك فليفتح الرابط بنافذةٍ خفيّة بعد النشر.
 */
import { readFileSync } from 'node:fs'

const src = readFileSync(new URL('../../src/App.tsx', import.meta.url), 'utf8')

let fail = 0
const ok = (label, cond) => {
  console.log(`${cond ? '✅' : '❌'} ${label}`)
  if (!cond) fail++
}

// حدودُ الكتلة المحروسة: من سطر `<Route element={<RequireAuth />}>` إلى سطر
// إغلاقها.
//
// **وانكسر عدّان قبل هذا، وكلاهما بالخطأ نفسه:** وسمُ الحراسة يحمل في جوفه
// وسماً مغلقاً على نفسه — `<Route element={<RequireAuth />}>` — فكلُّ فحصٍ
// يسأل «أفيه `/>`؟» أو «أين أوّلُ `>`؟» يقع على الداخليّ لا على الخارجيّ،
// فيُقرأ وسمُ الحراسة مغلقاً ولا تُفتح كتلةٌ أصلاً. والسؤالُ الصحيح: أ**ينتهي
// السطر** بـ`/>`؟
//
// والعدُّ بالأسطر لا بالمحارف — وفي هذا الملفّ وسمٌ واحدٌ في كل سطر.
function guardedRange(text) {
  const lines = text.split('\n')
  const start = lines.findIndex((line) => line.includes('<Route element={<RequireAuth />}>'))
  if (start === -1) return null

  let depth = 0
  for (let i = start; i < lines.length; i++) {
    const line = lines[i]
    // وسمٌ مغلقٌ على نفسه (`<Route … />`) لا يفتح كتلة.
    if (line.includes('<Route') && !line.trimEnd().endsWith('/>')) depth++
    if (line.includes('</Route>')) {
      depth--
      if (depth === 0) return lines.slice(start, i + 1).join('\n')
    }
  }
  return null
}

const guarded = guardedRange(src)
ok('كتلةُ `RequireAuth` موجودةٌ ومحدودة', guarded !== null)

if (guarded) {
  for (const path of ['/privacy', '/terms']) {
    const marker = `path="${path}"`
    ok(`مسارُ ${path} معرَّفٌ في التوجيه`, src.includes(marker))
    ok(`**ومسارُ ${path} خارج تسجيل الدخول**`, !guarded.includes(marker))
  }

  // ضابطُ عيارٍ في الاختبار نفسه: مسارٌ نعرف أنّه محروسٌ **يجب** أن يُرى
  // داخل الكتلة. ولولاه لَمرّ هذا الملفُّ كلُّه لو أخطأ `guardedRange` فأعاد
  // نصّاً فارغاً — فيقول «كلُّ المسارات خارج الحراسة» وهي كلُّها داخلها.
  ok('والحسّاب مضبوط: `/settings` داخل الكتلة',
     guarded.includes('path="/settings"'))
}

console.log(fail === 0 ? '\nالصفحتان القانونيّتان عامّتان.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
