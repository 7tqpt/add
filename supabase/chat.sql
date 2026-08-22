-- ============================================================================
--  المحادثة بين العميل ومقدّم الخدمة
--
--  شغّله في محرّر SQL بعد `install.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان موجوداً وما كان ناقصاً:**
--
--  الجدولان (`conversations` و`conversation_messages`) وسياساتهما في المخطّط
--  منذ البداية، وتعليقُهما يقول: «تُخزَّن لتظهر للإدارة عند نظر نزاع؛ ليست
--  شاشة تشغيلية يومية». وهذا هو ما تغيّر: صارت شاشةً يوميّة. ومن يبني شاشةً
--  على هذين الجدولين كما هما يجد ثلاثة نواقص:
--
--  ١. **`last_message_at` لا يتحرّك.** ولا يستطيع العميل تحريكه: لا سياسة
--     `update` على `conversations` أصلاً. فقائمة المحادثات تبقى مرتّبةً بزمن
--     الإنشاء إلى الأبد — أي أن أحدث محادثةٍ قد تكون في آخر القائمة.
--
--  ٢. **لا أثر لِما قُرئ.** فلا شارةَ «جديد»، ولا يعلم صاحب القاعة أن عميلاً
--     كتب إليه. ورسالةٌ لا يعلم بها المرسَل إليه ليست رسالة.
--
--  ٣. **لا نصّ آخر رسالة في القائمة.** فبلا تخزينه يحتاج عرضُ عشر محادثاتٍ
--     عشرة استعلامات — وهذا ما يُسمّى N+1، وعلى شبكة الجوال يُرى تأخّراً.
--
--  ويُصلَح الثلاثة بمُشغِّلٍ واحد: هو الذي يكتب، لا العميل. فلا يستطيع أحدٌ
--  أن يزعم أن رسالتَه أحدث ممّا هي، ولا أن يُعلّم محادثةَ غيره مقروءة.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ١. ما تحتاجه القائمة
--
--    نصُّ آخر رسالةٍ مقصوصٌ عند ‎١٦٠‎ حرفاً: القائمة تعرض سطراً واحداً، وحفظُ
--    رسالةٍ بألف حرفٍ مرّتين (في الرسائل وفي المحادثة) دفعُ ثمنٍ بلا مقابل.
-- ----------------------------------------------------------------------------
alter table public.conversations
  add column if not exists last_message_body text not null default '';
alter table public.conversations
  add column if not exists last_message_sender text;
alter table public.conversations
  add column if not exists customer_read_at timestamptz;
alter table public.conversations
  add column if not exists provider_read_at timestamptz;

-- ----------------------------------------------------------------------------
-- ٢. المُشغِّل
--
--    `security definer` لأن الطرفين لا يملكان `update` على `conversations`،
--    وهذا مقصود: ما يُكتب هنا خلاصةٌ تُشتقّ من الرسالة لا رأيٌ لصاحبها.
--
--    ويُعلَّم المرسِل قارئاً لرسالته: لولا ذلك لظهرت له محادثتُه «غير مقروءة»
--    بسبب كلامه هو.
-- ----------------------------------------------------------------------------
create or replace function public.conversation_touch()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.conversations set
    last_message_at     = new.created_at,
    last_message_body   = left(new.body, 160),
    last_message_sender = new.sender,
    customer_read_at    = case when new.sender = 'customer' then new.created_at
                               else customer_read_at end,
    provider_read_at    = case when new.sender = 'provider' then new.created_at
                               else provider_read_at end
  where id = new.conversation_id;
  return new;
end $$;

drop trigger if exists conversation_touch on public.conversation_messages;
create trigger conversation_touch
  after insert on public.conversation_messages
  for each row execute function public.conversation_touch();

-- ----------------------------------------------------------------------------
-- ٣. فتح المحادثة
--
--    دالّةٌ لا كتابةٌ مباشرة، لسببين:
--
--    **الأسماء.** `user_name` و`provider_name` عمودان في الجدول، ولو كتبهما
--    العميل لكتب ما شاء — فيظهر لصاحب القاعة اسمٌ غير اسم من يكلّمه.
--
--    **السباق.** «ابحث ثم أنشئ إن لم تجد» من طرف العميل ينتج محادثتين حين
--    يُضغط الزرّ مرّتين بسرعة، فتنقسم الرسائل بين اثنتين ولا يرى أحدٌ نصفها.
--    وهنا الفحص والإنشاء في جملةٍ واحدة.
-- ----------------------------------------------------------------------------
create or replace function public.api_open_conversation(
  p_provider_id uuid,
  p_booking_id  uuid default null
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me            uuid := public.current_app_user();
  my_name       text;
  provider_name text;
  found         uuid;
begin
  if me is null then
    raise exception 'لا يمكن فتح محادثة قبل إكمال حسابك.' using errcode = '42501';
  end if;

  select p.business_name into provider_name
  from public.service_providers p
  where p.id = p_provider_id and p.status = 'verified';
  if provider_name is null then
    raise exception 'مقدّم الخدمة غير موجود أو غير موثّق.' using errcode = 'P0002';
  end if;

  select u.full_name into my_name from public.app_users u where u.id = me;

  -- محادثةٌ واحدة لكل (عميل، مقدّم خدمة) بصرف النظر عن الحجز: من راسل صاحب
  -- القاعة قبل الحجز ثم حجز لا يبدأ من جديد، ولا يبحث عن كلامه في خيطين.
  select c.id into found
  from public.conversations c
  where c.user_id = me and c.provider_id = p_provider_id
  order by c.last_message_at desc
  limit 1;

  if found is not null then
    -- الحجز يُربط أوّلَ مرّةٍ يُذكر فيها ولا يُبدَّل بعدها.
    if p_booking_id is not null then
      update public.conversations set booking_id = p_booking_id
      where id = found and booking_id is null;
    end if;
    return found;
  end if;

  insert into public.conversations (booking_id, user_id, user_name, provider_id, provider_name)
  values (p_booking_id, me, coalesce(my_name, ''), p_provider_id, provider_name)
  returning id into found;
  return found;
end $$;

-- ----------------------------------------------------------------------------
-- ٣ب. والطرف الآخر يفتحها أيضاً
--
--    صاحبُ القاعة يحتاج أن يبدأ لا أن يردّ فقط: «موعدك بعد ثلاثة أيام، تعال
--    عاين القاعة»، أو «تأخّر العربون». ولولا هذه لبقي حبيسَ من كلّمه أوّلاً.
--
--    والمدخل هنا **حجز** لا عميل: لا يفتح صاحبُ القاعة محادثةً مع من لم
--    يتعامل معه. ولو كان المدخل معرّفَ عميلٍ لأمكن لمقدّم خدمةٍ أن يراسل كل
--    من في القاعدة واحداً واحداً.
-- ----------------------------------------------------------------------------
create or replace function public.api_open_conversation_with_customer(p_booking_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  mine     uuid := public.current_provider();
  customer uuid;
  my_name  text;
  their    text;
  found    uuid;
begin
  if mine is null then
    raise exception 'هذه لمقدّمي الخدمة.' using errcode = '42501';
  end if;

  select b.user_id into customer
  from public.bookings b
  where b.id = p_booking_id and b.provider_id = mine;
  if customer is null then
    raise exception 'الحجز غير موجود أو ليس لك.' using errcode = 'P0002';
  end if;

  select p.business_name into my_name from public.service_providers p where p.id = mine;
  select u.full_name into their from public.app_users u where u.id = customer;

  select c.id into found
  from public.conversations c
  where c.user_id = customer and c.provider_id = mine
  order by c.last_message_at desc
  limit 1;

  if found is not null then
    update public.conversations set booking_id = p_booking_id
    where id = found and booking_id is null;
    return found;
  end if;

  insert into public.conversations (booking_id, user_id, user_name, provider_id, provider_name)
  values (p_booking_id, customer, coalesce(their, ''), mine, coalesce(my_name, ''))
  returning id into found;
  return found;
end $$;

-- ----------------------------------------------------------------------------
-- ٤. تعليم المقروء
--
--    عمودٌ واحد يُكتب — عمودُ الطرف الذي يستدعي. ولو فُتح `update` على الجدول
--    لأمكن لطرفٍ أن يُعلّم رسائله هو مقروءةً عند الآخر، فتختفي شارةُ «جديد»
--    عمّن لم يقرأ.
-- ----------------------------------------------------------------------------
create or replace function public.api_mark_conversation_read(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me       uuid := public.current_app_user();
  mine     uuid := public.current_provider();
begin
  update public.conversations c set
    customer_read_at = case when c.user_id = me then now() else c.customer_read_at end,
    provider_read_at = case when c.provider_id = mine then now() else c.provider_read_at end
  where c.id = p_conversation_id
    and (c.user_id = me or c.provider_id = mine);
end $$;

-- ----------------------------------------------------------------------------
-- ٥. قائمة محادثاتي
--
--    الطرف الآخر واسمُه وعددُ ما لم يُقرأ — في صفٍّ واحد لكل محادثة.
--
--    و`security_invoker` فتُطبَّق سياسة `conversations_parties` على المتصل:
--    الطريقة لا تفتح ما أغلقته السياسة، إنما تختصر حسابه.
-- ----------------------------------------------------------------------------
create or replace view public.v_my_conversations
with (security_invoker = true) as
select
  c.id,
  c.booking_id,
  c.user_id,
  c.provider_id,
  c.last_message_at,
  c.last_message_body,
  c.last_message_sender,
  -- «أنا» هنا الطرف الذي يقرأ، والاسم المعروض اسمُ الآخر: العميل يرى اسم
  -- القاعة، وصاحب القاعة يرى اسم العميل.
  case when c.user_id = public.current_app_user() then 'customer' else 'provider' end
    as my_side,
  case when c.user_id = public.current_app_user() then c.provider_name else c.user_name end
    as other_name,
  (
    select count(*)
    from public.conversation_messages m
    where m.conversation_id = c.id
      and m.sender <> (case when c.user_id = public.current_app_user()
                            then 'customer' else 'provider' end)
      and m.created_at > coalesce(
            case when c.user_id = public.current_app_user()
                 then c.customer_read_at else c.provider_read_at end,
            'epoch'::timestamptz)
  ) as unread_count
from public.conversations c
where c.user_id = public.current_app_user()
   or c.provider_id = public.current_provider();

grant select on public.v_my_conversations to authenticated;
grant execute on function public.api_open_conversation(uuid, uuid) to authenticated;
grant execute on function public.api_open_conversation_with_customer(uuid) to authenticated;
grant execute on function public.api_mark_conversation_read(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- ٦. البثّ الحيّ
--
--    بدونه لا تصل الرسالة حتى يُغلق الطرف الآخر الشاشة ويفتحها — وهذه ليست
--    محادثة. والجملة محروسة: النشرة `supabase_realtime` من صنع Supabase ولا
--    وجود لها في قاعدةٍ عادية، وبلا الحراسة يسقط الملف كلُّه عند من يشغّله
--    على غيرها.
-- ----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'conversation_messages')
  then
    alter publication supabase_realtime add table public.conversation_messages;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- ٧. التحقّق
-- ----------------------------------------------------------------------------
select 'أعمدة القائمة' as البند,
       count(*)::text as النتيجة
  from information_schema.columns
 where table_schema = 'public' and table_name = 'conversations'
   and column_name in ('last_message_body', 'last_message_sender',
                       'customer_read_at', 'provider_read_at')
union all
select 'المُشغِّل', count(*)::text from pg_trigger
 where tgname = 'conversation_touch' and not tgisinternal
union all
select 'الدوال', count(*)::text from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('api_open_conversation', 'api_open_conversation_with_customer',
                     'api_mark_conversation_read', 'conversation_touch')
union all
select 'طريقة العرض', count(*)::text from information_schema.views
 where table_schema = 'public' and table_name = 'v_my_conversations';
