-- ============================================================================
--  صورةُ الطرف الآخر في قائمة المحادثات — للطرفين لا لطرف
--
--  شغّله في محرّر SQL بعد `chat.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:**
--
--  `v_my_conversations` طريقةُ عرضٍ `security_invoker` — أي أنّ كلَّ وصلٍ
--  فيها يمرّ بسياسة المتصل. فلمّا أُضيف `other_avatar` إليها لم يمكن أن
--  يُرجَع إلّا شعارُ القاعة للعميل: صورةُ العميل في `app_users`، وسياستُه
--  صريحة: «العميل يرى ويعدّل حسابه هو. **لا يرى حسابات غيره إطلاقاً**» —
--  وهي تشمل مقدّمَ الخدمة.
--
--  فكان مقدّمُ الخدمة يرى حروفاً في قائمته أبداً. ورآها صاحبُ المنصّة
--  فقال: «اجلب لي صورة من ملف العميل، خلّه تظهر في المحادثة بدل الحروف».
--
--  **والطريقُ هو الذي أقرّه قبلَه لبطاقة العميل:** دالّةٌ `security definer`
--  ترى الصفَّ ولا تُخرج منه إلّا ما وُعد به. انظر `customer_card.sql`.
--
--  **وما تُخرجه هذه:** أعمدةُ الطريقة نفسُها ومعها `other_avatar` محلولةً
--  للجانبين — **ولا بريدَ ولا جوّالَ ولا حالةَ حساب**.
--
--  **وحدُّها:** لا تُرجع إلّا محادثاتِ المتصل. ولو سقط ذلك الشرطُ لَقرأ أيُّ
--  مستخدمٍ محادثاتِ الناس كلِّهم — وهو أخطرُ ممّا تحرسه السياسةُ أصلاً.
--
--  **وتبقى الطريقةُ كما هي ولا تُحذف:** اللوحةُ وغيرُها قد تقرؤها، وحذفُ
--  شيءٍ يقرؤه غيرُك ليس من شأن هذا الملفّ.
-- ============================================================================

create or replace function public.api_my_conversations(
  p_conversation_id uuid default null
)
returns table (
  id                  uuid,
  booking_id          uuid,
  user_id             uuid,
  provider_id         uuid,
  last_message_at     timestamptz,
  last_message_body   text,
  last_message_sender text,
  my_side             text,
  other_name          text,
  unread_count        integer,
  other_avatar        text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  me   uuid := public.current_app_user();
  mine uuid := public.current_provider();
begin
  -- **ومن لا هويّةَ له لا يرى شيئاً** — لا خطأً يُرمى، بل قائمةٌ فارغة:
  -- القائمةُ تُفتح قبل اكتمال الملفّ أحياناً، وشاشةٌ حمراءُ هناك أسوأُ من
  -- قائمةٍ خالية.
  if me is null and mine is null then
    return;
  end if;

  return query
  select
    c.id,
    c.booking_id,
    c.user_id,
    c.provider_id,
    c.last_message_at,
    c.last_message_body,
    c.last_message_sender,
    case when c.user_id = me then 'customer' else 'provider' end as my_side,
    case when c.user_id = me then c.provider_name else c.user_name end
      as other_name,
    (
      select count(*)::integer
      from public.conversation_messages m
      where m.conversation_id = c.id
        and m.sender <> (case when c.user_id = me then 'customer' else 'provider' end)
        and m.created_at > coalesce(
              case when c.user_id = me then c.customer_read_at else c.provider_read_at end,
              'epoch'::timestamptz)
    ) as unread_count,
    -- **وهنا الفرقُ عن الطريقة:** الجانبان لا جانبٌ واحد.
    --
    -- **والحقلُ واحدٌ يُسمّى صراحةً** — لا `u.*` ولا `sp.*`: لو كُتب النجمُ
    -- يوماً لَخرج معه البريدُ والجوالُ من حيث لا يُرى. ويُقاس عددُ الأعمدة
    -- في الحزمة لذلك.
    case
      when c.user_id = me
        then coalesce((select sp.logo_path from public.service_providers sp
                        where sp.id = c.provider_id), '')
      else coalesce((select u.avatar_path from public.app_users u
                      where u.id = c.user_id), '')
    end as other_avatar
  from public.conversations c
  where (p_conversation_id is null or c.id = p_conversation_id)
    -- **والشرطُ هو الحدُّ كلُّه.** الدالّةُ تتجاوز السياسةَ بتصميمها، فما
    -- يمنعها من إخراج محادثات الناس إلّا هذا السطر.
    and (c.user_id = me or c.provider_id = mine)
  order by c.last_message_at desc;
end $$;

revoke all on function public.api_my_conversations(uuid) from public;
grant execute on function public.api_my_conversations(uuid) to authenticated;

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- التحقّق
-- ----------------------------------------------------------------------------
select 'الدالّة' as البند, count(*)::text as النتيجة
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'api_my_conversations'
union all
-- **وتُعدّ أعمدتُها لا وجودُها وحدَه.** إحدى عشرةَ لا غير — فلو تسلّل عمودٌ
-- ثانيَ عشرَ من صفّ العميل (بريدٌ أو جوّال) خرج الرقمُ مخالفاً وقيل.
select 'أعمدتها (١١)', count(*)::text
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral unnest(p.proargnames) as a(name)
 where n.nspname = 'public' and p.proname = 'api_my_conversations'
   and a.name is not null and a.name <> 'p_conversation_id'
union all
select 'ليست للعموم', case when has_function_privilege(
         'public', 'public.api_my_conversations(uuid)', 'execute')
       then '❌ للعموم' else '✅' end;
