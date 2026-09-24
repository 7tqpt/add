-- ============================================================================
--  مصروفُ خطّة العرس حسب القسم — لأشرطة «تفاصيل المصروفات»
--
--  شغّله بعد `install.sql`. آمنٌ عند التكرار.
-- ============================================================================
--
--  ── ما ينقص اليوم ─────────────────────────────────────────────────────────
--
--  شاشةُ الخطّة تعرض أربعة أرقامٍ مجموعة: الميزانيةُ وإجماليُّ الحجوزات
--  والمدفوعُ والمتبقّي. **ولا تقول أين ذهب المال**: القاعةُ كم، والتصويرُ
--  كم، والضيافةُ كم.
--
--  و`v_plan_summary` تجمع `sum(total_price)` ولا تفصّل، و`Booking` في
--  التطبيق لا تحمل قسمَ خدمتها أصلاً. فلا سبيل إلى التوزيع من التطبيق:
--  يحتاج جمعاً في القاعدة عبر `bookings → provider_services → service_categories`.
--
--  ── ولماذا دالّةٌ لا طريقةُ عرض ───────────────────────────────────────────
--
--  طريقةُ العرض تحتاج حرزاً بسياسةٍ على صفوفها، وهذه تجمع من ثلاثة جداول
--  لكلّ خطّةٍ على حدة. والدالّةُ تأخذ معرّفَ الخطّة وتردّ صفوفَها وحدَها،
--  وحرزُها سطرٌ واحدٌ يُقرأ: **خطّةُ صاحب الجلسة أو لا شيء**.
--
--  ── وما يُعدّ وما لا يُعدّ ────────────────────────────────────────────────
--
--  الملغى والمرفوضُ خارج الحساب — كما في `v_plan_summary` حرفاً. وحجزٌ
--  أُلغي لا يُنفق عليه أحد، وعدُّه يُري صاحبَه مصروفاً لم يخرج من جيبه.
--
--  ويُعاد لكلّ قسمٍ رقمان لا واحد:
--
--    · `spent`  — **ما دُفع فعلاً** (`paid_amount`). وهو الذي يُبنى عليه
--      «المصروف» في الشاشة، فالميزانيةُ تُستهلك بالدفع لا بالحجز.
--    · `booked` — ثمنُ ما حُجز (`total_price`). وهو الذي يُري الالتزامَ
--      القادم، ويفترق عن الأوّل دائماً ما دام عربونٌ لم يُكمَّل.
-- ============================================================================

begin;

create or replace function public.api_plan_spend_by_category(p_plan_id uuid)
returns table (
  category_id   uuid,
  category_name text,
  spent         numeric,
  booked        numeric,
  bookings      integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id                                       as category_id,
    c.name                                     as category_name,
    coalesce(sum(b.paid_amount), 0)            as spent,
    coalesce(sum(b.total_price), 0)            as booked,
    count(*)::integer                          as bookings
  from public.bookings b
  join public.wedding_plans pl on pl.id = b.plan_id
  join public.provider_services s on s.id = b.service_id
  join public.service_categories c on c.id = s.category_id
  where b.plan_id = p_plan_id
    -- **الحرزُ سطرٌ واحد**: خطّةُ صاحب الجلسة أو لا شيء. ولا يُوثق بمعرّفٍ
    -- يُمرَّر من التطبيق — ومن مرّر خطّةَ غيره لم يُخرج صفّاً.
    and pl.user_id = public.current_app_user()
    and b.status not in ('cancelled', 'rejected')
  group by c.id, c.name
  having coalesce(sum(b.total_price), 0) > 0
  order by coalesce(sum(b.total_price), 0) desc
$$;

comment on function public.api_plan_spend_by_category(uuid) is
  'مصروفُ خطّةِ صاحبِ الجلسة موزَّعاً على الأقسام — المدفوعُ والمحجوزُ لكلّ قسم.';

revoke all on function public.api_plan_spend_by_category(uuid) from public, anon;
grant execute on function public.api_plan_spend_by_category(uuid) to authenticated;

commit;

notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- للتحقّق بعد التشغيل — ضع معرّفَ خطّتك
-- ----------------------------------------------------------------------------
--   select * from public.api_plan_spend_by_category('‹معرّف الخطة›');
