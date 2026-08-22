-- ============================================================================
--  ربط صندوق الإشعارات بدالّة الدفع
--
--  شغّله بعد `notifications.sql`، وبعد نشر دالّة `push`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما يفعله:** يضع مُشغِّلاً على `notifications` ينادي دالّة الحافة عند كل
--  صفٍّ جديد. وهو نفسه ما تصنعه لوحة Supabase حين تُنشئ «Database Webhook» —
--  بضغطاتٍ في متصفّح لا أثر لها في المستودع.
--
--  **ولماذا هنا لا هناك:** ما يُصنع بالضغط يُنسى ولا يُراجَع ولا يُعاد بناؤه.
--  ومن أنشأ مشروعاً ثانياً للتجربة بدأ من الصفر ولم يعرف ما الذي نسيه. وهذا
--  الملف يُشغَّل مرّةً فيقع الربط، ويُشغَّل مرّةً أخرى فلا يتكرّر.
--
--  **وهو محروسٌ كلُّه:** مخطّط `supabase_functions` من صنع Supabase ولا وجود
--  له في قاعدةٍ عادية. فإن غاب لم يقع شيء ولم يسقط الملف — تُقرأ النتيجة في
--  آخره.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- الدالّة
--
--  `p_project_url` رابط مشروعك — `https://xxxx.supabase.co`. وهو **ليس
--  سرّاً**: هو نفسه الذي في `env.json` وفي كل نسخةٍ من التطبيق على أجهزة
--  الناس. أمّا مفتاح الخدمة فلا يُمرَّر هنا ولا يُخزَّن في القاعدة: الدالّة
--  منشورةٌ بـ`--no-verify-jwt` لأن المنادي مُشغِّلٌ لا مستخدم.
-- ----------------------------------------------------------------------------
create or replace function public.enable_push_webhook(p_project_url text)
returns text language plpgsql security definer set search_path = public as $$
declare
  url text := rtrim(p_project_url, '/') || '/functions/v1/push';
begin
  if p_project_url is null or p_project_url !~ '^https://' then
    return '❌ مرّر رابط مشروعك كاملاً، مثل https://xxxx.supabase.co';
  end if;

  if not exists (select 1 from pg_namespace where nspname = 'supabase_functions') then
    return '⚠️ مخطّط supabase_functions غير موجود — شغّل هذا الملف على مشروع Supabase لا على قاعدةٍ محلّية.';
  end if;

  -- يُحذف أوّلاً ثم يُنشأ: `create trigger` لا يقبل `or replace`، وإعادةُ
  -- التشغيل بعد تغيير الرابط يجب أن تُبدّله لا أن تُضيف مُشغِّلاً ثانياً
  -- فيصل الإشعار مرّتين.
  drop trigger if exists push_on_notification on public.notifications;

  execute format($t$
    create trigger push_on_notification
      after insert on public.notifications
      for each row execute function supabase_functions.http_request(
        %L, 'POST', '{"Content-Type":"application/json"}', '{}', '5000')
  $t$, url);

  return '✅ رُبط الصندوق بالدالّة: ' || url;
end $$;

-- ----------------------------------------------------------------------------
-- والفصل — لإيقاف الدفع بلا حذف شيء
-- ----------------------------------------------------------------------------
create or replace function public.disable_push_webhook()
returns text language plpgsql security definer set search_path = public as $$
begin
  drop trigger if exists push_on_notification on public.notifications;
  return '✅ فُصل الدفع. والصندوق داخل التطبيق يعمل كما هو.';
end $$;

-- ============================================================================
--  ✏️  ضع رابط مشروعك مكان ما تحته خطّ ثم شغّل السطر
-- ============================================================================

-- select public.enable_push_webhook('https://xxxxxxxxxxxx.supabase.co');
