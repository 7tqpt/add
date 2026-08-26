-- ============================================================================
--  مرفقاتُ المحادثة: صورةٌ وصوتٌ وفيديو وملفّ
--
--  شغّله **بعد `chat.sql`**. آمنٌ عند التكرار.
-- ============================================================================
--
--  **لماذا:** الاتفاق على تفاصيل عرسٍ ليس كلاماً مكتوباً. صاحبُ القاعة يصوّر
--  الصالة ليلاً، والعروس ترسل صورة الكوشة التي تريدها، والمصوّر يرسل مقطعاً
--  من عمله، والعقد ورقةٌ تُصوَّر أو ملفّ. ومن لا يستطيع فعل ذلك هنا يفعله في
--  واتساب — **فيخرج الاتفاق من المنصّة ومعه سجلُّه**، فإذا وقع نزاعٌ لم يبقَ
--  للإدارة ما تنظر فيه. وهذا بالضبط ما بُنيت المحادثة لمنعه.
--
--  **والسلّة خاصّةٌ لا عامّة** — وهذا أهمُّ سطرٍ هنا. سلّةُ وسائط الخدمات
--  عامّة لأن ما فيها معروضٌ للبيع؛ أمّا صورةُ عقدٍ أو حديثُ رجلٍ عن عرس ابنته
--  فليسا معروضين لأحد. ورابطٌ عامٌّ يعني أن من خمّن مساراً فتح محادثةً ليست له.
-- ============================================================================

begin;

alter table public.conversation_messages
  add column if not exists attachment_path    text,
  add column if not exists attachment_kind    text,
  add column if not exists attachment_seconds integer,
  add column if not exists attachment_name    text,
  add column if not exists attachment_size    integer;

alter table public.conversation_messages
  drop constraint if exists message_attachment_kind;
alter table public.conversation_messages
  add constraint message_attachment_kind
  check (attachment_kind is null
         or attachment_kind in ('image', 'audio', 'video', 'file'));

-- المرفقُ ونوعُه لا يفترقان: مسارٌ بلا نوعٍ لا تعرف الشاشة كيف ترسمه، ونوعٌ
-- بلا مسارٍ صفٌّ كاذب.
alter table public.conversation_messages
  drop constraint if exists message_attachment_pair;
alter table public.conversation_messages
  add constraint message_attachment_pair
  check ((attachment_path is null) = (attachment_kind is null));

-- **والمدّة للمسموع والمرئيّ وحدهما.** صورةٌ «مدّتها ١٢ ثانية» صفٌّ لا معنى
-- له، ومقطعٌ بلا مدّةٍ لا يعرف المستمع كم ينتظر — والصفرُ يعني أن القياس لم
-- يقع أصلاً فيمرّ مقطعٌ مجهولُ الطول.
--
-- ودقيقتان للصوت ودقيقةٌ للفيديو: أطولُ من ذلك ليس رسالةً بل مكالمة، ويثقل
-- تنزيلُه على شبكةٍ يمنية — يدفعه المرسِل مرّةً والمستقبِل مرّة.
alter table public.conversation_messages
  drop constraint if exists message_attachment_seconds;
alter table public.conversation_messages
  add constraint message_attachment_seconds
  check (
    case attachment_kind
      -- **و`is not null` ليست زائدة.** `null between 1 and 120` تساوي `null`،
      -- و`check` تقبل كلَّ ما ليس `false` — فمقطعٌ بلا مدّةٍ كان يمرّ من قيدٍ
      -- كُتب ليمنعه. كشفه اختبارٌ لا قراءة.
      when 'audio' then attachment_seconds is not null
                    and attachment_seconds between 1 and 120
      -- **والفيديو يقبل غيابَها، والصوتُ لا.** مدّةُ التسجيل الصوتي نقيسها
      -- بأنفسنا بساعةٍ تعمل وقت التسجيل، فلا عذر في غيابها. أمّا مدّةُ مقطعٍ
      -- مصوَّرٍ فلا تُعرف إلا بفتحه في مشغّل — **وخزنُ رقمٍ لم يُقَس أسوأ من
      -- تركه فارغاً**: المشغّل يقول المدّة حين يُفتح، والرقم الكاذب يبقى.
      -- والحدُّ الأعلى مفروضٌ وقت التصوير (`maxDuration`) وبحدّ حجم السلّة.
      when 'video' then attachment_seconds is null
                    or attachment_seconds between 1 and 60
      else attachment_seconds is null
    end
  );

-- والملفُّ باسمه: «مرفق» وحدها لا تقول أهو العقد أم قائمة الأسعار، ومن يفتح
-- محادثةً بعد شهرٍ يبحث بالاسم لا بالأيقونة.
alter table public.conversation_messages
  drop constraint if exists message_file_named;
