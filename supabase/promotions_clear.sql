-- ============================================================================
--  «تفريغ المنتهية» — زرٌّ للمالك وحده في «الاشتراكات والإعلانات»
-- ============================================================================
--
--  قال صاحبُ المنصّة: «اريد زر تفريغ خاص للمدير»، واختار (أ أ): **المنتهيةُ
--  والملغاةُ وحدها**، **والمالكُ وحده**. فقائمةُ الحملات تمتلئ بما انقضى ولا
--  يعود، ولا بابَ لحذفه إلّا SQL.
--
--  ── ما يُحذف ────────────────────────────────────────────────────────────────
--
--    • `ended` و`cancelled`.
--    • **وما انقضى تاريخُه وعمودُه ما زال «جارية»** — تقول عنه اللوحة «انتهت
--      مدّتها» (`promotionTiming`)، ولا يظهر في التطبيق. فهو منتهٍ لمن يرى.
--    • **إلّا طلبَ مزوّدٍ حوالتُه لم تُؤكَّد** (`scheduled` ومعه `payment_id`):
--      لو حُذف ثمّ أكّدت الإدارةُ حوالتَه لَقُبض المالُ ولا ظهورَ يُفعَّل
--      (`activate_paid_promotion` يبحث عن صفّه فلا يجده).
--
--  ── وما لا يُمسّ ────────────────────────────────────────────────────────────
--
--  **المال.** الدخلُ يُحسب من `payments` (`income.sql`) لا من `promotions`،
--  فتبقى المبالغُ المدفوعة في «عمليات الدفع» وتقارير الدخل كما هي.
--
--  ── والصور ─────────────────────────────────────────────────────────────────
--
--  تُرجَع روابطُها ليحذفها العميلُ من سلّة `ad-banners` بواجهة التخزين: Supabase
--  يمنع الحذفَ المباشر من `storage.objects` بـSQL، فلا يُحذف الملفُّ من هنا.
--
--  التشغيل:  بعد `banners.sql` — وإعادةُ اللصق آمنة.
-- ============================================================================

begin;

create or replace function public.api_admin_clear_promotions()
returns table (deleted integer, image_urls text[])
language plpgsql security definer set search_path = public as $$
declare
  gone public.promotions[];
begin
  if not public.is_owner() then
    raise exception 'تفريغُ الحملات للمالك وحده';
  end if;

  with victims as (
    delete from public.promotions pr
     where pr.status in ('ended', 'cancelled')
        or (pr.status = 'active' and pr.ends_at < now())
        or (pr.status = 'scheduled' and pr.payment_id is null and pr.ends_at < now())
    returning pr.*
  )
  select coalesce(array_agg(v), '{}') into gone from victims v;

  return query
    select coalesce(array_length(gone, 1), 0),
           coalesce(
             (select array_agg(distinct u)
                from unnest(gone) g
                cross join lateral unnest(
                  coalesce(g.image_urls, '{}') || array[g.image_url]) u
               where coalesce(u, '') <> ''),
             '{}');
end $$;

revoke execute on function public.api_admin_clear_promotions() from public, anon;
grant execute on function public.api_admin_clear_promotions() to authenticated;

comment on function public.api_admin_clear_promotions() is
  'يحذف الحملاتِ المنتهية والملغاة (والمنقضيةَ وإن قال عمودُها «جارية») — للمالك وحده. ويُرجع روابطَ صورها لتُحذف من التخزين.';

commit;

notify pgrst, 'reload schema';
