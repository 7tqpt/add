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
  // **و«طلب حذف الحساب» ثالثتُهنّ**: من أراد حذف حسابه قد لا يستطيع الدخول
  // أصلاً — ولو كانت خلف البوّابة لَما وصل إليها من يحتاجها.
  for (const path of ['/privacy', '/terms', '/delete-account']) {
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

// ── وعناوينُ البريد موجودةٌ فعلاً ──────────────────────────────────────────
//
// **ورابطٌ إلى بريدٍ لا وجود له أسوأُ من ألّا يكون هناك رابط:** يراه المراجِع
// فيظنّ للمنصّة قناةَ تواصل، ويكتب إليها المستخدمُ في أمر بياناته فترتدّ
// رسالتُه. وصندوقان فقط قائمان اليوم، فهذا يمنع دخولَ ثالثٍ لم يُنشأ.
const legal = readFileSync(new URL('../../src/pages/Legal.tsx', import.meta.url), 'utf8')
const MAILBOXES = ['info@sdd.company', 'support@sdd.company']

const used = [...legal.matchAll(/mailto:([^"']+)/g)].map((m) => m[1])
// **ولا يُعدّ عددُها بل تُفحص كلُّها.** كان الشرط «اثنان» فسقط حين أُضيفت
// صفحةٌ ثالثة — وهو عدٌّ لا فحص: ثلاثةُ عناوينَ صحيحةٍ خيرٌ من اثنين، وعنوانان
// أحدهما مخترَعٌ شرٌّ من ثلاثةٍ صحيحة.
ok('في الصفحات عناوينُ بريد', used.length >= 2, `${used.length}`)
for (const address of used) {
  ok(`و«${address}» صندوقٌ قائم`, MAILBOXES.includes(address))
}
// وكلُّ عنوانٍ يُذكر في النصّ هو عنوانٌ يُرسَل إليه — لا نصٌّ يخالف رابطَه.
for (const address of MAILBOXES) {
  if (!used.includes(address)) continue
  ok(`و«${address}» مكتوبٌ كما هو في النصّ`,
     legal.split(address).length - 1 >= 2)
}

// ── **ما يفتحه التطبيق هو ما يخدمه الموقع** ─────────────────────────────────
//
// **وهذا الفحصُ وُلد من رابطٍ ميّتٍ شُحن فعلاً.** كان التطبيق يفتح
// `sdd.company/privacy`، واللوحةُ تُنشر بـ`HashRouter` — فالعنوان الحقيقيّ
// `sdd.company/#/privacy`. والرابطُ بلا `#` يفتح الموقعَ على صفحة الدخول لا
// على السياسة: لا خطأً يظهر، ولا صفحةَ «غير موجود» — شيءٌ آخر يُعرض فحسب،
// وهو أخبثُ من العطل الصريح.
//
// والحارسُ الذي كان هنا يقيس أنّ المسارين **خارج الحراسة**، وذلك صحيحٌ وباقٍ
// — لكنّه لا يقول شيئاً عن شكل العنوان. فيُقرأ نوعُ الموجّه من `main.tsx`
// ويُقارَن بما يكتبه التطبيق.
const mainSrc = readFileSync(new URL('../../src/main.tsx', import.meta.url), 'utf8')
const isHashRouter = /<HashRouter>/.test(mainSrc)
const appSettings = readFileSync(
  new URL('../../mobile/lib/src/screens/account_extras.dart', import.meta.url), 'utf8')
const appLinks = [...appSettings.matchAll(/'(https:\/\/sdd\.company[^']*)'/g)].map((m) => m[1])

ok('تجهيزٌ: التطبيق يحمل روابط الموقع', appLinks.length >= 2,
   appLinks.join(' | '))
for (const needed of ['/privacy', '/terms', '/delete-account']) {
  ok(`ورابطُ ${needed} في التطبيق`,
     appLinks.some((l) => l.endsWith(needed)))
}
ok('تجهيزٌ: اللوحة تُنشر بموجّه الـhash', isHashRouter)

if (isHashRouter) {
  for (const link of appLinks) {
    ok(`و«${link}» فيه #`, link.includes('/#/'))
  }
} else {
  for (const link of appLinks) {
    ok(`و«${link}» بلا # — والموجّه ليس hash`, !link.includes('/#/'))
  }
}

// وكلُّ رابطٍ يشير إلى مسارٍ موجودٍ في `App.tsx` فعلاً — لا إلى اسمٍ مخترَع.
for (const link of appLinks) {
  const path = '/' + link.split('/').pop()
  ok(`و«${path}» مسارٌ مسجَّلٌ في اللوحة`,
     new RegExp(`path="${path}"`).test(src))
}

// ── سياسةُ الخصوصيّة تطابق ما يطلبه التطبيق فعلاً ───────────────────────────
//
// **وهذا الفحصُ وُلد من كذبةٍ كادت تُنشر.** كانت السياسة تقول نصّاً «ولا نقرأ
// موقع جهازك — التطبيق لا يطلب إذن الموقع أصلاً»، وهو صدقٌ يومَ كُتب. ثمّ
// أُضيف زرُّ «موقعي الحالي» وإذنُ الموقع في بيان أندرويد، فصارت الجملةُ
// كاذبةً في **وثيقةٍ قانونيّة** — ولا بناءَ يكسر ولا اختبارَ يوقظ.
//
// و«جوجل بلاي» يقارن الأذونات المعلنة بما تقوله السياسة، ورفضُ التحديث لهذا
// السبب معروف.
//
// فيُقرأ بيانُ أندرويد نفسه: إن كان فيه إذنُ موقعٍ وجب أن تفصح السياسة، وحرُم
// أن تنفي.
const manifest = readFileSync(
  new URL('../../mobile/android/app/src/main/AndroidManifest.xml', import.meta.url),
  'utf8')
const asksLocation = /ACCESS_(FINE|COARSE)_LOCATION/.test(manifest)

ok('تجهيزٌ: البيانُ يطلب إذن الموقع', asksLocation)

if (asksLocation) {
  ok('**والسياسةُ تفصح عن قراءة الموقع**',
     /موقع جهازك/.test(legal) && /موقعي الحالي/.test(legal))
  // والنفيُ الصريح محرَّم: هو الجملةُ التي كانت.
  ok('**ولا تنفي أنّها تطلب الإذن**',
     !/لا يطلب إذن الموقع/.test(legal) && !/لا نقرأ موقع جهازك/.test(legal))
  // ويُقال إنّه لا تتبّع — وهو ما يسأل عنه المراجِع بعد أن يرى الإذن.
  ok('وتقول إنّها لا تتتبّع في الخلفيّة',
     /الخلفية|الخلفيّة/.test(legal) && /نتتبّعك|سجلُّ مواقع|سجل مواقع/.test(legal))
}

// وiOS يرفض التطبيق من غير سطرِ سببٍ في `Info.plist` — والرفضُ عند الرفع لا
// عند البناء، فيُقاس هنا.
const plist = readFileSync(
  new URL('../../mobile/ios/Runner/Info.plist', import.meta.url), 'utf8')
if (asksLocation) {
  ok('وفي Info.plist سببُ استعمال الموقع',
     /NSLocationWhenInUseUsageDescription/.test(plist))
}

// ── صفحةُ حذف الحساب تقول ما يُحذف وما يبقى ─────────────────────────────────
//
// **وهذا حارسٌ انتقل ولم يُحذف.** كان في `account_extras_test.dart` يقيس أنّ
// نافذة التأكيد تقول ما سيضيع قبل الضغط لا بعده. ثمّ أُزيل الزرُّ بقرار صاحب
// المنتج وصار الطريقُ صفحةً على الموقع — فالشرطُ باقٍ ومكانُه تبدّل.
//
// ومن حذف حارساً لأنّ شاشتَه تبدّلت يفقد الشرطَ نفسه معها.
ok('وصفحةُ الحذف تقول ما يُحذف',
   /خطة عرسك/.test(legal) && /عناوينك المحفوظة/.test(legal))
ok('**وتقول ما يبقى ولماذا**',
   /سجلّات حجوزاتك/.test(legal) && /بلا اسمك/.test(legal),
   'فلا يظنّ أنّه يمحو أثره كلَّه')
ok('وتقول إنّ الحجزَ القائم يمنع الحذف', /حجزٌ قائم/.test(legal))
ok('وتقول كيف يُرسَل الطلب من البريد المسجَّل',
   /البريد المسجَّل/.test(legal) && /support@sdd\.company/.test(legal))

console.log(fail === 0 ? '\nالصفحتان القانونيّتان عامّتان.' : `\n${fail} فشل.`)
process.exit(fail === 0 ? 0 : 1)
