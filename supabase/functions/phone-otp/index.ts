// ============================================================================
//  دالّة الحافة: تحقّقُ رقم الجوال برمزٍ على واتساب
// ============================================================================
//
//  **ولماذا دالّةٌ ولا نداءٌ من التطبيق مباشرةً:** مفتاحُ المُرسِل
//  (Authentica) يُرسِل على **رصيدٍ مدفوعٍ** لصاحب المنصّة. وحزمةُ أندرويد
//  تُفكّ ويُستخرج ما فيها في دقائق — فمفتاحٌ في التطبيق مفتاحٌ في يد كلّ من
//  نزّله، يُرسل به حتى ينفد الرصيد فتتوقّف المنصّةُ عن تسجيل أحد.
//
//  فالمفتاحُ هنا وحدَه، والتطبيقُ ينادي هذه الدالّةَ برمز جلسته.
//
//  **الأسرار — ولا واحدٌ منها في المستودع:**
//    · `AUTHENTICA_API_KEY` — مفتاحُ التطبيق من لوحة Authentica. يوضع في
//      Edge Functions → Secrets. **وهو مالٌ لا كلمةُ مرور**: من ملكه أنفق
//      رصيدَك.
//    · `AUTHENTICA_TEMPLATE_ID` — **اختياريٌّ في الشيفرة، ولعلّه لازمٌ عند
//      المُرسِل.** وثيقتُهم تقول: «كلُّ قالبٍ مخصَّصٌ لقناةٍ بعينها، وطريقةُ
//      الإرسال يجب أن توافق قناةَ القالب» — فقالبُ واتساب غيرُ قالب الرسالة
//      النصّيّة. وحين يُضبط هذا السرُّ يُرسَل `template_id` في الطلب، وحين
//      لا يُضبط يُترك للمُرسِل أن يختار قالبَه الافتراضيّ.
//
//      **ولا يُخبَز في الشيفرة:** الأرقامُ تخصّ حساباً بعينه، وتبديلُها في
//      الشيفرة يعني نشرَ دالّةٍ من جديد.
//    · `SUPABASE_SERVICE_ROLE_KEY` و`SUPABASE_URL` — تضعهما Supabase في بيئة
//      الدالّة. ومفتاحُ الخدمة يتخطّى الحرز، وبه تُنادى دالّتا الحدّ
//      والإثبات — وهما منزوعتا الصلاحيّة عن المسجَّلين قصداً.
//
//  **فعلان في مسارٍ واحد:** `POST` مع `{ action: 'send' | 'verify', ... }`.
//  ولا ثالث. ودالّتان منفصلتان تعنيان سرَّين يُضبطان ونشرَين يُنسى أحدُهما.
//
//  ── وما تفعله بالترتيب ─────────────────────────────────────────────────────
//
//  send:   يُعرَف صاحبُ الجلسة → يُطالَب بالحدّ في القاعدة (وهو يُسجّل
//          الإرسالَ في العمليّة نفسِها) → يُطلب الإرسالُ من المُرسِل.
//  verify: يُعرَف صاحبُ الجلسة → يُسأل المُرسِلُ عن الرمز → إن صحّ كُتب
//          الإثباتُ في القاعدة.
//
//  **والرمزُ لا يمرّ بقاعدتنا ولا يُخزَّن فيها**: المُرسِلُ يُنشئه ويتحقّق
//  منه. ورمزٌ لا يُخزَّن لا يُسرَّب.
// ============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2'

const AUTHENTICA = 'https://api.authentica.sa/api/v2'

