# تشغيل إشعارات الجوال

الإشعارات **داخل التطبيق** تعمل بلا أي من هذا: الجرس في أعلى الشاشة، وصندوقٌ
يمتلئ من سبعة أحداث، وحبّةٌ تتحدّث مباشرةً بالبثّ. وهذه الخطوات لِما يصل
الجوال **وهو مغلق**.

## ما تحتاجه منك

خمس خطوات، مرّةً واحدة.

### ١. مشروع Firebase

من [console.firebase.google.com](https://console.firebase.google.com) أنشئ
مشروعاً، ثم أضف تطبيق أندرويد باسم الحزمة **`ye.aras.aras`** (هو ما في
`android/app/build.gradle.kts`، وأي اسمٍ غيره لا يصل إليه إشعار).

نزّل `google-services.json` وضعه في:

```
mobile/android/app/google-services.json
```

الملف **متروكٌ خارج المستودع** (‏`.gitignore`‏) — وهو تهيئةُ عميلٍ لا سرّاً،
لكنه ملكُ مشروعك. وحتى يوضع، تُبنى الحزمة كما هي ويبقى الدفع مطفأً بلا خطأ:
إضافة Google Services لا تُطبَّق إلّا إن وُجد الملف.

### ٢. حساب خدمة

في Firebase: **Project settings → Service accounts → Generate new private key**.
ينزّل ملف JSON.

> ⚠️ **هذا مفتاحٌ خاصٌّ حقيقي**، بخلاف مفتاح Supabase العلني. من ملكه أرسل
> باسمك إلى كل من نصّب التطبيق. لا يُوضع في المستودع، ولا في `env.json`، ولا
> يُرسَل في محادثة. موضعه الوحيد هو الخطوة التالية.

### ٣. السرّ في Supabase

لوحة Supabase → **Edge Functions → Secrets**:

| الاسم | القيمة |
| --- | --- |
| `FCM_SERVICE_ACCOUNT` | محتوى ملف الخطوة ٢ كاملاً (الصق الـJSON كما هو) |

`SUPABASE_URL` و`SUPABASE_SERVICE_ROLE_KEY` تضعهما Supabase وحدها، لا تضفهما.

### ٤. نشر الدالّة

```bash
supabase functions deploy push --no-verify-jwt
```

`--no-verify-jwt` لأن المستدعي خطّافُ قاعدة البيانات لا مستخدم.

### ٥. الخطّاف

لوحة Supabase → **Database → Webhooks → Create a new hook**:

| الحقل | القيمة |
| --- | --- |
| Table | `public.notifications` |
| Events | `Insert` |
| Type | Supabase Edge Functions |
| Edge Function | `push` |

## كيف يعمل

```
حجزٌ يُقبل  ──►  api_respond_to_booking()
رسالةٌ تصل  ──►  مُشغِّل notify_conversation_message()
                          │
                          ▼
                 صفٌّ في public.notifications
                          │  (خطّاف قاعدة البيانات)
                          ▼
                   دالّة الحافة push
                          │  (FCM v1)
                          ▼
                    جوال صاحب الشأن
```

ولا شيء في التطبيق ولا في `api.sql` يعرف عن FCM شيئاً. فأيُّ حدثٍ يُضاف غداً
ويكتب إشعاراً يصل الجوال وحده.

### ولماذا خطّافٌ لا نداءٌ من داخل المُشغِّل

نداءُ HTTP من داخل مُشغِّلٍ يجعل معاملة الحجز تنتظر شبكة Google: إن تأخّرت
تأخّر الحجز، وإن سقطت سقط. أي أن عطباً في إشعارٍ يمنع بيعاً. والخطّاف يقع بعد
الالتزام، خارجه.

## الفحص

بعد الخطوات الخمس:

1. ثبّت الحزمة الجديدة على جوالٍ حقيقي وسجّل الدخول.
2. تحقّق أن الرمز سُجّل:
   ```sql
   select user_id, platform, left(push_token, 12) || '…' as token, push_updated_at
   from public.user_devices where push_token is not null;
   ```
3. أغلق التطبيق تماماً، ثم اطلب من حسابٍ آخر أن يرسل إليك رسالة.
4. إن لم يصل شيء: **Edge Functions → push → Logs** يقول أين وقف.

## ما لا يفعله هذا

لا يُعرض إشعارٌ والتطبيق **مفتوحٌ أمامك**: النظام يعرض إشعارات الخلفية وحدها،
والجرس في أعلى الشاشة أصدقُ دلالةً من لافتةٍ تغطّي ما تنظر إليه. وعرضُها
يحتاج حزمةً أصليةً ثالثة (`flutter_local_notifications`).
