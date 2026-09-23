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
--  يقرأ سرّاً مخصّصاً من Vault وقت الإرسال، ولا يضعه في تعريف المُشغّل.
--  يحتاج `vault` و`pg_net` في مشروع Supabase؛ عند غيابهما لا يُبدّل الربط.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- الدالّة
--
--  `p_project_url` رابط مشروعك — `https://xxxx.supabase.co`. وهو **ليس
--  سرّاً**: هو نفسه الذي في `env.json` وفي كل نسخةٍ من التطبيق على أجهزة
--  الناس. أمّا سرّ الخطّاف فيُحفظ في Vault باسم `push_webhook_secret`،
--  ونفس قيمته في Edge Functions → Secrets باسم `PUSH_WEBHOOK_SECRET`.
-- ----------------------------------------------------------------------------
create or replace function public.dispatch_push_webhook()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  webhook_secret text;
begin
  select decrypted_secret into webhook_secret
    from vault.decrypted_secrets where name = 'push_webhook_secret';
  if webhook_secret is null or webhook_secret = '' then
    raise warning 'push_webhook_secret غير مضبوط في Vault؛ لم يُرسل الإشعار';
    return new;
  end if;

  perform net.http_post(
    url := TG_ARGV[0],
    body := jsonb_build_object('type', TG_OP, 'record', to_jsonb(new)),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-webhook-secret', webhook_secret),
    timeout_milliseconds := 5000
  );
  return new;
end $$;

revoke all on function public.dispatch_push_webhook()
  from public, anon, authenticated;

create or replace function public.enable_push_webhook(p_project_url text)
returns text language plpgsql security definer set search_path = public as $$
declare
  url text := rtrim(p_project_url, '/') || '/functions/v1/push';
begin
  if p_project_url is null or p_project_url !~ '^https://' then
    return '❌ مرّر رابط مشروعك كاملاً، مثل https://xxxx.supabase.co';
  end if;

  if to_regclass('vault.decrypted_secrets') is null
     or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then
    return '⚠️ يلزم Vault وpg_net قبل ربط الإشعارات.';
  end if;

  if not exists (select 1 from vault.decrypted_secrets
                  where name = 'push_webhook_secret'
                    and decrypted_secret <> '') then
    return '⚠️ احفظ push_webhook_secret في Vault قبل ربط الإشعارات.';
  end if;

  -- يُحذف أوّلاً ثم يُنشأ: `create trigger` لا يقبل `or replace`، وإعادةُ
  -- التشغيل بعد تغيير الرابط يجب أن تُبدّله لا أن تُضيف مُشغِّلاً ثانياً
  -- فيصل الإشعار مرّتين.
  drop trigger if exists push_on_notification on public.notifications;

  execute format($t$
    create trigger push_on_notification
      after insert on public.notifications
      for each row execute function public.dispatch_push_webhook(%L)
  $t$, url);

  return '✅ رُبط الصندوق بالدالّة: ' || url;
end $$;

-- These functions change a database trigger with the creator's privileges.
-- They are SQL Editor maintenance operations, not public Data API RPCs.
revoke all on function public.enable_push_webhook(text)
  from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- والفصل — لإيقاف الدفع بلا حذف شيء
-- ----------------------------------------------------------------------------
create or replace function public.disable_push_webhook()
returns text language plpgsql security definer set search_path = public as $$
begin
  drop trigger if exists push_on_notification on public.notifications;
  return '✅ فُصل الدفع. والصندوق داخل التطبيق يعمل كما هو.';
end $$;

revoke all on function public.disable_push_webhook()
  from public, anon, authenticated;

-- ============================================================================
--  ✏️  ضع رابط مشروعك مكان ما تحته خطّ ثم شغّل السطر
-- ============================================================================

-- select public.enable_push_webhook('https://xxxxxxxxxxxx.supabase.co');
