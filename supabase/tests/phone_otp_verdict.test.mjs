/**
 * قرارُ قبول الرمز — `supabase/functions/phone-otp/verdict.mjs`.
 *
 * ── ولماذا هذا الملفُّ موجود ─────────────────────────────────────────────────
 *
 * كان السطرُ يسأل عن `verified` والمُرسِلُ يردّ `status`، **فكان يردّ كلَّ
 * رمزٍ صحيح** ويقول لصاحبه «الرمزُ غير صحيح أو انتهت مدّته» وهو يقرأ رمزَه
 * من واتساب ويكتبه حرفاً حرفاً. وبقي كذلك يومين.
 *
 * ولم يُمسكه اختبار، لأنّه كان سطراً بين نداءَي شبكةٍ في `index.ts` ولا
 * Deno في سير التكامل. فأُخرج القرارُ وحدَه، وصار يُقاس **بردٍّ حقيقيٍّ
 * منسوخٍ حرفاً بحرفٍ من سجلّ القاعدة الحيّة**:
 *
 *   رُدَّ الرمز: 200 {"status":true,"message":"OTP verified successfully"}
 *
 * ── والشكلان كلاهما مرصود ───────────────────────────────────────────────────
 *
 * كُتب هذا الملفُّ أوّلاً وشكلُ الرفض مجهول: وثائقُ المُرسِل محجوبةٌ عن آلة
 * البناء، ومثالُهم على GitHub يكتب `{ verified: true }` في تعليقٍ — وهو
 * أصلُ الغلط: نُسخ التعليقُ ولم يُقس الخادم. فكُتبت الحالاتُ السالبةُ
 * مفترَضةً، وقيل ذلك صراحةً.
 *
 * **ثمّ جرّب صاحبُ المنصّة رمزاً خاطئاً فظهر الشكلُ في سجلّه**، فحلَّ
 * المرصودُ محلَّ المفترَض:
 *
 *   قَبِل:  200 {"status":true,"message":"OTP verified successfully"}
 *   ردَّ:   422 {"status":false,"message":"Failed to verify OTP"}
 *
 * والرفضُ يأتي بسببين لا بسبب — حالةٌ ليست 2xx و`status: false` — وكلاهما
 * يُقاس، ولا يُترك أحدُهما لأنّ الآخر يكفي اليوم.
 */
import { readFileSync } from 'node:fs'
import { otpVerified, verifyGate } from '../functions/phone-otp/verdict.mjs'

let fail = 0
const ok = (label, cond) => {
  if (cond) console.log(`✅ ${label}`)
  else { console.log(`❌ ${label}`); fail++ }
}

// ── ١) الردُّ الحقيقيُّ المنسوخ من السجلّ ───────────────────────────────────
//
// **وهذا هو الحرزُ الذي لا يُفرَّط فيه.** لو عاد القرارُ يسأل عن `verified`
// وحدَه لسقط هذا السطرُ وحدَه — وهو العطبُ الذي وقع.
const live = '{"status":true,"message":"OTP verified successfully"}'
ok('**ردُّ الخادم الحيّ يُقبَل** — status: true', otpVerified(true, live))

// ── ٢) والاسمُ الآخرُ يُقبَل كذلك ───────────────────────────────────────────
// مثالُ المُرسِل يكتبه، فمن بدّل إليه غداً لم ينكسر شيء.
ok('و`verified: true` يُقبَل', otpVerified(true, '{"verified":true}'))

// ── ٣) وردُّ الرفض الحقيقيُّ المنسوخ من السجلّ ──────────────────────────────
const rejected = '{"status":false,"message":"Failed to verify OTP"}'
ok('**وردُّ الرفض الحيّ يُردّ** — 422 و status: false',
   !otpVerified(false, rejected))

// **ويُردّ بسببه الثاني وحدَه كذلك.** لو ردَّ المُرسِلُ غداً بـ200 وجسمٍ
// سالبٍ لَقُبِل لو كانت الحالةُ وحدَها هي المقياس.
ok('ويُردّ بجسمه وحدَه لو جاء بـ200', !otpVerified(true, rejected))

// ── ٤) وسالباتٌ أخرى ────────────────────────────────────────────────────────
//
// **وحالةُ HTTP تعلو على الجسم.** ‏٤٠٠ بجسمٍ موجبٍ ردٌّ لا قبول — وإلّا
// قُبِل ردُّ وسيطٍ يعيد صفحةً فيها الكلمةُ صدفةً.
ok('و٤٠٠ بجسمٍ موجبٍ يُردّ', !otpVerified(false, live))

ok('وردٌّ ليس JSON يُردّ', !otpVerified(true, '<html>502 Bad Gateway</html>'))
ok('وردٌّ فارغٌ يُردّ', !otpVerified(true, ''))
ok('وجسمٌ بلا إشارةٍ يُردّ', !otpVerified(true, '{}'))
ok('و`null` يُردّ', !otpVerified(true, 'null'))

// **و`=== true` لا صِدقاً عابراً.** ردٌّ تبدّل شكلُه يجب أن يُردّ ويُكتب في
// السجلّ، لا أن يُقرأ قبولاً بالمصادفة.
ok('ونصُّ "true" يُردّ', !otpVerified(true, '{"status":"true"}'))
ok('والعددُ ١ يُردّ', !otpVerified(true, '{"status":1}'))
ok('ومصفوفةٌ تُردّ', !otpVerified(true, '[true]'))

// ── ٥) وبابُ المحاولات يُغلق عند الشكّ ─────────────────────────────────────
//
// كان خطأُ دالّة الحدّ يُكتب ثمّ يُمضى بلا عدّ (فحصٌ أمنيّ): أيُّ عطبٍ فيها
// يفتح تخمينَ الرمز الرباعيّ كلِّه.
ok('**وخطأُ دالّة الحدّ يُغلق الباب** — لا يُمضى بلا عدّ',
   verifyGate({ message: 'function does not exist' }, null)?.status === 503)
ok('وصفٌّ غائبٌ بلا خطأ يُغلقه كذلك', verifyGate(null, null)?.status === 503)
ok('والسماحُ الصريحُ يمرّ', verifyGate(null, { allowed: true, reason: 'ok', wait_seconds: 0 }) === null)
ok('ونصُّ "true" لا يمرّ', verifyGate(null, { allowed: 'true' }) !== null)
const limited = verifyGate(null, { allowed: false, reason: 'attempt_limit', wait_seconds: 600 })
ok('والحدُّ يردّ بـ429 وسببِه', limited?.status === 429 && limited.reason === 'attempt_limit'
   && limited.wait === 600)

// **وتُقاس الشيفرةُ التي تناديه:** لا Deno في الحزمة فلا يُشغَّل `index.ts`،
// فيُسأل نصُّه أنّ قرارَ الباب قبل نداء المُرسِل وأنّه يعود إن أُغلق.
const index = readFileSync(new URL('../functions/phone-otp/index.ts', import.meta.url), 'utf8')
const gateAt = index.indexOf('const gate = verifyGate(claimError, claim)')
const sendAt = index.indexOf('`${AUTHENTICA}/verify-otp`')
ok('**و`index.ts` يسأل البابَ قبل المُرسِل، ويعود إن أُغلق**',
   gateAt > 0 && sendAt > gateAt
   && /if \(gate\) \{[\s\S]*?return json\(/.test(index.slice(gateAt, sendAt)))

console.log(fail === 0
  ? '\n✅ قرارُ قبول الرمز — كلُّ ما يُقاس أخضر'
  : `\n❌ ${fail} سقطت`)
process.exit(fail === 0 ? 0 : 1)