/// ما يُقال لصاحب الجهاز عن كلّ ردٍّ من دالّة الحدّ.
///
/// **ولا يُعاد رمزُ السبب كما هو.** «hour_limit» لا تعني شيئاً لمن يقف أمام
/// الشاشة، والشاشةُ لا تُترجم رموزاً — فالنصُّ يُبنى هنا حيث يُعرف السياق.
function limitMessage(reason: string, wait: number): string {
  switch (reason) {
    case 'cooldown':
      return `انتظر ${wait} ثانية قبل طلب رمزٍ جديد.`
    case 'hour_limit':
      return 'طلبتَ ثلاثة رموزٍ في ساعة. انتظر قليلاً ثمّ أعد المحاولة.'
    case 'day_limit':
      return 'طلبتَ رموزاً كثيرةً اليوم. حاول غداً أو راسل الدعم.'
    case 'already_verified':
      return 'رقمك مؤكَّدٌ أصلاً.'
    case 'no_phone':
      return 'اكتب رقم جوالك أوّلاً.'
    case 'no_profile':
      return 'أكمل ملفك أوّلاً.'
    default:
      return 'تعذّر إرسال الرمز. أعد المحاولة.'
  }
}

/// رقمٌ بصيغة E.164 كما يطلبه المُرسِل: `+967…` بلا فراغاتٍ ولا شُرَط.
///
/// **ويُطهَّر هنا لا في الشاشة وحدها.** الشاشةُ تُساعد، والخادمُ يَحكم: رقمٌ
/// فيه فراغٌ يُرسَل ويُردّ برسالةٍ غامضةٍ من المُرسِل، ورقمٌ محلّيٌّ بلا مفتاح
/// دولةٍ يذهب إلى بلدٍ آخر.
///
/// واليمنُ `+967` والرقمُ المحلّيُّ تسعُ خاناتٍ يبدأ بـ`7`، وقد يُكتب
/// بصفرٍ سابقٍ (`07…`) — فيُسقط.
function normalisePhone(raw: string): string | null {
  let s = String(raw ?? '')
    .replace(/[\s\-()]/g, '')
    // **والأرقامُ العربيّةُ تُبدَّل.** من كتب رقمَه بلوحةٍ عربيّةٍ أخرج
    // «٧٧٠…» — وهي أرقامٌ لا يفهمها المُرسِل، ولا فرقَ عند صاحبها.
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06F0))

  if (s.startsWith('00')) s = `+${s.slice(2)}`
  if (!s.startsWith('+')) {
    if (s.startsWith('967')) s = `+${s}`
    else if (s.startsWith('0')) s = `+967${s.slice(1)}`
    else s = `+967${s}`
  }
  return /^\+\d{8,15}$/.test(s) ? s : null
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  })
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'POST فقط' }, 405)

  try {
    const key = Deno.env.get('AUTHENTICA_API_KEY')
    if (!key) {
      // **ويُقال صراحةً لا يُصمت.** بلا هذا يرى صاحبُ الجهاز «تعذّر الإرسال»
      // ويبحث في جواله، والعلّةُ سرٌّ لم يوضع في المشروع.
      console.error('AUTHENTICA_API_KEY غير مضبوط في أسرار المشروع.')
      return json({ error: 'خدمةُ الرسائل غير مهيّأة بعد. راسل الدعم.' }, 503)
    }

    const jwt = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '')
    if (!jwt) return json({ error: 'لا جلسة.' }, 401)

    const url = Deno.env.get('SUPABASE_URL')!
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    // **وصاحبُ الجلسة يُعرَف من الرمز لا من جسم الطلب.** لو أُخذ المعرّفُ
    // ممّا يرسله التطبيقُ لَأكّد كلُّ مستخدمٍ رقمَ من شاء.
    const { data: claims, error: authError } = await admin.auth.getUser(jwt)
    const authUser = claims?.user?.id
    if (authError || !authUser) return json({ error: 'جلسةٌ غير صالحة.' }, 401)

    const body = await request.json().catch(() => ({})) as {
      action?: string
      phone?: string
      otp?: string
    }

    const phone = normalisePhone(body.phone ?? '')
    if (!phone) return json({ error: 'رقمُ الجوال غيرُ صالح.' }, 400)

    // ── إرسال ───────────────────────────────────────────────────────────────
    if (body.action === 'send') {
      const { data: claim, error } = await admin
        .rpc('otp_claim_send', { p_auth_user: authUser, p_phone: phone })
        .single()

      if (error) {
        console.error('otp_claim_send:', error)
        return json({ error: 'تعذّر طلب الرمز. أعد المحاولة.' }, 500)
      }

      const row = claim as { allowed: boolean; reason: string; wait_seconds: number }
      if (!row.allowed) {
        return json(
          { error: limitMessage(row.reason, row.wait_seconds), reason: row.reason },
          429,
        )
      }

      // **ورقمُ القالب نصٌّ أو عدد؟** وثيقتُهم تكتبه عدداً (`31`) في المثال،
      // والسرُّ يأتي نصّاً أبداً — فيُحوَّل، وإن لم يكن رقماً أُرسل كما هو
      // ولم يُبتَر الطلبُ لأجل ذلك.
      const templateRaw = Deno.env.get('AUTHENTICA_TEMPLATE_ID')?.trim()
      const templateId = templateRaw
        ? (Number.isFinite(Number(templateRaw)) ? Number(templateRaw) : templateRaw)
        : undefined

      const sent = await fetch(`${AUTHENTICA}/send-otp`, {
        method: 'POST',
        headers: {
          'X-Authorization': key,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          method: 'whatsapp',
          phone,
          ...(templateId === undefined ? {} : { template_id: templateId }),
        }),
      })

      if (!sent.ok) {
        const text = await sent.text()
        // **ويُكتب في السجلّ ولا يُعاد إلى الجهاز.** ردُّ المُرسِل قد يحمل
        // تفصيلاً عن الحساب والرصيد، ولا شأن لصاحب الجهاز به.
        console.error('فشل إرسال الرمز:', sent.status, text)
        return json({ error: 'تعذّر إرسال الرمز الآن. أعد المحاولة بعد قليل.' }, 502)
      }

      return json({ sent: true })
    }

    // ── تحقّق ──────────────────────────────────────────────────────────────
    if (body.action === 'verify') {
      const otp = String(body.otp ?? '').trim()
      if (!/^\d{4,8}$/.test(otp)) return json({ error: 'اكتب الرمز كما وصلك.' }, 400)

      const checked = await fetch(`${AUTHENTICA}/verify-otp`, {
        method: 'POST',
        headers: {
          'X-Authorization': key,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ phone, otp }),
      })

      const result = await checked.json().catch(() => ({})) as { verified?: boolean }
      if (!checked.ok || result.verified !== true) {
        // **ولا يُفرَّق بين «رمزٌ خاطئ» و«رمزٌ انتهى» في الرسالة.** الفرقُ
        // يفيد من يجرّب الرموزَ أكثرَ ممّا يفيد صاحبَها.
        return json({ verified: false, error: 'الرمزُ غير صحيح أو انتهت مدّته.' }, 400)
      }

      const { error } = await admin.rpc('otp_mark_verified', {
        p_auth_user: authUser,
        p_phone: phone,
      })
      if (error) {
        // **وهذه الحالةُ تُقال ولا تُخفى:** الرمزُ صحيحٌ والرصيدُ أُنفق،
        // والكتابةُ سقطت. فلو قيل «الرمزُ خاطئ» لَأعاد صاحبُه الطلبَ فأنفق
        // رسالةً أخرى على عطبٍ ليس فيه.
        console.error('otp_mark_verified:', error)
        return json({ error: 'تحقّقنا من الرمز ولم نتمكّن من حفظه. راسل الدعم.' }, 500)
      }

      return json({ verified: true })
    }

    return json({ error: 'فعلٌ غير معروف.' }, 400)
  } catch (error) {
    console.error(error)
    return json({ error: 'عطبٌ غير متوقّع.' }, 500)
  }
})
