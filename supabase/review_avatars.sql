-- ============================================================================
--  صورةُ العميل في «آراء العملاء» — من ملفّه الشخصيّ
--
--  شغّله في محرّر SQL بعد `profile.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:**
--
--  تبويبُ التقييمات في صفحة المزوّد يرسم حرفاً في قرصٍ نبيذيّ، فقال صاحبُ
--  المنصّة: «أريد آراء العملاء صورة تظهر… صورة تجلبها لي من ملف شخصية حق
--  العميل».
--
--  والحرفُ ليس عطباً في الشاشة: `reviews` ليس فيه صورة، والصورةُ في
--  `app_users.avatar_path`، وسياستُها صريحة: «العميل يرى ويعدّل حسابه هو.
--  **لا يرى حسابات غيره إطلاقاً**». وصفحةُ المزوّد يفتحها غيرُ صاحب الرأي
--  أبداً — فلا وصلٌ إلى صفّه يمرّ.
--
--  **وهي حالةُ صورة المحادثات بعينها**، وطريقُها هو الذي أُقرّ لها:
--  دالّةٌ `security definer` ترى الصفَّ ولا تُخرج منه إلّا ما وُعد به.
--  انظر `conversation_avatars.sql` و`customer_card.sql`.
--
--  **وما تُخرجه هذه:** أعمدةُ التقييم الخمسةُ التي يقرؤها التطبيقُ اليوم
--  ومعها `avatar_path` وحدَه — **ولا بريدَ ولا جوّالَ ولا حالةَ حساب**.
--  والحقلُ يُسمّى صراحةً: لو كُتب `u.*` يوماً لَخرج معه ما لا يُراد.
--
--  **وحدّانِ لا حدٌّ واحد:**
--
--    ١. `r.provider_id = p_provider_id` — فلا تُقرأ آراءُ مزوّدٍ بذكر آخر.
--    ٢. `r.status = 'published'` — **وهو الأخطر**: المخفيُّ والمُبلَّغُ عنه
--       يراهما صاحبُهما والإدارةُ وحدَهم في السياسة، ودالّةٌ تتجاوز السياسةَ
--       بتصميمها لا يمنعها من إخراجهما إلّا هذا السطر.
--
--  **ولمن تُمنح:** `anon` و`authenticated` معاً — صفحةُ المزوّد تُفتح قبل
--  تسجيل الدخول، وهي بابُ المنصّة إلى غير المسجَّلين. **وأثرُ ذلك يُقال لا
--  يُسكت عنه:** صورةُ من قيّم تصير علنيّةً كما هو اسمُه اليوم.
--
--  **ويبقى جدولُ `reviews` وسياستُه كما هما ولا يُحذف منهما شيء.**
-- ============================================================================

create or replace function public.api_provider_reviews(
  p_provider_id uuid
)
returns table (
  id          uuid,
  user_name   text,
  rating      integer,
  comment     text,
  created_at  timestamptz,
  avatar_path text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select
    r.id,
    r.user_name,
    r.rating,
    r.comment,
    r.created_at,
    -- **حقلٌ واحدٌ يُسمّى صراحةً** — لا `u.*`.
    --
    -- و`left join` لا `join`: `reviews.user_id` يقبل الفراغ (`on delete set
    -- null`)، ورأيٌ حُذف صاحبُ حسابه يبقى منشوراً — فلو وُصل وصلاً داخليّاً
    -- لَاختفى الرأيُ نفسُه من الصفحة لا صورتُه وحدَها.
    coalesce(u.avatar_path, '') as avatar_path
  from public.reviews r
  left join public.app_users u on u.id = r.user_id
  -- **والشرطانِ هما الحدُّ كلُّه.** الدالّةُ تتجاوز السياسةَ بتصميمها، فما
  -- يمنعها من إخراج المخفيِّ والمُبلَّغ عنه إلّا هذان السطران.
  where r.provider_id = p_provider_id
    and r.status = 'published'
  order by r.created_at desc
  limit 20;
end $$;

revoke all on function public.api_provider_reviews(uuid) from public;
-- صفحةُ المزوّد تُفتح قبل تسجيل الدخول — وهي بابُ المنصّة إلى غير المسجَّلين.
grant execute on function public.api_provider_reviews(uuid) to anon, authenticated;

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- التحقّق
-- ----------------------------------------------------------------------------
select 'الدالّة' as البند, count(*)::text as النتيجة
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'api_provider_reviews'
union all
-- **وتُعدّ أعمدتُها لا وجودُها وحدَه.** ستّةٌ لا غير — فلو تسلّل عمودٌ سابعٌ
-- من صفّ العميل (بريدٌ أو جوّال) خرج الرقمُ مخالفاً وقيل.
select 'أعمدتها (٦)', count(*)::text
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  cross join lateral unnest(p.proargnames) as a(name)
 where n.nspname = 'public' and p.proname = 'api_provider_reviews'
   and a.name is not null and a.name <> 'p_provider_id'
union all
select 'تُرجع المنشورَ وحدَه',
       case when pg_get_functiondef(p.oid) like '%published%' then '✅' else '❌ الحدُّ سقط' end
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'api_provider_reviews';
