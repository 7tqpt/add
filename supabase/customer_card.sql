-- ============================================================================
--  بطاقةُ العميل كما يراها مقدّمُ الخدمة
--
--  شغّله في محرّر SQL بعد `install.sql` و`chat.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **لماذا دالّةٌ ولا تكفي السياسات:**
--
--  ضغط صاحبُ المنصّة شريطَ المحادثة بحساب مقدّم خدمةٍ فلم يُفتح شيء، فطلب
--  بطاقةً للعميل فيها صورتُه ومحافظتُه. وسياسةُ `app_users` صريحة:
--
--      «العميل يرى ويعدّل حسابه هو. لا يرى حسابات غيره إطلاقاً»
--
--  وهي تشمل مقدّمَ الخدمة. فالطريقان لا ثالثَ لهما:
--
--    ١) **تُوسَّع السياسة** فيقرأ مقدّمُ الخدمة صفَّ العميل — وفيه **البريدُ
--       والجوالُ وحالةُ الحساب** لا الصورةُ وحدَها. وهذا لم يُفعل ولن يُفعل:
--       من طلب صورةً لا يُعطى بريداً.
--
--    ٢) **أو دالّةٌ ضيّقة** ترى الصفَّ كلَّه ولا تُخرج منه إلّا حقلين. وهي
--       هذه، وهي ما اختاره صاحبُ المنصّة صراحةً: «عبر دالّةٍ ضيّقةٍ تُرجع
--       هذين وحدَهما لطرفَي محادثةٍ قائمة».
--
--  **وما عدا الحقلين محسوبٌ ممّا يملكه أصلاً.** عددُ الحجوزات وحالاتُها
--  وإجماليُّ ما دُفع — كلُّها من **حجوزات مقدّم الخدمة نفسِه**، يقرؤها اليوم
--  بسياسته. ولا تُحسب هنا إلّا لتُجمَع في نداءٍ واحدٍ بدل خمسة.
--
--  **وحدُّ الدالّة ثلاثة، كلُّها مقيسةٌ في `tests/customer_card.test.mjs`:**
--
--    ــ لا تعمل إلّا لمقدّم خدمة.
--    ــ ولا تعمل إلّا على محادثةٍ **هو طرفُها**.
--    ــ ولا تُخرج بريداً ولا جوّالاً ولا حالةَ حساب.
-- ============================================================================

create or replace function public.api_customer_card(p_conversation_id uuid)
returns table (
  full_name        text,
  avatar_path      text,
  governorate      text,
  bookings_count   integer,
  completed_count  integer,
  cancelled_count  integer,
  upcoming_count   integer,
  first_booking_at timestamptz,
  total_paid       numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  mine     uuid := public.current_provider();
  customer uuid;
begin
  if mine is null then
    raise exception 'هذه لمقدّمي الخدمة.' using errcode = '42501';
  end if;

  -- **والشرطُ شرطان لا واحد:** أن تكون المحادثةُ موجودةً، **وأن يكون هو
  -- طرفَها**. ولو اكتُفي بالأوّل لَقرأ أيُّ مقدّمِ خدمةٍ بطاقةَ أيّ عميلٍ
  -- بمعرّف محادثةٍ ليست له.
  select c.user_id into customer
  from public.conversations c
  where c.id = p_conversation_id and c.provider_id = mine;

  if customer is null then
    raise exception 'المحادثة غير موجودة أو ليست لك.' using errcode = 'P0002';
  end if;

  return query
  select
    u.full_name,
    -- **والحقلان وحدَهما يخرجان من الصفّ.** ولو كُتب `u.*` يوماً لَخرج معه
    -- البريدُ والجوالُ — فيُسمَّيان صراحةً، ويُقاس ذلك بحزمةٍ تعدّ الأعمدة.
    u.avatar_path,
    u.governorate,
    -- وما بعدها من حجوزاته **معه هو**، لا من حجوزات العميل كلِّها.
    (select count(*)::integer from public.bookings b
      where b.user_id = customer and b.provider_id = mine),
    (select count(*)::integer from public.bookings b
      where b.user_id = customer and b.provider_id = mine
        and b.status = 'completed'),
    -- **والمرفوضُ مع الملغى**: كلاهما حجزٌ لم يقع، والتفريقُ بينهما في بطاقةٍ
    -- موجزةٍ يزيد سطراً ولا يزيد معنى.
    (select count(*)::integer from public.bookings b
      where b.user_id = customer and b.provider_id = mine
        and b.status in ('cancelled', 'rejected', 'expired')),
    (select count(*)::integer from public.bookings b
      where b.user_id = customer and b.provider_id = mine
        and b.status in ('pending_provider', 'confirmed')),
    (select min(b.created_at) from public.bookings b
      where b.user_id = customer and b.provider_id = mine),
    -- **وما دُفع لا ما وُعد**: `paid_amount` ناقصَ ما رُدّ، لا `total_price`.
    -- وحجزٌ لم يُدفع عربونُه يُظهر صفراً — وهو الصدق.
    (select coalesce(sum(b.paid_amount - b.refunded_amount), 0) from public.bookings b
      where b.user_id = customer and b.provider_id = mine)
  from public.app_users u
  where u.id = customer;
end $$;

revoke all on function public.api_customer_card(uuid) from public;
grant execute on function public.api_customer_card(uuid) to authenticated;

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- التحقّق
-- ----------------------------------------------------------------------------
select 'الدالّة' as البند, count(*)::text as النتيجة
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'api_customer_card'
union all
-- **وتُعدّ أعمدتُها لا وجودُها وحدَه.** تسعةٌ لا غير — فلو أُضيف يوماً عمودٌ
-- عاشرٌ من صفّ العميل (بريدٌ أو جوّال) خرج الرقمُ مخالفاً وقيل.
select 'أعمدتها (٩)', count(*)::text
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral unnest(p.proargnames) as a(name)
 where n.nspname = 'public' and p.proname = 'api_customer_card'
   and a.name is not null and a.name <> 'p_conversation_id'
union all
select 'ليست للعموم', case when has_function_privilege(
         'public', 'public.api_customer_card(uuid)', 'execute')
       then '❌ للعموم' else '✅' end;
