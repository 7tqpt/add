// ============================================================================
//  دالّة الحافة: تحويل صفّ `notifications` إلى إشعارٍ على الجوال
// ============================================================================
//
//  **متى تُستدعى:** من «Database Webhook» على `insert` في جدول
//  `public.notifications`. أي أن كل ما يكتب إشعاراً — وهي سبعةُ مواضع في
//  `api.sql` ومُشغِّلُ الرسالة في `notifications.sql` — يصل الجوال بلا أن
//  يعرف شيئاً عن FCM. ولو أُضيف حدثٌ ثامنٌ غداً وصل وحده.
//
//  **ولماذا خطّافٌ لا نداءٌ من القاعدة:** إرسال HTTP من داخل مُشغِّلٍ يعني
//  أن معاملة الحجز تنتظر شبكة Google. فإذا تأخّرت تأخّر الحجز، وإذا سقطت سقط
//  — أي أن عطباً في إشعارٍ يمنع بيعاً. والخطّاف يقع بعد الالتزام، خارجه.
//
//  **الأسرار — ولا واحد منها في المستودع:**
//    · `FCM_SERVICE_ACCOUNT` — محتوى ملف حساب الخدمة من Firebase، يُوضع في
//      أسرار المشروع (Edge Functions → Secrets). وهو مفتاحٌ خاصّ حقيقي:
//      من ملكه أرسل باسمك إلى كل من نصّب التطبيق.
//    · `SUPABASE_SERVICE_ROLE_KEY` و`SUPABASE_URL` — تضعهما Supabase في بيئة
//      الدالّة وحدها. ومفتاح الخدمة يتخطّى RLS، ولذلك يُقرأ به جدولُ الأجهزة:
//      الدالّة تُرسل نيابةً عن المنصّة لا عن مستخدم.
// ============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2'

interface NotificationRow {
  id: string
  user_id: string | null
  provider_id: string | null
  kind: string
  title: string
  body: string
  data: Record<string, unknown>
}

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'

// ── رمز الوصول إلى FCM ──────────────────────────────────────────────────────
//
// يُوقَّع محلّياً بمفتاح حساب الخدمة ثم يُبدَّل برمز وصول. والرمز صالحٌ ساعة،
// فيُخبَّأ: استدعاءٌ لـGoogle مع كل إشعارٍ يضاعف زمن الإرسال بلا سبب.
let cached: { token: string; expires: number } | null = null

async function accessToken(): Promise<string> {
  if (cached && cached.expires > Date.now() + 60_000) return cached.token

  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT')
  if (!raw) throw new Error('FCM_SERVICE_ACCOUNT غير مضبوط في أسرار المشروع.')
  const account = JSON.parse(raw) as { client_email: string; private_key: string }

  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claims = {
    iss: account.client_email,
    scope: FCM_SCOPE,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const encode = (value: unknown) =>
    btoa(JSON.stringify(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
  const unsigned = `${encode(header)}.${encode(claims)}`

  const pem = account.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0))
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const signed = `${unsigned}.${
    btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
  }`

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signed,
    }),
  })
  if (!response.ok) throw new Error(`فشل الحصول على رمز FCM: ${await response.text()}`)
  const token = await response.json() as { access_token: string; expires_in: number }
  cached = { token: token.access_token, expires: Date.now() + token.expires_in * 1000 }
  return cached.token
}

// ── الإرسال ─────────────────────────────────────────────────────────────────
Deno.serve(async (request) => {
  try {
    const payload = await request.json() as { record?: { id?: string }; type?: string }
    const id = payload.record?.id
    if (!id) return new Response('لا صفّ في الحمولة', { status: 400 })

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // **لا يُصدَّق ما في الحمولة إلّا المعرّف.** الدالّة منشورةٌ بلا تحقّقٍ من
    // الرمز — لأن المنادي مُشغِّلٌ لا مستخدمٌ يحمل جلسة — ورابطُ المشروع علنيّ.
    // فلو أُخذ العنوانُ والنصُّ من الجسد لأمكن لمن عرف الرابط أن يدفع إلى
    // جوال أيّ مستخدمٍ رسالةً باسم «فرحتي» يكتبها هو: «حوّل العربون إلى هذا
    // الرقم». فيُقرأ الصفُّ من القاعدة بمعرّفه، ويُرسَل ما فيها لا ما جاء.
    // وأقصى ما يبلغه المزوِّر حينئذٍ إعادةُ إشعارٍ حقيقيٍّ إلى صاحبه.
    const stored = await admin
      .from('notifications')
      .select('id, user_id, provider_id, kind, title, body, data')
      .eq('id', id)
      .maybeSingle()
    const row = stored.data as NotificationRow | null
    if (!row) return new Response('لا إشعار بهذا المعرّف', { status: 200 })

    // صاحبُ الإشعار إمّا مستخدمٌ أو مقدّم خدمة، والقيدُ في الجدول يضمن أنه
    // واحدٌ منهما لا الاثنان. ومقدّم الخدمة يُردّ إلى حساب مستخدمه لأن
    // الأجهزة معلّقةٌ على `app_users`.
    let owner = row.user_id
    if (!owner && row.provider_id) {
      const { data } = await admin
        .from('service_providers').select('user_id').eq('id', row.provider_id).maybeSingle()
      owner = data?.user_id ?? null
    }
    if (!owner) return new Response('لا صاحب للإشعار', { status: 200 })

    const { data: devices } = await admin
      .from('user_devices')
      .select('id, push_token')
      .eq('user_id', owner)
      .eq('push_enabled', true)
      .not('push_token', 'is', null)

    const tokens = (devices ?? []).map((d) => d.push_token as string)
    if (tokens.length === 0) return new Response('لا أجهزة', { status: 200 })

    const bearer = await accessToken()
    const projectId = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!).project_id as string

    // البيانات نصوصٌ كلُّها: FCM يرفض أي قيمةٍ غير نصّية في `data`، وهو رفضٌ
    // صامتٌ يظهر خطأً غامضاً وقت الإرسال.
    const data: Record<string, string> = { notification_id: row.id, kind: row.kind }
    for (const [key, value] of Object.entries(row.data ?? {})) {
      if (value !== null && value !== undefined) data[key] = String(value)
    }

    const dead: string[] = []
    await Promise.all(tokens.map(async (token) => {
      const send = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: row.title, body: row.body },
              data,
              android: { priority: 'HIGH', notification: { sound: 'default' } },
              apns: { payload: { aps: { sound: 'default' } } },
            },
          }),
        },
      )
      if (send.ok) return
      const text = await send.text()
      // رمزٌ ميّت — التطبيق أُزيل أو مُسحت بياناته. يُنظَّف وإلّا بقي يُرسَل
      // إليه إلى الأبد ويُحسب في الحصّة.
      if (send.status === 404 || text.includes('UNREGISTERED') || text.includes('INVALID_ARGUMENT')) {
        dead.push(token)
      }
      console.error('فشل إرسال إلى رمز:', send.status, text)
    }))

    if (dead.length > 0) {
      await admin.from('user_devices').update({ push_token: null }).in('push_token', dead)
    }

    return new Response(JSON.stringify({ sent: tokens.length - dead.length, dead: dead.length }), {
      headers: { 'content-type': 'application/json' },
    })
  } catch (error) {
    console.error(error)
    return new Response(String(error), { status: 500 })
  }
})
