-- ============================================================================
--  الإشعارات: صندوقٌ داخل التطبيق، ورمزُ جهازٍ للدفع
--
--  شغّله في محرّر SQL بعد `install.sql` و`chat.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان موجوداً:**
--
--  جدول `notifications` وسياساته في المخطّط منذ البداية، ودالّتا
--  `notify_user()` و`notify_provider()` تُستدعيان فعلاً من سبعة مواضع في
--  `api.sql`: طلبُ حجزٍ جديد، وتأكيده، والاعتذار عنه، وإلغاؤه، وتأكيدُ
--  الدفعة، وطلبُ التقييم، ووصولُ تقييم.
--
--  أي أن التطبيق **يكتب إشعاراته منذ اليوم الأول ولا يقرؤها أحد**. سبعةُ
--  أحداثٍ تُسجَّل في صندوقٍ لا باب له. وصاحب القاعة الذي وصله طلب حجز لا يعلم
--  حتى يفتح شاشة الطلبات من تلقاء نفسه.
--
--  **وما يضيفه هذا الملف:**
--
--  ١. إشعارَ الرسالة — والمحادثة جديدة فلم يكن لها موضعٌ في `api.sql`.
--  ٢. رمزَ الجهاز، وهو ما يحتاجه الدفع (FCM) حين يُربط المشروع بـFirebase.
--  ٣. إضافة الجدول إلى نشرة البثّ، فتصل الحبّةُ والجرسُ يعملان.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ١. إشعار الرسالة — **واحدٌ لكل محادثة لا واحدٌ لكل رسالة**
--
--    من كتب عشرين سطراً متتابعاً يُنتج عشرين إشعاراً، فيصير الصندوق سجلَّ
--    محادثةٍ لا صندوقَ تنبيه، ويُدفن فيه «قُبل حجزك» بين كلامٍ عابر. فإن كان
--    للمستلم إشعارُ رسالةٍ من هذه المحادثة لم يقرأه بعدُ، حُدِّث نصُّه وزمنُه
--    مكانَه.
--
--    وهذا يوافق ما يفعله الجرس: الحبّة تقول «هناك جديد»، لا «هناك عشرون
--    جديداً».
-- ----------------------------------------------------------------------------
create or replace function public.notify_conversation_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  convo   public.conversations;
  who     text;
  target  uuid;
  is_user boolean := new.sender = 'provider';   -- المستلم عميلٌ إذا كتب المزوّد
  existing uuid;
begin
  select * into convo from public.conversations where id = new.conversation_id;
  if convo.id is null then return new; end if;

  if is_user then
    target := convo.user_id;
    who    := coalesce(nullif(convo.provider_name, ''), 'مقدّم الخدمة');
  else
    target := convo.provider_id;
    who    := coalesce(nullif(convo.user_name, ''), 'العميل');
  end if;
  if target is null then return new; end if;

  select n.id into existing
  from public.notifications n
  where n.kind = 'message'
    and n.read_at is null
    and n.data ->> 'conversation_id' = new.conversation_id::text
    and (case when is_user then n.user_id else n.provider_id end) = target
  limit 1;

  if existing is not null then
    update public.notifications
    set body = left(new.body, 120), created_at = new.created_at
    where id = existing;
    return new;
  end if;

  if is_user then
    perform public.notify_user(
      target, 'message', who, left(new.body, 120),
      jsonb_build_object('conversation_id', new.conversation_id));
  else
    perform public.notify_provider(
      target, 'message', who, left(new.body, 120),
      jsonb_build_object('conversation_id', new.conversation_id));
  end if;
  return new;
end $$;

drop trigger if exists notify_conversation_message on public.conversation_messages;
create trigger notify_conversation_message
  after insert on public.conversation_messages
  for each row execute function public.notify_conversation_message();

-- ----------------------------------------------------------------------------
-- ٢. رمز الجهاز
--
--    الرمز على `user_devices` لا في جدولٍ جديد: الجدول موجودٌ وفيه المنصّة
--    والطراز و`push_enabled`، وهي ما يحتاجه المرسِل ليختار من يُرسل إليه.
--
--    والفهرس فريدٌ على الرمز: FCM يُصدر رمزاً لكل تثبيت، وقد ينتقل الرمز نفسه
--    إلى حسابٍ آخر على الجهاز نفسه. فلولا الفريد لبقي الرمز مقيّداً لصاحبه
--    الأول، ولوصلت إشعاراتُ حسابٍ إلى من سجّل بعده على الجهاز — وهو تسريبٌ
--    لا عطبُ راحة.
-- ----------------------------------------------------------------------------
alter table public.user_devices add column if not exists push_token text;
alter table public.user_devices
  add column if not exists push_updated_at timestamptz not null default now();

create unique index if not exists user_devices_push_token_key
  on public.user_devices (push_token) where push_token is not null;

-- تسجيل رمز الجهاز — يُستدعى عند كل إقلاع، فالرمز يتغيّر بلا إشعار.
create or replace function public.api_register_push_token(
  p_token      text,
  p_platform   text default 'android',
  p_model      text default '',
  p_os_version text default ''
)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := public.current_app_user();
begin
  if me is null or coalesce(p_token, '') = '' then return; end if;
  if p_platform not in ('ios', 'android') then p_platform := 'android'; end if;

  -- الرمز مفتاح: إن كان مسجّلاً نُقل إلى صاحبه الحالي بدل أن يُنشأ صفٌّ ثانٍ.
  update public.user_devices set
    user_id         = me,
    platform        = p_platform,
    model           = coalesce(nullif(p_model, ''), model),
    os_version      = coalesce(nullif(p_os_version, ''), os_version),
    last_used_at    = now(),
    push_updated_at = now()
  where push_token = p_token;

  if not found then
    insert into public.user_devices
      (user_id, model, os_version, platform, push_token, push_enabled)
    values (me, coalesce(nullif(p_model, ''), 'جهاز'), p_os_version, p_platform, p_token, true);
  end if;
end $$;

-- إيقاف الدفع عن هذا الجهاز — عند الخروج من الحساب.
create or replace function public.api_forget_push_token(p_token text)
returns void language sql security definer set search_path = public as $$
  update public.user_devices set push_token = null, push_updated_at = now()
  where push_token = p_token and user_id = public.current_app_user();
$$;

grant execute on function public.api_register_push_token(text, text, text, text) to authenticated;
grant execute on function public.api_forget_push_token(text) to authenticated;

-- ----------------------------------------------------------------------------
-- ٣. تعليم المقروء
--
--    سياسة `notifications_owner_update` تسمح لصاحب الصفّ بالتحديث، فتكفي
--    لتعليم إشعارٍ واحد. وهذه للجميع دفعةً واحدة — «علّم الكل مقروءاً» — وهي
--    جملةٌ لا يستطيع العميل كتابتها بأمانٍ من جانبه: `update … where user_id
--    = ?` يحتاج أن يعرف معرّفه، وهو لا يعرفه في التطبيق.
-- ----------------------------------------------------------------------------
create or replace function public.api_mark_all_notifications_read()
returns integer language plpgsql security definer set search_path = public as $$
declare
  me      uuid := public.current_app_user();
  mine    uuid := public.current_provider();
  touched integer;
begin
  update public.notifications set read_at = now()
  where read_at is null
    and ((user_id is not null and user_id = me)
      or (provider_id is not null and provider_id = mine));
  get diagnostics touched = row_count;
  return touched;
end $$;

grant execute on function public.api_mark_all_notifications_read() to authenticated;

-- ----------------------------------------------------------------------------
-- ٤. البثّ الحيّ
--
--    بدونه لا تظهر الحبّة على الجرس حتى يُغلق المستخدم التطبيق ويفتحه. وهو
--    ما يجعل الإشعار داخل التطبيق مجدياً حتى قبل ربط Firebase.
-- ----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'notifications')
  then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- ٥. التحقّق
-- ----------------------------------------------------------------------------
select 'مُشغِّل الرسالة' as البند,
       count(*)::text as النتيجة
  from pg_trigger where tgname = 'notify_conversation_message' and not tgisinternal
union all
select 'عمود الرمز', count(*)::text from information_schema.columns
 where table_schema = 'public' and table_name = 'user_devices' and column_name = 'push_token'
union all
select 'الفهرس الفريد', count(*)::text from pg_indexes
 where schemaname = 'public' and indexname = 'user_devices_push_token_key'
union all
select 'الدوال', count(*)::text from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('api_register_push_token', 'api_forget_push_token',
                     'api_mark_all_notifications_read', 'notify_conversation_message');