alter table public.conversation_messages
  add constraint message_file_named
  check (attachment_kind is distinct from 'file'
         or length(btrim(coalesce(attachment_name, ''))) > 0);

-- **ورسالةٌ فارغةٌ من الاثنين تُردّ.** كان `body` مطلوباً فكفى وحده؛ والآن صار
-- المرفقُ بديلاً عنه، فبلا هذا القيد يمرّ صفٌّ لا نصَّ فيه ولا مرفق — فقاعةٌ
-- بيضاء في الخيط لا يعرف أحدٌ ما هي.
alter table public.conversation_messages
  drop constraint if exists message_not_empty;
alter table public.conversation_messages
  add constraint message_not_empty
  check (length(btrim(body)) > 0 or attachment_path is not null);

-- ----------------------------------------------------------------------------
-- معاينةُ الخيط
--
-- `last_message_body` تعرضه قائمةُ المحادثات. ورسالةٌ مرفقٌ نصُّها فارغ كانت
-- ستُظهر سطراً خالياً — فيبدو الخيط وكأن لا جديد فيه.
-- ----------------------------------------------------------------------------
create or replace function public.conversation_touch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.conversations c
     set last_message_at     = new.created_at,
         last_message_body   = case
           when length(btrim(new.body)) > 0 then left(new.body, 160)
           when new.attachment_kind = 'image' then '📷 صورة'
           when new.attachment_kind = 'audio' then '🎤 رسالة صوتية'
           when new.attachment_kind = 'video' then '🎬 مقطع فيديو'
           when new.attachment_kind = 'file'
             then '📎 ' || left(coalesce(new.attachment_name, 'ملف'), 60)
           else ''
         end,
         last_message_sender = new.sender,
         -- المرسِلُ قارئٌ لكلامه: لولا ذلك لظهرت له محادثتُه «غير مقروءة»
         -- بسببه هو.
         customer_read_at = case when new.sender = 'customer'
                                 then new.created_at else c.customer_read_at end,
         provider_read_at = case when new.sender = 'provider'
                                 then new.created_at else c.provider_read_at end
   where c.id = new.conversation_id;
  return new;
end $$;

-- ----------------------------------------------------------------------------
-- السلّة — **خاصّة**
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-media', 'chat-media', false, 26214400,
  array[
    'image/jpeg', 'image/png', 'image/webp',
    'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/ogg', 'audio/wav', 'audio/x-m4a',
    'video/mp4', 'video/quicktime', 'video/3gpp',
    'application/pdf'
  ]
)
on conflict (id) do update
  set public             = false,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- المسار `<conversation_id>/<ختم>.<امتداد>`، فأوّلُ جزءٍ منه هو المحادثة —
-- وعليه تُبنى الحراسة: طرفاها وحدهما، والإدارة عند نظر نزاع.
create or replace function public.in_conversation(p_conversation text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.conversations c
     where c.id::text = p_conversation
       and (c.user_id = public.current_app_user()
            or c.provider_id = public.current_provider()
            or public.is_admin())
  )
$$;

drop policy if exists "chat media parties read" on storage.objects;
create policy "chat media parties read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'chat-media'
    and public.in_conversation((storage.foldername(name))[1])
  );

drop policy if exists "chat media parties write" on storage.objects;
create policy "chat media parties write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and public.in_conversation((storage.foldername(name))[1])
  );

-- **ولا سياسةَ حذفٍ لطرفي المحادثة، وهذا مقصود:** المحادثة سجلٌّ يُنظر فيه عند
-- النزاع. ومن يستطيع محو صورة العقد بعد أن أرسلها يمحو الدليل عليه.
drop policy if exists "chat media admin deletes" on storage.objects;
create policy "chat media admin deletes" on storage.objects
  for delete to authenticated
  using (bucket_id = 'chat-media' and public.can_write());

commit;

notify pgrst, 'reload schema';

-- ============================================================================
--  الفحص
-- ============================================================================
select 'أعمدة المرفق' as البند,
       case when exists (
         select 1 from information_schema.columns
          where table_name = 'conversation_messages' and column_name = 'attachment_path')
       then '✅' else '❌' end as الحال
union all
select 'قيدُ الرسالة غير الفارغة',
       case when exists (select 1 from pg_constraint where conname = 'message_not_empty')
       then '✅' else '❌' end
union all
select 'السلّة خاصّة',
       case when exists (
         select 1 from storage.buckets where id = 'chat-media' and public = false)
       then '✅' else '❌ عامّة — مرفقاتُ الناس مكشوفة' end
union all
select 'حارسُ القراءة',
       case when exists (
         select 1 from pg_policies
          where tablename = 'objects' and policyname = 'chat media parties read')
       then '✅' else '❌' end;
