-- ============================================================================
--  دخلُ المنصّة — ثلاثةُ أبوابٍ في رقمٍ واحد
--
--  شغّله في أي وقت. آمنٌ عند التكرار.
-- ============================================================================
--
--  **ما كان ناقصاً:** اللوحة تعرض «عمولة المنصة» وحدها. وقد بُني بعدها بابان
--  آخران للدخل — اشتراكاتُ المزوّدين وإعلاناتُهم — فصار صاحبُ المنصّة يرى
--  ثلثَ دخله ويظنّه كلَّه.
--
--  **وأدقُّ من ذلك:** ما تعرضه اللوحة اليوم عمولةٌ على حجوزاتٍ **أُنشئت** في
--  المدّة، لا على مالٍ وصل. وبين الاثنين فرقٌ يتّسع كلّما كثُر المعلَّق: حجزٌ
--  بمليونٍ أُنشئ اليوم ولم يُدفع عربونُه يرفع الرقم مئةَ ألفٍ لم تدخل الخزنة.
--  فما هنا **نقديٌّ لا استحقاقيّ**: لا يُحسب ريالٌ إلا وقد تأكّدت حوالتُه.
--
--    عمولة   ← `platform_share` من دفعات الحجوزات المؤكَّدة
--    اشتراك  ← مبلغُ حوالةِ اشتراكٍ تأكّدت
--    إعلان   ← مبلغُ حوالةِ إعلانٍ تأكّدت
--
--  والمستردُّ يُطرح من العمولة: استردادٌ بعد أن أُخذت عمولتُه يعني أن المنصّة
--  تُعيد حصّتها كذلك، ورقمٌ لا يطرحه يكذب في اتجاه واحدٍ دائماً — إلى أعلى.
-- ============================================================================

begin;

create or replace function public.api_admin_income(p_from date, p_to date)
returns table (
  day           date,
  commission    numeric,
  subscriptions numeric,
  promotions    numeric
)
language sql stable security definer set search_path = public as $$
  select
    d::date as day,
    coalesce(sum(p.platform_share) filter (
      where p.kind in ('deposit', 'balance', 'full')), 0)
    - coalesce(sum(p.platform_share) filter (where p.kind = 'refund'), 0) as commission,
    coalesce(sum(p.amount) filter (where p.kind = 'subscription'), 0) as subscriptions,
    coalesce(sum(p.amount) filter (where p.kind = 'promotion'), 0)    as promotions
  -- سلسلةُ الأيام أوّلاً ثم الوصل: يومٌ بلا دخلٍ يجب أن يكون صفراً في الرسم
  -- لا فجوةً تُزحزح الخطّ وتُري صعوداً لم يقع.
  from generate_series(p_from, p_to, interval '1 day') d
  left join public.payments p
    on p.created_at::date = d::date
   and p.status = 'paid'
  where public.can_read_area('finance')
  group by d
  order by d
$$;

comment on function public.api_admin_income(date, date) is
  'دخلُ المنصّة اليوميّ: عمولةٌ محصَّلة واشتراكاتٌ وإعلانات. نقديٌّ لا استحقاقيّ.';

-- **والحارسُ داخل الاستعلام لا حولَه:** `where public.can_read_area('finance')`
-- شرطٌ يُقيَّم مرّةً، فمن لا يملك قراءة المال يرى صفوفاً بأصفار لا خطأً — وهو
-- ما يمنع تسريبَ الأرقام دون أن يُسقط شاشةَ من دخلها بصلاحيةٍ أضيق.
--
-- ولأنها `security definer` فلا بدّ من سحبها من `anon`: القراءة للمسؤولين.
revoke all on function public.api_admin_income(date, date) from public, anon;
grant execute on function public.api_admin_income(date, date) to authenticated;

commit;

notify pgrst, 'reload schema';

-- ============================================================================
--  الفحص
-- ============================================================================
select 'دالّة الدخل' as البند,
       case when exists (
         select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'api_admin_income')
       then '✅' else '❌' end as الحال
union all
select 'دخلُ آخر ثلاثين يوماً',
       coalesce((select to_char(
         sum(commission + subscriptions + promotions), 'FM999,999,999') || ' ريال'
         from public.api_admin_income(current_date - 30, current_date)), '—');
